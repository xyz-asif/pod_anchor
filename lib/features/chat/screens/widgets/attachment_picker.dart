import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:chatbee/config/theme/app_theme.dart';

/// Bottom sheet with media attachment options.
///
/// Options: Camera, Gallery, Video, File.
/// Voice and GIF options will be added in later stages.
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
        padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(left: 4.w, bottom: 12.h),
              child: Text(
                'Share',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDarkColor,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AttachmentOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  color: Colors.deepPurple,
                  onTap: () {
                    Navigator.pop(context);
                    onPickImage(ImageSource.camera);
                  },
                ),
                _AttachmentOption(
                  icon: Icons.photo_rounded,
                  label: 'Gallery',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    onPickImage(ImageSource.gallery);
                  },
                ),
                _AttachmentOption(
                  icon: Icons.videocam_rounded,
                  label: 'Video',
                  color: Colors.pink,
                  onTap: () {
                    Navigator.pop(context);
                    onPickVideo(ImageSource.gallery);
                  },
                ),
                _AttachmentOption(
                  icon: Icons.gif_box_rounded,
                  label: 'GIF',
                  color: Colors.teal,
                  onTap: () {
                    Navigator.pop(context);
                    onPickGif();
                  },
                ),
                _AttachmentOption(
                  icon: Icons.insert_drive_file_rounded,
                  label: 'File',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                    onPickFile();
                  },
                ),
              ],
            ),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }
}

class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.color,
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
            width: 52.w,
            height: 52.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26.sp),
          ),
          SizedBox(height: 6.h),
          Text(
            label,
            style: TextStyle(fontSize: 12.sp, color: AppTheme.textMediumColor),
          ),
        ],
      ),
    );
  }
}
