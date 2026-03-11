# Frontend: Notification System Implementation Guide

This adds notification support to your Flutter app. It follows your existing patterns:
model → repo → controller → screen, with Riverpod for state and GoRouter for navigation.

The system covers three things:
1. **Notification screen** — paginated list with tap-to-navigate
2. **Real-time updates** — WebSocket events update the badge and list instantly
3. **Push notification handling** — FCM taps navigate to the right screen

---

## 1. API Endpoints

Add to your `ApiEndpoints` class:

**File: `lib/core/constants/api_endpoints.dart`**

Add these constants:

```dart
// Notifications
static const String notifications = '/notifications';
static const String notificationsUnreadCount = '/notifications/unread-count';
static String notificationRead(String id) => '/notifications/$id/read';
static const String notificationsReadAll = '/notifications/read-all';

// FCM Token
static const String registerFCMToken = '/users/me/fcm-token';
```

---

## 2. Model

**File: `lib/features/notifications/models/notification_model.dart`**

```dart
import 'package:json_annotation/json_annotation.dart';

part 'notification_model.g.dart';

@JsonSerializable()
class NotificationModel {
  final String id;
  final String type;
  final String resourceType;
  final String resourceId;
  final String title;
  final String body;
  final String actorId;
  final String? actorName;
  final String? actorPhotoUrl;
  final bool isRead;
  final DateTime? createdAt;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.resourceType,
    required this.resourceId,
    required this.title,
    required this.body,
    required this.actorId,
    this.actorName,
    this.actorPhotoUrl,
    this.isRead = false,
    this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      _$NotificationModelFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationModelToJson(this);

  NotificationModel copyWith({
    String? id,
    String? type,
    String? resourceType,
    String? resourceId,
    String? title,
    String? body,
    String? actorId,
    String? actorName,
    String? actorPhotoUrl,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      type: type ?? this.type,
      resourceType: resourceType ?? this.resourceType,
      resourceId: resourceId ?? this.resourceId,
      title: title ?? this.title,
      body: body ?? this.body,
      actorId: actorId ?? this.actorId,
      actorName: actorName ?? this.actorName,
      actorPhotoUrl: actorPhotoUrl ?? this.actorPhotoUrl,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
```

---

## 3. Repository

**File: `lib/features/notifications/repos/notification_repo.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/core/constants/api_endpoints.dart';
import 'package:chatbee/core/network/api_client.dart';
import 'package:chatbee/features/notifications/models/notification_model.dart';

part 'notification_repo.g.dart';

class NotificationRepo {
  final ApiClient apiClient;

  NotificationRepo({required this.apiClient});

  /// Get paginated notifications.
  Future<(List<NotificationModel>, bool)> getNotifications({
    int limit = 20,
    String? before,
  }) async {
    final query = <String, dynamic>{'limit': limit};
    if (before != null) query['before'] = before;

    final response = await apiClient.get(
      ApiEndpoints.notifications,
      queryParameters: query,
    );

    final data = response.data as Map<String, dynamic>;
    final list = data['notifications'] as List;
    final hasMore = data['hasMore'] as bool? ?? false;

    final notifications = list
        .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return (notifications, hasMore);
  }

  /// Get unread notification count (for badge).
  Future<int> getUnreadCount() async {
    final response = await apiClient.get(ApiEndpoints.notificationsUnreadCount);
    final data = response.data as Map<String, dynamic>;
    return data['count'] as int? ?? 0;
  }

  /// Mark a single notification as read.
  Future<void> markAsRead(String notifId) async {
    await apiClient.post(ApiEndpoints.notificationRead(notifId));
  }

  /// Mark all notifications as read.
  Future<void> markAllAsRead() async {
    await apiClient.post(ApiEndpoints.notificationsReadAll);
  }

  /// Register FCM token with backend.
  Future<void> registerFCMToken(String token) async {
    await apiClient.post(ApiEndpoints.registerFCMToken, data: {'token': token});
  }
}

@riverpod
NotificationRepo notificationRepo(Ref ref) {
  return NotificationRepo(apiClient: ref.read(apiClientProvider));
}
```

---

## 4. Controller

**File: `lib/features/notifications/controllers/notification_controller.dart`**

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/features/notifications/models/notification_model.dart';
import 'package:chatbee/features/notifications/repos/notification_repo.dart';

part 'notification_controller.g.dart';

/// Manages the notification list and unread badge count.
@Riverpod(keepAlive: true)
class NotificationController extends _$NotificationController {
  bool _hasMore = true;
  bool _isLoadingOlder = false;

