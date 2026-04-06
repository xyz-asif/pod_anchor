import 'dart:developer';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/features/notifications/models/notification_model.dart';
import 'package:chatbee/features/notifications/repos/notification_repo.dart';
import 'package:chatbee/core/providers/auth_provider.dart';

part 'notification_controller.g.dart';

/// Manages the notification list and unread badge count.5
@Riverpod(keepAlive: true)
class NotificationController extends _$NotificationController {
  bool _hasMore = true;
  bool _isLoadingOlder = false;

  @override
  FutureOr<List<NotificationModel>> build() async {
    ref.watch(userSessionProvider);
    final result = await ref.read(notificationRepoProvider).getNotifications();
    _hasMore = result.$2;
    return result.$1;
  }

  /// Pull-to-refresh.
  Future<void> refresh() async {
    _hasMore = true;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final result = await ref
          .read(notificationRepoProvider)
          .getNotifications();
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

      final result = await ref
          .read(notificationRepoProvider)
          .getNotifications(before: current.last.id);

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
    ref.watch(userSessionProvider);
    // Defer fetch until after build() returns so state is initialized
    Future.microtask(_fetchCount);
    return 0;
  }

  Future<void> _fetchCount() async {
    final previous = state;
    try {
      final count = await ref.read(notificationRepoProvider).getUnreadCount();
      state = count;
    } catch (e) {
      // Preserve previous count on failure so the badge doesn't vanish.
      state = previous;
      log('Failed to fetch unread notification count: $e', name: 'NOTIF');
    }
  }

  void increment() => state = state + 1;
  void decrement() => state = (state - 1).clamp(0, 99999);
  void reset() => state = 0;

  /// Re-fetch from server (e.g. on app resume).
  Future<void> refresh() async => _fetchCount();
}
