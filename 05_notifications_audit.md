# Notifications Feature Audit — ChatBee Flutter App

> **Scope**: Notification list, badge count, FCM push, local notifications, navigation from notifications, WS real-time notifications
> **Files**: `notification_controller.dart`, `notification_screen.dart`, `notification_service.dart`, `notification_navigator.dart`, `notification_repo.dart`, `notification_model.dart`, `notification_bell.dart`
> **Note**: The notification system is clean — optimistic mark-as-read with rollback, separate badge provider, WS real-time prepend with deduplication, and FCM background handler are all well-implemented.

---

## Summary

7 issues found. The most impactful: notification navigation is incomplete (most notification types go nowhere useful), pending notification from terminated-state launch is never consumed, FCM `onTokenRefresh` listener leaks a subscription, and the badge count drifts out of sync over time.

---

## Fixes

---

### 1. HIGH — Notification navigation is incomplete — most types go to /home

**File**: `notification_navigator.dart`

**Problem**: The navigator only handles `chat_room` and `connection`. All other notification types (`poem_liked`, `commented`, `comment_liked`, `reposted`, `followed`, `mentioned`) fall through to the `default` case which pushes `/home`. The user taps "Asif liked your poem" and gets sent to the home feed — not the poem.

The backend sends `resourceType` and `resourceId` for each notification. These need to be mapped to the correct screen.

**Fix**: Add cases for all notification types your backend sends:

```dart
void navigateToNotification(BuildContext context, String resourceType, String resourceId) {
  // Guard against empty values
  if (resourceType.isEmpty || resourceId.isEmpty) return;

  switch (resourceType) {
    case 'chat_room':
      context.push('/chat/$resourceId');
      break;
    case 'poem':
      // Navigate to poem detail — uses the fetch wrapper from core/infra audit
      context.push('/poem/$resourceId');
      break;
    case 'user':
    case 'profile':
      // Navigate to user profile (for followed, connection_accepted)
      context.push('/profile/$resourceId');
      break;
    case 'comment':
      // Comments are on poems — resourceId should be the poemId.
      // If backend sends commentId instead, this needs a backend change.
      // For now, try navigating as a poem. If it fails, user sees "Poem not found".
      context.push('/poem/$resourceId');
      break;
    default:
      context.push('/home');
  }
}
```

Also update `_handleNotificationNavigation` in `notification_service.dart` to add null safety for the FCM data path:

```dart
void _handleNotificationNavigation(BuildContext context, Map<String, dynamic> data) {
    final resourceType = data['resourceType'] as String?;
    final resourceId = data['resourceId'] as String?;

    if (resourceType != null && resourceType.isNotEmpty &&
        resourceId != null && resourceId.isNotEmpty) {
      navigateToNotification(context, resourceType, resourceId);
    }
}
```

**Important**: Verify what `resourceType` values your backend actually sends for each notification type. Check the Go `notifications/service.go`. The mapping above assumes:
- `poem_liked` → resourceType: `poem`, resourceId: poemId
- `commented` → resourceType: `poem`, resourceId: poemId
- `followed` → resourceType: `user`, resourceId: followerId
- `reposted` → resourceType: `poem`, resourceId: poemId

If the backend uses different values, update the switch cases to match.

---

### 2. HIGH — Pending notification from terminated-state launch is never consumed

**File**: `notification_service.dart`, `app.dart`

**Problem**: When the app is killed and the user taps a push notification to launch it, `getInitialMessage()` captures the data into `_pendingNotificationData`. The `handlePendingNotification(context)` method exists to consume it — but it's never called anywhere.

Additionally, `onMessageOpenedApp` (background → foreground tap) stores data into `_pendingNotificationData` and waits for someone to consume it. Since the app is already running in this case, it should navigate immediately — not store and wait.

**Fix (3 steps)**:

**Step A** — Create a global navigator key so the service can navigate without widget context:

In `core/routes/app_router.dart`, add a global key:

```dart
/// Global navigator key — used by NotificationService to navigate from outside widget tree.
final rootNavigatorKey = GlobalKey<NavigatorState>();
```

Pass it to GoRouter:

```dart
return GoRouter(
    navigatorKey: rootNavigatorKey,  // ADD THIS
    initialLocation: '/login',
    // ... rest unchanged
);
```

**Step B** — Update `onMessageOpenedApp` to navigate immediately (app is already running):