  @override
  FutureOr<List<NotificationModel>> build() async {
    final result = await ref.read(notificationRepoProvider).getNotifications();
    _hasMore = result.$2;
    return result.$1;
  }

  /// Pull-to-refresh.
  Future<void> refresh() async {
    _hasMore = true;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final result = await ref.read(notificationRepoProvider).getNotifications();
      _hasMore = result.$2;
      return result.$1;
    });
  }

  /// Load older notifications (pagination).
  Future<void> loadOlder() async {
    if (!_hasMore || _isLoadingOlder) return;
    _isLoadingOlder = true;

    try {
      final current = state.valueOrNull ?? [];
      if (current.isEmpty) return;

      final result = await ref.read(notificationRepoProvider).getNotifications(
        before: current.last.id,
      );

      _hasMore = result.$2;
      state = AsyncValue.data([...current, ...result.$1]);
    } finally {
      _isLoadingOlder = false;
    }
  }

  /// Mark a single notification as read (optimistic).
  Future<void> markAsRead(String notifId) async {
    final current = state.valueOrNull;
    if (current == null) return;

    // Optimistic update
    state = AsyncValue.data(
      current.map((n) {
        if (n.id == notifId) return n.copyWith(isRead: true);
        return n;
      }).toList(),
    );

    // Update badge
    ref.read(unreadNotificationCountProvider.notifier).decrement();

    try {
      await ref.read(notificationRepoProvider).markAsRead(notifId);
    } catch (e) {
      // Revert on failure
      state = AsyncValue.data(
        current.map((n) {
          if (n.id == notifId) return n.copyWith(isRead: false);
          return n;
        }).toList(),
      );
      ref.read(unreadNotificationCountProvider.notifier).increment();
    }
  }

  /// Mark all as read.
  Future<void> markAllAsRead() async {
    final current = state.valueOrNull;
    if (current == null) return;

    state = AsyncValue.data(
      current.map((n) => n.copyWith(isRead: true)).toList(),
    );
    ref.read(unreadNotificationCountProvider.notifier).reset();

    try {
      await ref.read(notificationRepoProvider).markAllAsRead();
    } catch (e) {
      // Refresh from server on failure
      refresh();
    }
  }

  /// Add a real-time notification from WebSocket (prepend to top).
  void addFromWebSocket(NotificationModel notif) {
    final current = state.valueOrNull ?? [];
    // Avoid duplicates
    if (current.any((n) => n.id == notif.id)) return;
    state = AsyncValue.data([notif, ...current]);
    ref.read(unreadNotificationCountProvider.notifier).increment();
  }
}

/// Separate provider for badge count so it can be watched independently
/// without rebuilding the full notification list.
@Riverpod(keepAlive: true)
class UnreadNotificationCount extends _$UnreadNotificationCount {
  @override
  int build() {
    // Initial fetch
    _fetchCount();
    return 0;
  }

  Future<void> _fetchCount() async {
    try {
      final count = await ref.read(notificationRepoProvider).getUnreadCount();
      state = count;
    } catch (_) {}
  }

  void increment() => state = state + 1;
  void decrement() => state = (state - 1).clamp(0, 99999);
  void reset() => state = 0;

  /// Re-fetch from server (e.g. on app resume).
  Future<void> refresh() async => _fetchCount();
}
```

---

## 5. WebSocket Integration

**File: `lib/core/services/websocket_service.dart`**

Add `notification` to `WsEventType`:

```dart
enum WsEventType {
  // ... existing types ...
  notification; // ← add this

  static WsEventType? fromString(String? value) {
    switch (value) {
      // ... existing cases ...
      case 'notification':
        return WsEventType.notification;
      default:
        return null;
    }
  }

  String get value {
    switch (this) {
      // ... existing cases ...
      case WsEventType.notification:
        return 'notification';
    }
  }
}
```

**File: `lib/features/chat/controllers/ws_event_handler.dart`**

Add the handler for the new event type. In the `switch` inside `wsEventHandler`:

```dart
case WsEventType.notification:
  _handleNotification(ref, event);
  break;
```

Add the handler function:

```dart
void _handleNotification(Ref ref, WsEvent event) {
  try {
    final notif = NotificationModel.fromJson(event.payload);
    ref.read(notificationControllerProvider.notifier).addFromWebSocket(notif);
  } catch (e) {
    log('Error handling notification event: $e', name: 'WS');
  }
}
```

Add the import at the top:

```dart
import 'package:chatbee/features/notifications/models/notification_model.dart';
import 'package:chatbee/features/notifications/controllers/notification_controller.dart';
```

---

## 6. Navigation Helper

**File: `lib/features/notifications/utils/notification_navigator.dart`**

This is the reusable piece. When you add posts, comments, or any new feature,
you only add a case here. Nothing else changes.

```dart
import 'package:go_router/go_router.dart';
import 'package:flutter/widgets.dart';

