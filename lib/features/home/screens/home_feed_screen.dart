import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:chatbee/config/theme/app_theme.dart';

/// Home feed screen — first tab in the bottom navigation.
/// Shows the poems feed (placeholder for now) and a notification bell in the app bar.
class HomeFeedScreen extends ConsumerWidget {
  const HomeFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ChatBee',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDarkColor,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              Icons.notifications_outlined,
              size: 26.r,
              color: AppTheme.textDarkColor,
            ),
            onPressed: () => context.push('/notifications'),
          ),
          SizedBox(width: 4.w),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories_rounded,
              size: 72.r,
              color: AppTheme.textLightColor,
            ),
            SizedBox(height: 16.h),
            Text(
              'Your feed will appear here',
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w500,
                color: AppTheme.textMediumColor,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'Discover and share poetry',
              style: TextStyle(
                fontSize: 14.sp,
                color: AppTheme.textLightColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
