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
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: false,
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