```dart
void _setupMessageHandlers() {
    // 1. Foreground messages — unchanged
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log('Received foreground message: ${message.messageId}', name: 'FCM');
      _showLocalNotification(message);
    });

    // 2. Background → foreground tap: navigate immediately (app is running)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      log('Message clicked! App opened from background: ${message.messageId}', name: 'FCM');
      final data = message.data;
      final resourceType = data['resourceType'] as String?;
      final resourceId = data['resourceId'] as String?;
      if (resourceType != null && resourceId != null) {
        final context = rootNavigatorKey.currentContext;
        if (context != null) {
          navigateToNotification(context, resourceType, resourceId);
        } else {
          // Context not ready yet — store for later
          _pendingNotificationData = data;
        }
      }
    });

    // 3. Terminated state: store for later (app not running yet)
    _fcm.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        log('App launched from terminated state via notification', name: 'FCM');
        _pendingNotificationData = message.data;
      }
    });
}
```

Import `rootNavigatorKey` from `app_router.dart` and `navigateToNotification` from `notification_navigator.dart`.

**Step C** — Consume pending notification on app ready:

In `home_screen.dart` (or `SessionGate`), add to `initState`:

```dart
@override
void initState() {
  super.initState();
  // ... existing code ...

  // Consume pending notification from terminated-state launch
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    ref.read(notificationServiceProvider).handlePendingNotification(context);
  });
}
```

The flow:
- **Terminated → tap push**: `getInitialMessage` stores data → app renders → HomeScreen consumes and navigates
- **Background → tap push**: `onMessageOpenedApp` navigates immediately via `rootNavigatorKey`
- **Foreground push**: Shows local notification → user taps → `onDidReceiveNotificationResponse` stores data → HomeScreen consumes

---

### 3. HIGH — FCM `onTokenRefresh` listener leaks a subscription on every call

**File**: `notification_service.dart` (line 61-66)

**Problem**: `registerTokenWithBackend` is called on every login and on every app resume. Each call creates a new `_fcm.onTokenRefresh.listen(...)` subscription without cancelling the previous one. After several resume cycles, multiple listeners are all registering the token.

**Fix**: Store the subscription, cancel before re-subscribing, and add a cleanup method for logout:

```dart
class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  Map<String, dynamic>? _pendingNotificationData;
  StreamSubscription? _tokenRefreshSubscription;  // ADD THIS

  Future<void> registerTokenWithBackend(NotificationRepo repo) async {
    final token = await _fcm.getToken();
    if (token != null) {
      try {
        await repo.registerFCMToken(token);
        log('FCM token registered with backend', name: 'FCM');
      } catch (e) {
        log('Failed to register FCM token: $e', name: 'FCM');
      }
    }

    // Cancel previous listener before adding new one
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _fcm.onTokenRefresh.listen((newToken) async {
      try {
        await repo.registerFCMToken(newToken);
        log('Refreshed FCM token registered', name: 'FCM');
      } catch (_) {}
    });
  }

  /// Call on logout to stop listening for token refreshes.
  void cleanup() {
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _pendingNotificationData = null;
  }
}
```

Then in `auth_controller.dart signOut()`, call cleanup:

```dart
Future<void> signOut() async {
    ref.read(webSocketServiceProvider).disconnect();
    ref.read(notificationServiceProvider).cleanup();  // ADD THIS
    await ref.read(authRepoProvider).signOut();
    // ... rest unchanged
}
```

Add `import 'dart:async';` to `notification_service.dart` if not present.

---

### 4. MEDIUM — Badge count drifts out of sync over time

**File**: `notification_controller.dart`

**Problem**: The `UnreadNotificationCount` provider fetches the count once on build, then relies on `increment()` / `decrement()` / `reset()` calls to stay in sync. Over time, these can drift:
- If a WS notification event is missed (network glitch during delivery), the count is never incremented
- If `markAsRead` fails but the catch block doesn't fire (e.g., request times out after the optimistic decrement), the count is off by one
- Multiple devices: reading on another device doesn't update this device's count

**Fix**: Periodically re-sync the badge count from the server. Add a refresh on app resume and on notification screen open:

In `notification_screen.dart initState`:

```dart
@override
void initState() {
  super.initState();
  _scrollController.addListener(_onScroll);
  
  // Re-sync badge count from server when screen opens
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ref.read(unreadNotificationCountProvider.notifier).refresh();
  });
}
```

In `app.dart` lifecycle resume handler, add after the existing refreshes:

```dart
// ── Step 3: Refresh UI data ──
ref.read(chatListControllerProvider.notifier).backgroundRefresh();
ref.read(friendsControllerProvider.notifier).refresh();
// ADDED: Re-sync notification badge count
ref.read(unreadNotificationCountProvider.notifier).refresh();
```

