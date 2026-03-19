import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/features/auth/controllers/auth_controller.dart';

/// Wraps the home screen. Handles:
/// - Loading state during session restore (shows spinner)
/// - Error state (shows retry + sign-out)
/// - Profile setup redirect (if profile not completed)
class SessionGate extends ConsumerWidget {
  final Widget child;
  const SessionGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return authState.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off_rounded, size: 64.r, color: AppTheme.textLightColor),
                SizedBox(height: 16.h),
                Text(
                  'Could not restore session',
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8.h),
                Text(
                  e.toString(),
                  style: TextStyle(fontSize: 13.sp, color: AppTheme.textMediumColor),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24.h),
                ElevatedButton(
                  onPressed: () => ref.read(authControllerProvider.notifier).restoreSession(),
                  child: const Text('Retry'),
                ),
                SizedBox(height: 8.h),
                TextButton(
                  onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
                  child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (user) {
        if (user == null) {
          // Still loading or signed out — show spinner briefly
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // Check profile setup
        if (!user.isProfileSetup) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/profile-setup');
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // Check username setup
        if (user.username == null || user.username!.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/username-setup');
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        return child;
      },
    );
  }
}
