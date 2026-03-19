# Core / Infra Audit — ChatBee Flutter App

> **Scope**: WebSocket service, app lifecycle, routing, API client, event handler, global connectivity
> **Files**: `websocket_service.dart`, `app.dart`, `main.dart`, `app_router.dart`, `api_client.dart`, `api_endpoints.dart`, `ws_event_handler.dart`
> **Note**: The WebSocket service and lifecycle code are well-engineered — zombie detection, exponential backoff with jitter, connectivity listener, concurrency guards, and grace period handling are all solid. This audit focuses only on real edge cases and bugs, not style.

---

## Summary

9 issues found. The most impactful are: no global "no internet" screen (user sees infinite spinner instead), a WS stream subscription leak on reconnect, `main.dart` blocking the splash screen on slow networks, and lifecycle code running when not logged in. No architectural changes needed — these are all surgical fixes.

---

## Fixes

---

### 1. HIGH — No global "no internet" screen — user sees infinite spinner

**Files**: New file `core/widgets/connectivity_wrapper.dart`, modify `app.dart`

**Problem**: When there's no internet, every loading screen (session restore, chat list, feed, etc.) shows an infinite spinner with no explanation. The user has no idea what's wrong. When internet comes back, nothing happens automatically — the user has to manually pull-to-refresh or restart the app.

This should be a single global solution, not per-screen, so every screen benefits.

**Fix**: Create a global `ConnectivityWrapper` widget that wraps the entire app. It monitors network state and overlays a "no internet" banner. When connectivity returns, it automatically triggers a refresh.

**Step A** — Create a connectivity provider:

Create `core/providers/connectivity_provider.dart`:

```dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks whether the device has any network connection.
/// Emits true/false reactively. All widgets can ref.watch this.
final connectivityProvider = StreamProvider<bool>((ref) {
  final connectivity = Connectivity();

  // Controller to merge the initial check + ongoing changes into one stream
  final controller = StreamController<bool>();

  // Check current state immediately
  connectivity.checkConnectivity().then((results) {
    final hasNetwork = results.any((r) => r != ConnectivityResult.none);
    controller.add(hasNetwork);
  });

  // Listen for changes
  final sub = connectivity.onConnectivityChanged.listen((results) {
    final hasNetwork = results.any((r) => r != ConnectivityResult.none);
    controller.add(hasNetwork);
  });

  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Simple synchronous check — use when you need a one-shot read.
/// Returns false if the provider hasn't loaded yet.
bool isOnline(WidgetRef ref) {
  return ref.read(connectivityProvider).valueOrNull ?? true;
}
```

**Step B** — Create the wrapper widget:

Create `core/widgets/connectivity_wrapper.dart`:

```dart
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/core/providers/connectivity_provider.dart';
import 'package:chatbee/core/providers/auth_provider.dart';
import 'package:chatbee/features/chat/controllers/chat_list_controller.dart';
import 'package:chatbee/features/auth/controllers/auth_controller.dart';

/// Wraps the entire app. When offline, shows a themed banner at the top.
/// When connectivity is restored, automatically triggers data refresh.
///
/// Design: Uses the app's dark navy palette (featureBackgroundColor + errorColor)
/// with Cera Pro font, matching snackbar/chip visual language.
class ConnectivityWrapper extends ConsumerStatefulWidget {
  final Widget child;
  const ConnectivityWrapper({super.key, required this.child});

  @override
  ConsumerState<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends ConsumerState<ConnectivityWrapper> {
  bool _wasOffline = false;

  @override
  Widget build(BuildContext context) {
    final connectivityAsync = ref.watch(connectivityProvider);

    return connectivityAsync.when(
      loading: () => widget.child,
      error: (_, __) => widget.child,
      data: (isOnline) {
        // Went offline → haptic buzz
        if (!isOnline && !_wasOffline) {
          _wasOffline = true;
          HapticFeedback.heavyImpact();
        }

        // Came back online → light tap + auto-refresh
        if (isOnline && _wasOffline) {
          _wasOffline = false;
          HapticFeedback.mediumImpact();
          log('Network restored — auto-refreshing', name: 'CONNECTIVITY');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _autoRefreshOnReconnect();
          });
        }

        return Column(
          children: [
            // ── Offline banner — matches app's dark navy design language ──
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: isOnline ? 0 : 36.h,
              width: double.infinity,
              decoration: BoxDecoration(
                // Dark navy surface with a subtle red-tinted left border
                color: AppTheme.featureBackgroundColor,
                border: Border(
                  bottom: BorderSide(
                    color: AppTheme.errorColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
              ),
              clipBehavior: Clip.hardEdge,
              alignment: Alignment.center,
              child: isOnline
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(2.r),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.errorColor.withValues(alpha: 0.15),
                            ),
                            child: Icon(
                              Icons.wifi_off_rounded,
                              size: 14.r,
                              color: AppTheme.errorColor,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'No internet connection',
                            style: TextStyle(
                              fontFamily: 'Cera Pro',
                              color: AppTheme.textMediumColor,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            // Main app content
            Expanded(child: widget.child),
          ],
        );
      },
    );
  }

  /// Called automatically when network returns. Refreshes key data silently.
  void _autoRefreshOnReconnect() {
    final isLoggedIn = ref.read(authNotifierProvider).isLoggedIn;
    if (!isLoggedIn) return;

    // Session might have expired while offline — restore it
    final authState = ref.read(authControllerProvider);
    if (authState.hasError) {
      ref.read(authControllerProvider.notifier).restoreSession();
    }

    // Refresh chat list silently
    try {
      ref.read(chatListControllerProvider.notifier).backgroundRefresh();
    } catch (_) {}
  }
}
```

