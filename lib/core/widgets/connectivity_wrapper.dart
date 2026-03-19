import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/core/providers/connectivity_provider.dart';
import 'package:chatbee/features/chat/controllers/chat_list_controller.dart';
import 'package:chatbee/features/auth/controllers/auth_controller.dart';
import 'package:chatbee/core/providers/auth_provider.dart';

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
