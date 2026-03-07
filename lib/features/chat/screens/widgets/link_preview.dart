import 'package:any_link_preview/any_link_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chatbee/config/theme/app_theme.dart';

/// Widget that displays a link preview for chat messages.
/// Fetches metadata from the URL and shows title, description, and image.
class LinkPreviewWidget extends StatelessWidget {
  final String url;
  final bool isMe;

  const LinkPreviewWidget({
    super.key,
    required this.url,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return AnyLinkPreview(
      link: url,
      displayDirection: UIDirection.uiDirectionVertical,
      showMultimedia: true,
      bodyMaxLines: 2,
      bodyTextOverflow: TextOverflow.ellipsis,
      titleStyle: TextStyle(
        fontSize: 13.sp,
        fontWeight: FontWeight.w600,
        color: isMe ? Colors.white : AppTheme.textDarkColor,
      ),
      bodyStyle: TextStyle(
        fontSize: 11.sp,
        color: isMe ? Colors.white70 : AppTheme.textMediumColor,
      ),
      errorWidget: Container(
        padding: EdgeInsets.all(8.r),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withValues(alpha: 0.1)
              : AppTheme.borderColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          children: [
            Icon(
              Icons.link,
              size: 16.r,
              color: isMe ? Colors.white70 : AppTheme.textMediumColor,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: isMe ? Colors.white : AppTheme.textDarkColor,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      placeholderWidget: Container(
        width: double.infinity,
        height: 80.h,
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withValues(alpha: 0.1)
              : AppTheme.borderColor.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Center(
          child: SizedBox(
            width: 20.r,
            height: 20.r,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                isMe ? Colors.white70 : AppTheme.primaryColor,
              ),
            ),
          ),
        ),
      ),
      borderRadius: 8.r,
      removeElevation: true,
      backgroundColor: isMe
          ? Colors.white.withValues(alpha: 0.1)
          : AppTheme.borderColor.withValues(alpha: 0.2),
    );
  }
}

/// Helper to extract URLs from text
class LinkExtractor {
  /// Regex pattern to match URLs
  static final RegExp _urlRegex = RegExp(
    r'https?://(?:[a-zA-Z0-9\-\.]+|\[[0-9a-fA-F:]\])+(/[^\s]*)?',
    caseSensitive: false,
  );

  /// Extracts the first URL from text, or null if none found
  static String? extractUrl(String text) {
    final match = _urlRegex.firstMatch(text);
    return match?.group(0);
  }

  /// Checks if text contains a URL
  static bool hasUrl(String text) {
    return _urlRegex.hasMatch(text);
  }
}
