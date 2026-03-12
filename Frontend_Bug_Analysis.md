# FRONTEND BUG ANALYSIS — WebSocket Presence System

**ChatBee — Flutter / Dart (Riverpod)**
**Prepared: March 9, 2026**

---

## Executive Summary

The Flutter frontend has **4 bugs** in its WebSocket presence handling that prevent reliable online/offline status updates. These bugs interact with 5 backend bugs (documented separately) to create the intermittent presence failures observed in production.

The frontend bugs fall into two categories: (1) missing event handling that silently drops the server's presence data, and (2) fragile connection lifecycle management that creates race conditions during app backgrounding/foregrounding.

| Detail | Value |
|--------|-------|
| **Files Changed** | `websocket_service.dart`, `app.dart`, `ws_event_handler.dart` |
| **Files Unchanged** | `chat_list_controller.dart`, `message_controller.dart`, `chat_state_controller.dart`, `presence_model.dart` |
| **Total Bugs** | 4 (2 Critical, 1 High, 1 Medium) |
| **Dependency** | Requires backend fixes to be deployed simultaneously |

---

## Scenario Walkthrough: What Happens Today

Here is the exact sequence when User B's app resumes from background and tries to restore presence:

### Step 1: App resumes — `didChangeAppLifecycleState(resumed)` fires

- `wsService.connectIfNeeded()` is called — starts WebSocket reconnection
- A polling loop checks `isConnected` every 200ms, up to 20 times (4 seconds max) ← **BUG 7**

### Step 2: WebSocket connects (if within 4s)

- `wsService.sendPresenceStatus(true)` tells server User B is back online
- `wsService.send({'type': 'sync_presence'})` asks server for full presence snapshot
- Server processes `sync_presence` and sends back a `presence_sync` response with `Map<userId, bool>`

### Step 3: `presence_sync` response arrives at frontend

- `_handleMessage` parses the JSON: `{"type": "presence_sync", "payload": {"userA": true, ...}}`
- `WsEventType.fromString('presence_sync')` returns `null` — enum doesn't have this value! ← **BUG 6**
- Fallback: event type defaults to `WsEventType.message`
- `ws_event_handler` dispatches to `_handleNewMessage` which tries `MessageResponse.fromJson()`
- Parse fails or produces garbage — the entire presence snapshot is **SILENTLY DROPPED**
- **Result: User A's online status is never updated in B's UI**

### Meanwhile, in the background...

- When the app was paused, `disconnect()` closed the socket — but `onDone` triggered `_scheduleReconnect` ← **BUG 8**
- The reconnect timer may be firing while the app is backgrounded, wasting battery
- When the app resumes, `connectIfNeeded` and the auto-reconnect timer may race to connect
- Two WebSocket connections can be established — one becomes orphaned and eventually times out

---

## Detailed Bug Analysis

---

### Bug 6: `presence_sync` event silently dropped — enum missing + no handler

| Detail | Value |
|--------|-------|
| **File** | `websocket_service.dart` + `ws_event_handler.dart` |
| **Severity** | CRITICAL — Presence snapshot after reconnect is completely lost |

**Problem:**

The backend sends a `presence_sync` event (a bulk map of userId → online/offline) when the client sends `{"type": "sync_presence"}`. This is the **primary mechanism** for restoring correct presence state after the app resumes from background.

The frontend has two compounding problems:

**First**, the `WsEventType` enum does not include `presenceSync`. When `WsEventType.fromString('presence_sync')` is called, it returns `null`. The `WsEvent.fromJson` constructor uses a fallback: `WsEventType.fromString(json['type']) ?? WsEventType.message`. So the `presence_sync` event is silently converted to a `message` type.

**Second**, `ws_event_handler.dart` has no case for `presenceSync`. Even if the enum value existed, the switch statement in the event listener would fall through. The event would be ignored.

The combined effect: **every time the app resumes and requests a presence snapshot, the server responds correctly, but the frontend throws away the response.** User A appears stuck in whatever state they were in before the app was backgrounded. This is the primary reason why "when the other opens the app, for the other person it should show online but it is not showing."

**Problematic Code:**

