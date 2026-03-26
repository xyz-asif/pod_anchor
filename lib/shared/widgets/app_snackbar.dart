import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The type of snackbar to display.
enum SnackbarType { info, success, warning, error }

/// Custom snackbar matching the app's design language.
///
/// Usage:
///   AppSnackbar.show(context, message: 'Saved!', type: SnackbarType.success);
class AppSnackbar {
  AppSnackbar._();

  static void show(
    BuildContext context, {
    required String message,
    SnackbarType type = SnackbarType.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    // Haptic feedback for non-success snackbars
    if (type != SnackbarType.success) {
      switch (type) {
        case SnackbarType.error:
          HapticFeedback.heavyImpact();
          break;
        case SnackbarType.warning:
        case SnackbarType.info:
          HapticFeedback.lightImpact();
          break;
        default:
          break;
      }
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: _SnackbarContent(
            message: message,
            type: type,
            actionLabel: actionLabel,
            onAction: onAction,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          duration: duration,
          padding: EdgeInsets.zero,
          margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        ),
      );
  }
}

class _SnackbarContent extends StatelessWidget {
  final String message;
  final SnackbarType type;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SnackbarContent({
    required this.message,
    required this.type,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildIcon(),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            SizedBox(width: 8.w),
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                onAction!();
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  actionLabel!,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
            child: Icon(
              Icons.close,
              color: Colors.white.withValues(alpha: 0.6),
              size: 20.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    final (IconData icon, Color color) = switch (type) {
      SnackbarType.info => (Icons.info, Colors.white),
      SnackbarType.success => (Icons.check_circle, const Color(0xFF4CAF50)),
      SnackbarType.warning => (Icons.error, const Color(0xFFFFC107)),
      SnackbarType.error => (Icons.warning_rounded, const Color(0xFFEF5350)),
    };

    return Container(
      padding: EdgeInsets.all(2.w),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.15),
      ),
      child: Icon(icon, color: color, size: 22.sp),
    );
  }
}
