import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:open_filex/open_filex.dart';

import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';
import 'package:chatbee/features/poems/services/poem_share_service.dart';
import 'package:chatbee/shared/widgets/app_snackbar.dart';

class PoemShareSheet extends StatefulWidget {
  final PoemModel poem;

  const PoemShareSheet({super.key, required this.poem});

  @override
  State<PoemShareSheet> createState() => _PoemShareSheetState();
}

class _PoemShareSheetState extends State<PoemShareSheet> {
  bool _isGenerating = false;

  Future<void> _shareAsText() async {
    HapticFeedback.lightImpact();
    Navigator.pop(context);
    await PoemShareService.shareAsText(widget.poem);
  }

  Future<void> _downloadImage() async {
    if (_isGenerating) return;
    HapticFeedback.lightImpact();
    setState(() => _isGenerating = true);

    try {
      final savedPath =
          await PoemShareService.generateAndSaveImage(context, widget.poem);

      if (!mounted) return;
      setState(() => _isGenerating = false);
      Navigator.pop(context);

      if (savedPath != null) {
        // Strip file:// prefix if present — open_filex needs a plain path
        String cleanPath = savedPath;
        if (cleanPath.startsWith('file://')) {
          cleanPath = Uri.parse(cleanPath).toFilePath();
        }

        AppSnackbar.show(
          context,
          message: 'Image downloaded successfully',
          type: SnackbarType.success,
          duration: const Duration(seconds: 5),
          actionLabel: 'View',
          onAction: () {
            OpenFilex.open(cleanPath);
          },
        );
      } else {
        AppSnackbar.show(
          context,
          message: 'Failed to save image',
          type: SnackbarType.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      Navigator.pop(context);
      AppSnackbar.show(
        context,
        message: 'Failed to generate image',
        type: SnackbarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 32.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: AppTheme.borderColor,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 20.h),

          Text(
            'Share Poem',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDarkColor,
            ),
          ),
          SizedBox(height: 20.h),

          _buildOption(
            icon: Icons.text_fields_rounded,
            label: 'Share as Text',
            subtitle: 'Send poem text to other apps',
            onTap: _shareAsText,
          ),
          SizedBox(height: 12.h),
          _buildOption(
            icon: Icons.image_outlined,
            label: 'Download Image',
            subtitle: 'Save styled poem image to gallery',
            onTap: _downloadImage,
            isLoading: _isGenerating,
          ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return Material(
      color: AppTheme.featureBackgroundColor,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          child: Row(
            children: [
              Container(
                width: 40.r,
                height: 40.r,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: isLoading
                    ? Padding(
                        padding: EdgeInsets.all(10.r),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryColor,
                        ),
                      )
                    : Icon(icon, size: 20.r, color: AppTheme.primaryColor),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDarkColor,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppTheme.textLightColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20.r,
                color: AppTheme.textLightColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