```dart
// OLD: websocket_service.dart — WsEventType enum
enum WsEventType {
  message,
  userOnline,
  userOffline,
  // ... (no presenceSync!)
}

static WsEventType? fromString(String? value) {
  switch (value) {
    // ... (no 'presence_sync' case!)
    default: return null;  // ← presence_sync falls here
  }
}

// OLD: ws_event_handler.dart — switch statement
switch (event.type) {
  case WsEventType.userOnline: ...
  case WsEventType.userOffline: ...
  // (no presenceSync case — even if enum existed, no handler)
}
```

**Fix:**

Added `presenceSync` to the `WsEventType` enum with the mapping `'presence_sync'` ↔ `presenceSync`.

Added special parsing in `_handleMessage` for `presence_sync` events. The `presence_sync` payload has a different shape than other events — it's a flat `Map<String, bool>` (userId → isOnline), not the usual `{roomId, payload}` structure. The parser now handles this directly.

Added `_handlePresenceSync` in `ws_event_handler.dart` that iterates the map and calls `chatListController.updatePresence()` for each user, applying the authoritative snapshot.

**Fixed Code:**

```dart
// NEW: websocket_service.dart — enum with presenceSync
enum WsEventType {
  // ... existing values ...
  presenceSync;  // ← ADDED

  static WsEventType? fromString(String? value) {
    switch (value) {
      case 'presence_sync': return WsEventType.presenceSync;  // ← ADDED
      // ...
    }
  }
}

// NEW: _handleMessage — special parsing for presence_sync
if (eventType == WsEventType.presenceSync) {
  final payload = json['payload'];
  final event = WsEvent(
    type: WsEventType.presenceSync,
    roomId: '',
    payload: payload is Map ? Map<String, dynamic>.from(payload) : {},
  );
  _eventController.add(event);
  return;
}

// NEW: ws_event_handler.dart — handler for presenceSync
void _handlePresenceSync(Ref ref, WsEvent event) {
  final chatListNotifier = ref.read(chatListControllerProvider.notifier);
  for (final entry in event.payload.entries) {
    final userId = entry.key;
    final isOnline = entry.value == true;
    chatListNotifier.updatePresence(userId, isOnline: isOnline);
  }
}
```

---

### Bug 7: App resume uses fragile polling loop to wait for WebSocket

| Detail | Value |
|--------|-------|
| **File** | `app.dart` — `didChangeAppLifecycleState` |
| **Severity** | HIGH — Unreliable reconnection causes presence to never be sent |

**Problem:**

When the app resumes, `app.dart` needs to wait for the WebSocket to connect before sending presence updates. The current implementation uses a polling loop that checks `isConnected` every 200ms for up to 20 iterations (4 seconds total).

This approach has three problems:

**Race condition:** `isConnected` is set to `true` inside the stream listener callback. The polling loop checks the flag from a different async context. There's a tiny window where the connection succeeds between checks but `isConnected` hasn't been updated yet.

**Too short timeout:** 4 seconds may not be enough on slow mobile networks (cellular, weak WiFi, congested). If the loop times out, `sendPresenceStatus` and `sync_presence` are never sent. User A never learns that User B came back online.

**No guarantee of sequencing:** Even when the loop exits successfully, the subsequent send happens in a `postFrameCallback`. By the time it runs, the connection might have dropped again (e.g., server rejected the token).

**Problematic Code:**

```dart
// OLD: app.dart — polling loop
wsService.connectIfNeeded();  // fire and forget

int attempts = 0;
while (!wsService.isConnected && attempts < 20) {
  await Future.delayed(const Duration(milliseconds: 200));
  attempts++;
}

if (wsService.isConnected) {
  print('[AppLifecycle] WebSocket connected after $attempts attempts, sending online status');
  wsService.sendPresenceStatus(true);
  wsService.send({'type': 'sync_presence', 'payload': {}});
} else {
  print('[AppLifecycle] WebSocket failed to connect, presence not sent');
}
```

**Fix:**

Replaced the polling loop with a `Completer`-based `connectIfNeeded()` that returns a `Future<bool>`. The future resolves when the WebSocket's stream listener fires its first data event (proving the connection is live). Timeout is increased to 8 seconds. No polling, no timing guesses, deterministic behavior.

**Fixed Code:**