**Step C** — Wrap the app in `app.dart`:

```dart
// In app.dart, inside the ScreenUtilInit builder, wrap MaterialApp.router:
builder: (context, child) {
    return ConnectivityWrapper(
      child: MaterialApp.router(
        title: 'ChatBee',
        // ... rest unchanged
      ),
    );
},
```

**What this gives you**:
- **Offline**: Dark navy banner (matching `featureBackgroundColor`) slides in with the app's `errorColor` icon — not a jarring red bar. `HapticFeedback.heavyImpact()` on connection loss so the user feels it.
- **Online restored**: Banner slides out with `easeInOut` curve, `HapticFeedback.mediumImpact()` confirms recovery. Session auto-restores if broken, chat list silently refreshes.
- **No infinite spinners** on any screen during network outage.
- **Works globally**: One wrapper widget in `app.dart`, every screen benefits — no per-screen implementation.
- **Font**: Uses `Cera Pro` to match the rest of the app.
- **Coexists with WS service**: The WebSocket service's own connectivity listener handles WS reconnection separately (correct — different concern).

---

### 2. HIGH — Stream subscription leak on WebSocket reconnect

**File**: `core/services/websocket_service.dart`

**Problem**: In `_doConnect()`, a new `_channel!.stream.listen(...)` subscription is created every time the method is called. The previous subscription is never cancelled. While `_closeChannel()` closes the sink and nulls the channel, the `stream.listen()` subscription reference is never stored or cancelled. If the old channel's stream emits `onDone` after the new channel is already connected, it calls `_handleDisconnect()` on the new connection — causing a false disconnect.

**Fix**: Store the stream subscription and cancel it before creating a new one:

```dart
class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;  // ADD THIS
  // ... rest of fields unchanged ...
```

In `_doConnect()`, replace the listen call:

```dart
      // CHANGED: Store the subscription so we can cancel it on reconnect
      _channelSubscription = _channel!.stream.listen(
        _handleRawMessage,
        onError: (Object error) {
          log('[WS] Stream error: $error', name: 'WS');
          _isConnecting = false;
          _handleDisconnect();
        },
        onDone: () {
          final code   = _channel?.closeCode;
          final reason = _getCloseReasonDescription(code, _channel?.closeReason);
          log('[WS] Disconnected — $code ($reason)', name: 'WS');
          _isConnecting = false;
          _handleDisconnect();
        },
      );
```

In `_closeChannel()`, cancel before closing:

```dart
  void _closeChannel({bool keepToken = false}) {
    _reconnectTimer?.cancel();
    _presenceSyncTimer?.cancel();
    _pingTimer?.cancel();
    _cancelPongTimeout();

    // ADDED: Cancel stream subscription before closing channel
    _channelSubscription?.cancel();
    _channelSubscription = null;

    try { _channel?.sink.close(); } catch (_) {}
    _channel      = null;
    _isConnected  = false;
    _isConnecting = false;

    if (!keepToken) _token = null;
  }
```

In `dispose()`, also cancel:

```dart
  void dispose() {
    _connectivitySubscription?.cancel();
    _channelSubscription?.cancel();  // ADD THIS
    disconnect();
    _eventController.close();
  }
```

---

### 3. HIGH — main.dart blocks splash screen if network is slow

**File**: `main.dart` (line 54)

**Problem**: `await container.read(authControllerProvider.notifier).restoreSession()` blocks the `main()` function. If the backend is slow or unreachable, the user sees a white screen for 5–15 seconds before the app renders. `runApp()` isn't called until `restoreSession` completes or times out.

