import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:chatbee/config/theme/app_theme.dart';

/// Bottom sheet with media attachment options - Dark Theme Design.
///
/// Options: Camera, Gallery, Video, GIF, File.
class AttachmentPicker extends StatelessWidget {
  final void Function(ImageSource source) onPickImage;
  final void Function(ImageSource source) onPickVideo;
  final VoidCallback onPickFile;
  final VoidCallback onPickGif;

  const AttachmentPicker({
    super.key,
    required this.onPickImage,
    required this.onPickVideo,
    required this.onPickFile,
    required this.onPickGif,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 16.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and close handle
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 20.h),
                decoration: BoxDecoration(
                  color: AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: 8.w, bottom: 20.h),
              child: Text(
                'Share',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDarkColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AttachmentOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  backgroundColor: const Color(0xFFE8D5F2), // Light purple
                  iconColor: const Color(0xFF9C27B0), // Deep purple
                  onTap: () {
                    Navigator.pop(context);
                    onPickImage(ImageSource.camera);
                  },
                ),
                _AttachmentOption(
                  icon: Icons.photo_rounded,
                  label: 'Gallery',
                  backgroundColor: const Color(0xFFD6E9F8), // Light blue
                  iconColor: const Color(0xFF2196F3), // Blue
                  onTap: () {
                    Navigator.pop(context);
                    onPickImage(ImageSource.gallery);
                  },
                ),
                _AttachmentOption(
                  icon: Icons.videocam_rounded,
                  label: 'Video',
                  backgroundColor: const Color(0xFFF8D7E3), // Light pink
                  iconColor: const Color(0xFFE91E63), // Pink
                  onTap: () {
                    Navigator.pop(context);
                    onPickVideo(ImageSource.gallery);
                  },
                ),
                _AttachmentOption(
                  icon: Icons.gif_rounded,
                  label: 'GIF',
                  backgroundColor: const Color(0xFFD5F2EA), // Light teal
                  iconColor: const Color(0xFF009688), // Teal
                  onTap: () {
                    Navigator.pop(context);
                    onPickGif();
                  },
                ),
                _AttachmentOption(
                  icon: Icons.insert_drive_file_rounded,
                  label: 'File',
                  backgroundColor: const Color(0xFFFFF3D6), // Light orange
                  iconColor: const Color(0xFFFF9800), // Orange
                  onTap: () {
                    Navigator.pop(context);
                    onPickFile();
                  },
                ),
              ],
            ),
            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }
}

class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60.w,
            height: 60.w,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 28.sp),
          ),
          SizedBox(height: 10.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 13.sp,
              color: AppTheme.textMediumColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