/// Routes the user to the right screen based on notification content.
/// Add new cases here when you add new features (posts, comments, etc.).
void navigateToNotification(BuildContext context, String resourceType, String resourceId) {
  switch (resourceType) {
    case 'chat_room':
      context.push('/chat/$resourceId');
      break;
    case 'connection':
      // Navigate to the connections/friends tab
      // You may want to pass a parameter to highlight the specific request
      context.push('/home'); // or a dedicated connections route
      break;
    // Future cases:
    // case 'post':
    //   context.push('/post/$resourceId');
    //   break;
    // case 'comment':
    //   context.push('/post/$resourceId'); // navigate to the post containing the comment
    //   break;
    // case 'user_profile':
    //   context.push('/profile/$resourceId');
    //   break;
    default:
      // Unknown type — go home
      context.push('/home');
  }
}
```

---

## 7. Notification Screen

**File: `lib/features/notifications/screens/notification_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/features/notifications/controllers/notification_controller.dart';
import 'package:chatbee/features/notifications/models/notification_model.dart';
import 'package:chatbee/features/notifications/utils/notification_navigator.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(notificationControllerProvider.notifier).loadOlder();
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifState = ref.watch(notificationControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(notificationControllerProvider.notifier).markAllAsRead();
            },
            child: Text(
              'Read all',
              style: TextStyle(fontSize: 13.sp, color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
      body: notifState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(e.toString(), style: TextStyle(fontSize: 14.sp, color: Colors.red)),
              SizedBox(height: 8.h),
              TextButton(
                onPressed: () => ref.read(notificationControllerProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none_rounded, size: 64.r, color: AppTheme.textLightColor),
                  SizedBox(height: 12.h),
                  Text('No notifications yet', style: TextStyle(fontSize: 16.sp, color: AppTheme.textMediumColor)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(notificationControllerProvider.notifier).refresh(),
            child: ListView.separated(
              controller: _scrollController,
              itemCount: notifications.length,
              separatorBuilder: (_, __) => Divider(height: 1, indent: 72.w, color: AppTheme.borderColor),
              itemBuilder: (context, index) {
                final notif = notifications[index];
                return _NotificationTile(
                  notification: notif,
                  onTap: () {
                    // Mark as read on tap
                    if (!notif.isRead) {
                      ref.read(notificationControllerProvider.notifier).markAsRead(notif.id);
                    }
                    // Navigate based on resourceType
                    navigateToNotification(context, notif.resourceType, notif.resourceId);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  IconData _iconForType(String type) {
    switch (type) {
      case 'connection_request':
        return Icons.person_add_rounded;
      case 'connection_accepted':
        return Icons.people_rounded;
      case 'new_message':
        return Icons.chat_bubble_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isUnread ? AppTheme.primaryColor.withValues(alpha: 0.05) : null,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Actor avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 24.r,
                  backgroundColor: AppTheme.primaryLight,
                  backgroundImage: notification.actorPhotoUrl != null
                      ? CachedNetworkImageProvider(notification.actorPhotoUrl!)
                      : null,
                  child: notification.actorPhotoUrl == null
                      ? Icon(_iconForType(notification.type), size: 20.r, color: AppTheme.primaryColor)
                      : null,
                ),
                // Type badge
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 18.r,
                    height: 18.r,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      _iconForType(notification.type),
                      size: 10.r,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(width: 12.w),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: TextStyle(fontSize: 14.sp, color: AppTheme.textDarkColor),
                      children: [
                        TextSpan(
                          text: notification.actorName ?? 'Someone',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: '  ${notification.body}'),
                      ],
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    notification.createdAt != null
                        ? timeago.format(notification.createdAt!)
                        : '',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: isUnread ? AppTheme.primaryColor : AppTheme.textLightColor,
                      fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            // Unread dot
            if (isUnread)
              Padding(
                padding: EdgeInsets.only(top: 6.h, left: 8.w),
                child: Container(
                  width: 8.r,
                  height: 8.r,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

---

## 8. Badge on Bottom Navigation

Wherever your bottom nav is (likely `HomeScreen`), add a badge to the
notifications tab icon. Watch the `unreadNotificationCountProvider`:

```dart
// Inside your bottom navigation bar builder:
Consumer(
  builder: (context, ref, child) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    return Badge(
      isLabelVisible: unreadCount > 0,
      label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
      child: const Icon(Icons.notifications_outlined),
    );
  },
),
```

---

## 9. Push Notification Tap Navigation

**File: `lib/core/services/notification_service.dart`**

Update the existing handlers to navigate on tap. You need access to the router.

Add a static navigator key or use GoRouter's context:

```dart
import 'package:chatbee/features/notifications/utils/notification_navigator.dart';
import 'package:chatbee/core/routes/app_router.dart';

// In _setupMessageHandlers, update the onMessageOpenedApp handler:
FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
  log('Message clicked! App opened from background: ${message.messageId}', name: 'FCM');
  _handleNotificationTap(message.data);
});

// Update getInitialMessage handler:
_fcm.getInitialMessage().then((RemoteMessage? message) {
  if (message != null) {
    log('App launched from terminated state via notification', name: 'FCM');
    // Store the data to handle after the app is fully initialized
    _pendingNotificationData = message.data;
  }
});

// Add a field to store pending navigation:
Map<String, dynamic>? _pendingNotificationData;

// Add a method to check and handle pending navigation (call after app is ready):
void handlePendingNotification(BuildContext context) {
  if (_pendingNotificationData != null) {
    _handleNotificationNavigation(context, _pendingNotificationData!);
    _pendingNotificationData = null;
  }
}

void _handleNotificationNavigation(BuildContext context, Map<String, dynamic> data) {
  final resourceType = data['resourceType'] as String?;
  final resourceId = data['resourceId'] as String?;

  if (resourceType != null && resourceId != null) {
    navigateToNotification(context, resourceType, resourceId);
  }
}
```

Update `onDidReceiveNotificationResponse` in `_setupLocalNotifications`:

```dart
onDidReceiveNotificationResponse: (NotificationResponse response) {
  log('Local notification tapped: ${response.payload}', name: 'FCM');
  // Parse the data payload and navigate
  // The payload is the stringified data map from the FCM message
  // You'll need to parse it back to a Map and call _handleNotificationNavigation
},
```

---

## 10. FCM Token Registration

**File: `lib/core/services/notification_service.dart`**

Update `initialize()` to register the token with your backend after getting it:

```dart
Future<void> initialize({NotificationRepo? notificationRepo}) async {
  if (_isInitialized) return;

  await requestPermissions();
  await _setupLocalNotifications();
  _setupMessageHandlers();

  // Get and register FCM token
  final token = await getFCMToken();
  if (token != null && notificationRepo != null) {
    try {
      await notificationRepo.registerFCMToken(token);
      log('FCM token registered with backend', name: 'FCM');
    } catch (e) {
      log('Failed to register FCM token: $e', name: 'FCM');
    }
  }

  // Listen for token refresh
  _fcm.onTokenRefresh.listen((newToken) async {
    if (notificationRepo != null) {
      try {
        await notificationRepo.registerFCMToken(newToken);
        log('Refreshed FCM token registered', name: 'FCM');
      } catch (e) {
        log('Failed to register refreshed token: $e', name: 'FCM');
      }
    }
  });

  _isInitialized = true;
}
```

---

## 11. Route Registration

**File: `lib/core/routes/app_router.dart`**

Add the notification screen route:

```dart
GoRoute(
  path: '/notifications',
  builder: (context, state) => const NotificationScreen(),
),
```

---

## 12. Refresh Badge on App Resume

**File: `lib/app.dart`**

In `didChangeAppLifecycleState`, inside the `resumed` case, add:

```dart
// Refresh notification badge count
ref.read(unreadNotificationCountProvider.notifier).refresh();
```

---

## File Structure Summary

```
lib/features/notifications/
├── models/
│   └── notification_model.dart
├── repos/
│   └── notification_repo.dart
├── controllers/
│   └── notification_controller.dart
├── screens/
│   └── notification_screen.dart
└── utils/
    └── notification_navigator.dart
```

---

## Adding New Features Later

When you add posts, comments, or any new feature to a future app:

**Backend:** Call `notifService.Send(...)` with the new `Type` and `ResourceType` constants. Add the constants to the model file. That's it.

**Frontend:**
1. Add a case to `notification_navigator.dart` for the new `resourceType`
2. Add an icon case to `_iconForType` in the notification tile
3. Add a route in `app_router.dart` for the new screen

Nothing else changes. The notification screen, controller, repo, badge,
push handling, and WebSocket integration all work automatically.
