import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:chatbee/config/theme/app_theme.dart';

/// Minimal publish bottom sheet - just Save Draft + Publish buttons
/// Replaces the full publish bottom sheet per v1 spec
Future<String?> showMinimalPublishSheet({
  required BuildContext context,
  bool isEditing = false,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => MinimalPublishSheet(
      isEditing: isEditing,
    ),
  );
}

class MinimalPublishSheet extends StatelessWidget {
  final bool isEditing;

  const MinimalPublishSheet({
    super.key,
    this.isEditing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: EdgeInsets.only(top: 12.h, bottom: 16.h),
              child: Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppTheme.borderColor,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
            ),

            // Title
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Text(
                isEditing ? 'Update poem' : 'Publish poem',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDarkColor,
                ),
              ),
            ),

            SizedBox(height: 24.h),

            // Action buttons
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Row(
                children: [
                  // Draft button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop('private'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        side: BorderSide(color: AppTheme.borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text(
                        'Save Draft',
                        style: TextStyle(
                          fontSize: 15.sp,
                          color: AppTheme.textMediumColor,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  // Publish button
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop('public'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text(
                        isEditing ? 'Update' : 'Publish',
                        style: TextStyle(
                          fontSize: 15.sp,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: MediaQuery.of(context).padding.bottom + 24.h),
          ],
        ),
      ),
    );
  }
}
