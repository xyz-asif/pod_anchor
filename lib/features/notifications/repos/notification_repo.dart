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
