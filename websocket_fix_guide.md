# WebSocket Lifecycle Bug Fix — Android

## Problem summary

Three symptoms, one root cause:

1. **Other person sees you as offline** even though you're in the app
2. **Messages show single tick** (not delivered) even though recipient is online
3. **Unread counts and notifications don't update** in real time

All three resolve when the app is force-killed and reopened.

---

## Root cause

In `app.dart`, the lifecycle handler calls `disconnectAndNotifyServer()` on **both** `paused` and `hidden`:

```dart
case AppLifecycleState.paused:
case AppLifecycleState.hidden:
  wsService.disconnectAndNotifyServer();
  break;
```

On Android, `paused` fires on **transient events** — pulling down the notification shade, the app switcher peek, permission dialogs, share sheet, biometric prompts, and even some system overlays. This kills the WebSocket within 1–2 seconds of connecting.

The logs confirm it — every session follows this pattern:

```
00:05:51  [WS] New WebSocket connection
00:05:51  message #1: presence_status
00:05:51  message #2: sync_presence
00:05:52  POST /chat/disconnect        ← KILLS IT ~1 SECOND LATER
00:05:53  [WS ERROR] close 1006
```

### The cascade

Once the WebSocket dies:

- Backend's `IsUserOnline()` returns `false` → user appears offline
- `SendMessage` sees recipient offline → message stays at "sent" (single tick)
- `room_updated` WS event has no connection to reach → unread count never updates in UI
- `user_offline` broadcast fires → other user's UI shows offline status

### Secondary issues found