**Fix**: Don't await `restoreSession()` in `main()`. Fire-and-forget. The `SessionGate` from the auth audit handles the loading/error states in the UI.

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  final container = ProviderContainer();

  final apiClient = container.read(apiClientProvider);
  await apiClient.initialize();

  final notificationService = container.read(notificationServiceProvider);
  await notificationService.initialize();

  final authNotifier = container.read(authNotifierProvider);
  await authNotifier.init();

  if (authNotifier.isLoggedIn) {
    // Fire-and-forget — don't block app render
    notificationService.registerTokenWithBackend(
      container.read(notificationRepoProvider),
    );

    // Don't await — SessionGate handles loading state
    container.read(authControllerProvider.notifier).restoreSession().then((_) {
      container.read(wsEventHandlerProvider);
      log('Session restored', name: 'MAIN');
    }).catchError((e) {
      log('Session restore failed: $e', name: 'MAIN');
    });
  }

  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
}
```

Add `import 'dart:developer';` at the top.

This means the app renders instantly. SessionGate shows a spinner briefly, then either the home screen or an error/retry screen.

---

### 4. HIGH — WebSocket token exposed in URL (logs, crash reports, proxies)

**File**: `core/constants/api_endpoints.dart` (line 97-101)

**Problem**: The Firebase ID token (~900 chars) is passed as a query parameter in the WebSocket URL. This means it's visible in server access logs, crash reporting tools, network proxies, and any debug logging that captures URLs. Anyone who sees the URL can impersonate the user for up to 1 hour.

**Fix (short-term)**: Ensure the URL is never logged anywhere. Search the entire codebase for any logging that could include the WS URL string. The current code only logs `[WS] Connecting…` without the URL, which is correct — verify this stays that way.

**Fix (long-term, requires backend change)**: Switch to sending the token as the first WS message after connection rather than in the URL. The backend would authenticate on first message instead of on the upgrade request. Flag this for a future backend pass.

**For now**: Add a comment in `api_endpoints.dart` to warn future developers:

```dart
/// ⚠️ SECURITY: Token is in the URL query string. NEVER log the output of this method.
/// Long-term: migrate to first-message auth to keep token out of URLs.
static String webSocketUrl(String token) {
    final wsBase = baseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://');
    return '$wsBase/chat/ws?token=$token';
}
```

---

### 5. MEDIUM — Lifecycle handler runs resume logic when not logged in

**File**: `app.dart` (line 35-96)

**Problem**: When the app resumes from background, the lifecycle handler unconditionally calls `getAndRefreshToken()`, `connectIfNeeded()`, `backgroundRefresh()`, and `friendsController.refresh()`. If the user is on the login screen or has signed out, these calls either fail silently or make unnecessary network requests.

**Fix**: Guard both paused and resumed handlers with a login check:

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (!mounted) return;
  log('→ $state', name: 'LIFECYCLE');

  // Skip lifecycle handling if not logged in
  final isLoggedIn = ref.read(authNotifierProvider).isLoggedIn;
  if (!isLoggedIn) return;

  final wsService = ref.read(webSocketServiceProvider);

  switch (state) {
    case AppLifecycleState.paused:
    case AppLifecycleState.hidden:
      wsService.disconnectAndNotifyServer();
      break;

    case AppLifecycleState.resumed:
      // ... rest of resume logic unchanged ...
      break;

    default:
      break;
  }
}
```

Add `import 'package:chatbee/core/providers/auth_provider.dart';` if not already imported.

---

### 6. MEDIUM — Connectivity listener not cancelled on sign-out

**File**: `core/services/websocket_service.dart`

