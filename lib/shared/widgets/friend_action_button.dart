import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Consistent action button for friends screen
class FriendActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final bool isLoading;

  const FriendActionButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40.r,
      height: 40.r,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.r,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20.r),
          onTap: isLoading ? null : onPressed,
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 20.r,
                    height: 20.r,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  )
                : Icon(
                    icon,
                    color: color,
                    size: 20.r,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Consistent text button for friends screen
class FriendTextButton extends StatelessWidget {
  final String text;
  final Color color;
  final VoidCallback onPressed;
  final bool isLoading;

  const FriendTextButton({
    super.key,
    required this.text,
    required this.color,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8.r),
        onTap: isLoading ? null : onPressed,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1.r,
            ),
          ),
          child: isLoading
              ? SizedBox(
                  width: 16.r,
                  height: 16.r,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              : Text(
                  text,
                  style: TextStyle(
                    color: color,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}