1. **Double `presence_status` + `sync_presence`**: `_doConnect().ready` sends both, then the `resumed` handler sends them again → 4 messages instead of 2 on every connect (confirmed in logs: messages #1–#4 are always presence_status, sync_presence, presence_status, sync_presence)

2. **Second user never connects WebSocket**: User `69c0b8e176e94e8f08465f05` only makes HTTP calls — no WS connection is ever established. They can never receive real-time events.

---

## Fix 1 — `app.dart`: Debounce the background disconnect

This is the **primary fix** that resolves all three symptoms.

### What to change

Replace the entire `didChangeAppLifecycleState` method and add a `_disconnectTimer` field:

```dart
class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  Timer? _disconnectTimer;  // ← ADD THIS FIELD

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _disconnectTimer?.cancel();  // ← ADD THIS LINE
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    log('→ $state', name: 'LIFECYCLE');

    final isLoggedIn = ref.read(authNotifierProvider).isLoggedIn;
    if (!isLoggedIn) return;

    final wsService = ref.read(webSocketServiceProvider);

    switch (state) {
      case AppLifecycleState.paused:
        // ── DEBOUNCE: Only disconnect if app stays backgrounded for 3s ──
        // Android fires `paused` on transient events (notification shade,
        // app switcher, permission dialogs, biometric prompt, share sheet).
        // The 3-second delay lets these resolve without killing the socket.
        _disconnectTimer?.cancel();
        _disconnectTimer = Timer(const Duration(seconds: 3), () {
          log('Disconnect timer fired — app still in background',
              name: 'LIFECYCLE');
          wsService.disconnectAndNotifyServer();
        });
        break;

      case AppLifecycleState.hidden:
        // On Android 13+, hidden fires AFTER paused. The timer from
        // the paused case already covers it. Do nothing here.
        break;

      case AppLifecycleState.resumed:
        // ── CANCEL any pending disconnect — user came back ──
        _disconnectTimer?.cancel();
        _disconnectTimer = null;

        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          try {
            // Step 1: Refresh Firebase token (expires every 1 hour)
            final freshToken = await ref
                .read(authControllerProvider.notifier)
                .getAndRefreshToken();

            if (!mounted) return;

            if (freshToken != null) {
              wsService.updateToken(freshToken);
            }

            // Step 2: Reconnect WebSocket if needed
            final connected = await wsService.connectIfNeeded(
              timeout: const Duration(seconds: 8),
            );

            if (!mounted) return;

            if (connected) {
              log('WS connected on resume', name: 'LIFECYCLE');
              // Send presence update in case we were already connected
              // (connectIfNeeded returned true without reconnecting).
              // If we just freshly reconnected, _doConnect's .ready callback
              // already sent these — the duplicate is harmless (idempotent).
              wsService.sendPresenceStatus(true);
              // DO NOT call requestPresenceSync() here.
              // _doConnect sends it on fresh connections, and the 60s
              // periodic timer handles ongoing sync. This eliminates
              // the duplicate sync_presence calls visible in the logs.
            } else {
              log('WS reconnect failed (will retry via backoff)',
                  name: 'LIFECYCLE');
            }

            // Step 3: Refresh UI data
            ref
                .read(chatListControllerProvider.notifier)
                .backgroundRefresh();
            ref.read(friendsControllerProvider.notifier).refresh();
            ref
                .read(unreadNotificationCountProvider.notifier)
                .refresh();

            // Step 4: Recover stuck auth session
            if (!mounted) return;
            final authState = ref.read(authControllerProvider);
            if (authState.hasError) {
              log('Auth in error state — retrying session restore',
                  name: 'LIFECYCLE');
              ref
                  .read(authControllerProvider.notifier)
                  .restoreSession();
            }
          } catch (e, st) {
            log('Lifecycle resume handler error: $e\n$st',
                name: 'LIFECYCLE');
          }
        });
        break;

      default:
        break;
    }
  }
```

**You also need to add the `dart:async` import** at the top of `app.dart` if it's not already there:

```dart
import 'dart:async';
```

### Why 3 seconds?

- Notification shade pull-down: `paused` → `resumed` happens in under 1 second
- App switcher peek: typically under 2 seconds
- Permission dialogs: resolve within 1–2 seconds
- 3 seconds safely covers all of these without noticeable delay for real backgrounding

---

## Fix 2 — Ensure second user connects WebSocket on login

The second user in your logs (`69c0b8e176e94e8f08465f05`) makes HTTP calls but never establishes a WebSocket connection. This means they can never receive any real-time events.

### What to check

Find where `wsService.connect(token)` is called in your codebase. It's not in any of the files you shared — it's likely in your auth controller or a session gate widget.

**The requirement**: `connect(token)` must be called for **every authenticated user** immediately after login or session restore completes. It must NOT be gated behind navigating to the chat tab or chat list screen.

### Where it should be

In your auth controller (wherever `restoreSession()` or `login()` succeeds):

```dart
// After successful authentication:
final token = await firebaseUser.getIdToken();
if (token != null) {
  ref.read(webSocketServiceProvider).connect(token);
}
```

If this call currently lives inside a chat-specific screen or controller, move it to the auth flow.

---

## Fix 3 — Remove duplicate presence sync on reconnect (optional cleanup)

In `_doConnect()` inside `websocket_service.dart`, the `.ready` callback already sends:

```dart
sendPresenceStatus(true);
requestPresenceSync();
```

And then the `resumed` handler in `app.dart` sends them again. After applying Fix 1, the `resumed` handler only sends `sendPresenceStatus(true)` (which is idempotent), so the duplicate `requestPresenceSync()` is already eliminated.

No additional code change needed — Fix 1 already handles this.

---

## How to verify the fix

After applying the changes, check your server logs for user `69c5820e724718a6ef5ae17b`:

### Before fix (bad pattern):
```
[WS] New WebSocket connection for user ...
[WS] message #1: presence_status
[WS] message #2: sync_presence
[WS] message #3: presence_status      ← duplicate
[WS] message #4: sync_presence        ← duplicate
POST /chat/disconnect                  ← kills it 1-2s later
[WS ERROR] close 1006
```

### After fix (good pattern):
```
[WS] New WebSocket connection for user ...
[WS] message #1: presence_status
[WS] message #2: sync_presence
[WS] message #3: ping                 ← 10s later, keepalive working
[WS] message #4: ping                 ← 20s later
...                                    ← connection stays alive
```

### Test scenarios:

1. **Pull down notification shade** → release → WebSocket should NOT disconnect
2. **Open app switcher** → return to app → WebSocket should NOT disconnect
3. **Leave app in background for 5+ seconds** → WebSocket SHOULD disconnect (timer fires at 3s)
4. **Return to app after backgrounding** → WebSocket should reconnect, other user should see you as online
5. **Send a message while both users are online** → should show double tick (delivered) immediately
6. **Open a chat room** → unread count should drop to 0, messages should show blue ticks (read)

---

## Summary of changes

| File | Change | Purpose |
|------|--------|---------|
| `app.dart` | Add `Timer? _disconnectTimer` field | Hold reference to debounce timer |
| `app.dart` | `dispose()`: cancel timer | Prevent timer leak |
| `app.dart` | `paused`: start 3s timer instead of immediate disconnect | Ignore transient paused events |
| `app.dart` | `hidden`: do nothing (remove the case) | Covered by paused timer |
| `app.dart` | `resumed`: cancel timer + remove `requestPresenceSync()` | Cancel false-alarm disconnects, remove duplicate sync |
| Auth controller | Ensure `wsService.connect(token)` runs on login/restore | Fix second user never connecting WS |