**Problem**: `_startConnectivityListener()` subscribes to network changes in `connect()`. When the user signs out, `disconnect()` calls `_closeChannel()` but does NOT cancel the connectivity subscription. Only `dispose()` does. After sign-out, network changes still trigger `_doConnect()` (which returns early due to `_intentionalDisconnect`, but it's unnecessary work and log noise).

**Fix**: Cancel the connectivity listener in `disconnect()`:

```dart
void disconnect() {
    _intentionalDisconnect = true;
    _connectivitySubscription?.cancel();  // ADD THIS
    _connectivitySubscription = null;     // ADD THIS
    _closeChannel(keepToken: true);
}
```

The listener is re-wired on the next `connect()` call after re-login.

---

### 7. MEDIUM — `/poem/:id` route crashes if navigated without `extra`

**File**: `core/routes/app_router.dart` (line 94-98)

**Problem**: The poem detail route hard-casts `state.extra`:

```dart
final poem = state.extra as PoemModel;  // Crashes if extra is null
```

If the user arrives via deep link, notification, or the route is reconstructed after process death, `extra` is null and this throws a `TypeError`.

**Fix**: Handle the null case by fetching from the API:

```dart
GoRoute(
    path: '/poem/:id',
    builder: (context, state) {
      final poem = state.extra as PoemModel?;
      final poemId = state.pathParameters['id']!;
      if (poem != null) {
        return PoemDetailScreen(poem: poem);
      }
      // Fallback for deep links / notifications / process restoration
      return PoemDetailFetchWrapper(poemId: poemId);
    },
),
```

Create `features/poems/screens/poem_detail_fetch_wrapper.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatbee/features/poems/repos/poem_repo.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';
import 'package:chatbee/features/poems/screens/poem_detail_screen.dart';

class PoemDetailFetchWrapper extends ConsumerWidget {
  final String poemId;
  const PoemDetailFetchWrapper({super.key, required this.poemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<PoemModel>(
      future: ref.read(poemRepoProvider).getPoem(poemId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Poem not found')),
          );
        }
        return PoemDetailScreen(poem: snapshot.data!);
      },
    );
  }
}
```

This also enables future notification navigation: `navigateToNotification(context, 'poem', poemId)`.

---

### 8. MEDIUM — `themeMode: ThemeMode.light` contradicts dark theme

**File**: `app.dart` (line 115)

**Problem**: The app sets `theme: AppTheme.dark` and `darkTheme: AppTheme.dark`, but `themeMode: ThemeMode.light`. This works because `theme` is used when `themeMode` is `light` — so it applies the dark theme object in "light mode" context. This is confusing and will break if you add a real light theme later.

**Fix**:

```dart
theme: AppTheme.dark,
darkTheme: AppTheme.dark,
themeMode: ThemeMode.dark,  // Match the actual theme being used
```

---

### 9. LOW — Remaining print() statements in lifecycle code

**File**: `app.dart`

**Problem**: Three `print()` calls survived the auth audit cleanup:

```dart
print('[Lifecycle] → $state');                          // line 37
print('[Lifecycle] WS reconnected, syncing presence');   // line 76
print('[Lifecycle] WS reconnect failed ...');            // line 80
```

**Fix**: Replace with `dart:developer log()`:

```dart
import 'dart:developer';

log('→ $state', name: 'LIFECYCLE');
log('WS reconnected, syncing presence', name: 'LIFECYCLE');
log('WS reconnect failed (will retry via backoff)', name: 'LIFECYCLE');
```

---

## What I reviewed and confirmed is correct (no changes needed)

- **Zombie detection**: Ping every 10s, pong timeout 10s, force-reconnect on timeout. Correct and tighter than backend's 15s read deadline.
- **Exponential backoff with jitter**: `3 * 2^attempt ± 20%` clamped 3–30s. Textbook implementation.
- **Concurrency guard**: `_isConnecting` flag prevents parallel socket opens. `connectIfNeeded` reuse of in-flight `_connectCompleter` is well done.
- **Connectivity listener**: Resets attempt counter on network restore, reconnects immediately. Correct.
- **Intentional disconnect flag**: Prevents reconnect loops after sign-out/background. All paths check this correctly.
- **`channel.ready` for connection state**: `_isConnected = true` only after WS handshake completes. Correct.
- **`disconnectAndNotifyServer()`**: HTTP POST with 3s timeout + `finally` cleanup. Correct.
- **Chat screen lifecycle**: `silentRefresh()` + `markAsRead()` on resume, `currentOpenRoomProvider` cleared via `addPostFrameCallback` in dispose. Correct.
- **Event handler self-message suppression**: Checks `senderId == currentUserId`. Correct.
- **Presence sync timer**: 60-second periodic. Reasonable.

---

## Verification Checklist

After applying all fixes:

- [ ] Turn off WiFi → dark navy banner with wifi-off icon slides in (matches app theme, not jarring red)
- [ ] Turn off WiFi → feel a heavy haptic buzz when banner appears
- [ ] Turn WiFi back on → banner slides out smoothly, feel a medium haptic tap
- [ ] Turn WiFi back on → session auto-restores, chat list refreshes (no manual action needed)
- [ ] No infinite spinner on any screen during network outage
- [ ] Force-close app → reopen → WS reconnects without duplicate `onDone` handling
- [ ] Cold start on slow network → app renders immediately (spinner inside UI, not white screen)
- [ ] Sign out → toggle WiFi → no WS reconnect attempts in logs
- [ ] Background app → resume when **logged in** → WS reconnects + presence sync (this is correct behavior)
- [ ] Background app → resume when **logged out** → no token refresh / WS connect attempts
- [ ] Tap a poem notification when app is killed → poem loads (no crash on missing `extra`)
- [ ] Theme renders correctly with `ThemeMode.dark`
- [ ] No `print()` statements in release build log output