---

### 5. MEDIUM — Local notification only shows on Android (iOS silently drops)

**File**: `notification_service.dart` (line 200-223)

**Problem**: `_showLocalNotification` checks `notification != null && android != null` before showing. On iOS, `android` is always null — so the local notification code never fires on iOS.

However, on iOS, `setForegroundNotificationPresentationOptions(alert: true, ...)` already tells the OS to display the push notification natively in the foreground. So iOS doesn't need the local notification fallback — it's already handled.

The real issue is only on Android: the `android != null` check is correct for Android because the backend includes Android-specific fields. But if the backend ever sends a push without Android fields (data-only message), the notification silently drops.

**Fix**: Keep the Android-only behavior but make it more robust. Use platform check instead of relying on the `android` field:

```dart
import 'dart:io' show Platform;

void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    // iOS handles foreground display via setForegroundNotificationPresentationOptions.
    // Only Android needs the local notification fallback.
    if (!Platform.isAndroid) return;

    _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription: 'This channel is used for important notifications.',
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(message.data),
    );
}
```

This prevents duplicate notifications on iOS (FCM native display + local notification) while ensuring Android always shows foreground notifications.

---

### 6. MEDIUM — Missing haptic feedback on notification interactions

**File**: `notification_screen.dart`

**Problem**: Tapping a notification and "Read all" have no haptic feedback. These are intentional user actions that should feel responsive.

**Fix**:

On notification tap (line 99-106):

```dart
return _NotificationTile(
  notification: notif,
  onTap: () {
    HapticFeedback.selectionClick();  // ADD THIS
    if (!notif.isRead) {
      ref.read(notificationControllerProvider.notifier).markAsRead(notif.id);
    }
    navigateToNotification(context, notif.resourceType, notif.resourceId);
  },
);
```

On "Read all" (line 50-52):

```dart
TextButton(
  onPressed: () {
    HapticFeedback.lightImpact();  // ADD THIS
    ref.read(notificationControllerProvider.notifier).markAllAsRead();
  },
  child: Text('Read all', style: TextStyle(fontSize: 13.sp, color: AppTheme.primaryColor)),
),
```

Add `import 'package:flutter/services.dart';` to `notification_screen.dart`.

---

### 7. LOW — `timeago` may show UTC-based relative times

**File**: `notification_screen.dart` (line 223-224)

**Problem**: Same issue as chat timestamps — `notification.createdAt` may be UTC. `timeago.format()` computes relative time from `DateTime.now()`, and if `createdAt` is UTC while `now()` is local, the relative time is wrong (off by timezone offset).

**Fix**: Convert to local time before formatting:

```dart
Text(
  notification.createdAt != null
      ? timeago.format(
          notification.createdAt!.isUtc
              ? notification.createdAt!.toLocal()
              : notification.createdAt!,
        )
      : '',
  // ... style unchanged
),
```

---

## What I reviewed and confirmed is correct (no changes needed)

- **Optimistic mark-as-read with rollback**: Decrements badge, marks read locally, reverts on API failure. Correct.
- **Separate badge provider**: `UnreadNotificationCount` is independent from the notification list — avoids full-list rebuild on badge change. Good architecture.
- **WS notification prepend with deduplication**: `addFromWebSocket` checks for duplicate IDs. Correct.
- **Pagination with cursor**: `loadOlder` uses `before: current.last.id`. Correct.
- **Notification bell widget**: Watches badge count, shows 99+ cap. Clean.
- **FCM background handler**: Top-level function with `@pragma('vm:entry-point')`. Correct Android requirement.
- **`_isLoadingOlder` guard**: Prevents parallel pagination requests. Correct.

---

## Verification Checklist

After applying all fixes:

- [ ] Tap "Asif liked your poem" notification → navigates to poem detail (not home)
- [ ] Tap "Asif followed you" notification → navigates to Asif's profile
- [ ] Kill app → receive push → tap push → app opens → navigates to correct screen
- [ ] Background app → receive push → tap push → app opens → navigates correctly
- [ ] Login → resume → login again → only one FCM token refresh listener active
- [ ] Open notification screen → badge count re-syncs from server
- [ ] Resume from background → badge count refreshes
- [ ] iOS foreground: notification banner appears (not silently dropped)
- [ ] Tap notification → feel selection click haptic
- [ ] Tap "Read all" → feel light haptic
- [ ] Notification timestamps show correct relative time in non-UTC timezone
