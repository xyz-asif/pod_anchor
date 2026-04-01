import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:chatbee/features/notifications/controllers/notification_controller.dart';

class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    return IconButton(
      onPressed: () {
        HapticFeedback.lightImpact();
        context.push('/notifications');
      },
      icon: Badge(
        isLabelVisible: unreadCount > 0,
        label: Text(
          unreadCount > 99 ? '99+' : '$unreadCount',
          style: TextStyle(fontSize: 10.sp),
        ),
        child: Icon(Icons.notifications_outlined, size: 24.r),
      ),
    );
  }
}