```dart
// NEW: app.dart — Completer-based wait
final connected = await wsService.connectIfNeeded(
  timeout: const Duration(seconds: 8),
);
if (connected) {
  wsService.sendPresenceStatus(true);
  wsService.requestPresenceSync();
}

// NEW: websocket_service.dart — connectIfNeeded returns Future<bool>
Completer<bool>? _connectCompleter;

Future<bool> connectIfNeeded({Duration timeout = const Duration(seconds: 8)}) async {
  _intentionalDisconnect = false;

  if (_isConnected && _channel != null) return true;
  if (_token == null) return false;

  _reconnectAttempts = 0;
  _connectCompleter = Completer<bool>();
  _doConnect();

  try {
    return await _connectCompleter!.future.timeout(timeout, onTimeout: () => false);
  } catch (e) {
    return false;
  }
}

// In _doConnect's stream listener — resolve the completer:
_channel!.stream.listen((data) {
  if (!_isConnected) {
    _isConnected = true;
    _startPingTimer();
    if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
      _connectCompleter!.complete(true);  // ← resolves the Future
    }
  }
  _handleMessage(data);
});
```

---

### Bug 8: Auto-reconnect fires while app is intentionally backgrounded

| Detail | Value |
|--------|-------|
| **File** | `websocket_service.dart` — `disconnect()` + `_scheduleReconnect()` |
| **Severity** | HIGH — Wastes battery, creates zombie connections, races on resume |

**Problem:**

When the app goes to background, `app.dart` calls `disconnect()` which calls `_closeChannel()`. The `_closeChannel` method closes the WebSocket sink, which triggers the stream's `onDone` callback. The `onDone` callback calls `_scheduleReconnect()`. So within seconds of intentionally disconnecting, the service starts trying to reconnect — while the app is still backgrounded.

This causes three problems:

**Battery waste:** The app is making network requests in the background for no reason. On iOS, this may also cause the app to be terminated by the OS.

**Zombie connections:** If a reconnect succeeds while backgrounded, the server thinks the user is online (WebSocket is connected) but the user is not actually using the app. No `presence_status(false)` was sent for this new connection.

**Race on resume:** When the app resumes and calls `connectIfNeeded()`, there may already be a pending reconnect timer about to fire. Both attempt to connect simultaneously, potentially creating two WebSocket connections. One becomes orphaned.

**Problematic Code:**

```dart
// OLD: disconnect doesn't suppress auto-reconnect
void disconnect() {
  _closeChannel();  // closes sink → onDone fires → _scheduleReconnect()
}

void _closeChannel() {
  _stopPingTimer();
  _reconnectTimer?.cancel();
  try { _channel?.sink.close(); } catch (_) {}  // ← triggers onDone!
  _channel = null;
  _isConnected = false;
}
```

**Fix:**

Added `_intentionalDisconnect` flag. When `disconnect()` is called (app backgrounding), the flag is set to `true` and `_scheduleReconnect()` checks it before scheduling. When `connectIfNeeded()` is called (app resuming), the flag is cleared. This cleanly separates intentional disconnects from unintentional ones (network loss, server restart).

**Fixed Code:**

```dart
// NEW: intentional disconnect suppresses auto-reconnect
bool _intentionalDisconnect = false;

void disconnect() {
  _intentionalDisconnect = true;  // ← suppress reconnect
  _closeChannelSilently();
}

Future<bool> connectIfNeeded({...}) async {
  _intentionalDisconnect = false;  // ← re-enable reconnect
  // ...
}

void _scheduleReconnect() {
  if (_intentionalDisconnect) return;  // ← don't reconnect
  // ...
}

void _handleDisconnect() {
  _isConnected = false;
  _stopPingTimer();
  if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
    _connectCompleter!.complete(false);  // ← fail pending waiters
  }
  if (!_intentionalDisconnect) {
    _scheduleReconnect();
  }
}
```

---

### Bug 9: Ping interval (30s) matches backend read deadline (30s)

| Detail | Value |
|--------|-------|
| **File** | `websocket_service.dart` — `_pingInterval` |
| **Severity** | MEDIUM — Causes spurious WebSocket disconnects |

**Problem:**

The frontend sends a ping every 30 seconds. The backend (after the fix) sets a 30-second read deadline on the WebSocket. These timers are not synchronized — they start at different times and drift independently.

If the frontend's ping is delayed by even 100-200ms (common causes: Dart GC pause, main isolate busy with UI rendering, OS scheduling delays on mobile), the backend's read deadline expires before the ping arrives. The server closes the connection, and the user appears to disconnect.

This is a contributing factor to the "sometimes it even disconnects" symptom. The disconnects appear random because they depend on the exact phase alignment between two independent 30-second timers.

**Problematic Code:**

```dart
// OLD: 30s ping vs 30s server deadline — no margin
static const Duration _pingInterval = Duration(seconds: 30);
```

**Fix:**

Changed the frontend ping interval from 30 seconds to 25 seconds, providing a comfortable 5-second buffer. Even with GC pauses and UI jank, pings consistently arrive before the backend's 30-second deadline.

**Fixed Code:**

```dart
// NEW: 25s ping vs 30s server deadline — 5s safety margin
static const Duration _pingInterval = Duration(seconds: 25);
```

---

## File Changes Summary

### websocket_service.dart

This file received the most changes — it's the core of the WebSocket lifecycle.

| Change | Detail |
|--------|--------|
| **Added `presenceSync` to `WsEventType`** | New enum value with `'presence_sync'` ↔ `presenceSync` mapping |
| **Added `_intentionalDisconnect` flag** | Set `true` on `disconnect()`, cleared on `connectIfNeeded()`. Checked in `_scheduleReconnect()` to suppress background reconnects |
| **`connectIfNeeded()` returns `Future<bool>`** | Uses `Completer` resolved by stream listener. Replaces polling loop in `app.dart`. 8-second timeout with clean failure path |
| **Special `presence_sync` parsing** | `presence_sync` payload is `Map<String, bool>`, not `{roomId, payload}`. Parsed separately in `_handleMessage` |
| **Ping interval 30s → 25s** | Prevents deadline race with backend's 30s `ReadDeadline` |
| **Added `requestPresenceSync()`** | Convenience method: sends `{type: 'sync_presence'}` — used by `app.dart` on resume |
| **Centralized `_handleDisconnect()`** | Both `onError` and `onDone` call this. Fails pending `Completer`, checks `_intentionalDisconnect` before scheduling reconnect |

### app.dart

Simplified lifecycle handling — no more polling, cleaner flow.

| Change | Detail |
|--------|--------|
| **Replaced polling loop** | `await wsService.connectIfNeeded()` — resolves when actually connected or times out |
| **Added `requestPresenceSync()`** | Called immediately after reconnect to get authoritative presence state |
| **Extracted `_handleResume()`** | Clean async method for resume flow instead of inline code |
| **Always refresh data on resume** | `backgroundRefresh()` runs regardless of WS status — HTTP endpoints return current presence in room participants |

### ws_event_handler.dart

Added `presence_sync` handling — the missing link in the event dispatch.

| Change | Detail |
|--------|--------|
| **Added `presenceSync` case** | New case in the event switch dispatches to `_handlePresenceSync` |
| **Added `_handlePresenceSync()`** | Iterates the `Map<String, bool>` payload and calls `chatListController.updatePresence()` for each user |
| **Renamed `_handleUserOnline`** | Renamed to `_handleUserPresence` for clarity — handles both online and offline individual events |

---

## Integration Notes

These frontend fixes **MUST be deployed together** with the backend fixes. The complete fix set is:

**Backend (Go):**
- `hub.go` — Grace period, per-connection tracking, presence callbacks
- `service.go` (chat package) — Simplified HandleWebSocket, new pingPump, pong handler

**Frontend (Dart):**
- `websocket_service.dart` — presenceSync enum, intentional disconnect flag, Completer-based connect, 25s ping
- `app.dart` — Await-based resume flow, presence sync request
- `ws_event_handler.dart` — presenceSync handler

**No changes needed:**
- `main.go` — Hub callbacks are wired inside `NewService()` automatically
- `chat_list_controller.dart` — `updatePresence()` already works correctly
- `message_controller.dart` — No presence logic
- `chat_state_controller.dart` — No presence logic
- `presence_model.dart` — No changes needed
- All `repository.go` files — No changes needed
- All `handler.go` files — No changes needed
- All connection/user package files — No changes needed
