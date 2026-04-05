import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';
import 'package:chatbee/features/poems/widgets/poem_card.dart';

class RepostCard extends StatelessWidget {
  final PoemModel repost; // isRepost == true, has originalPoem

  const RepostCard({super.key, required this.repost});

  @override
  Widget build(BuildContext context) {
    final original = repost.originalPoem;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Reposter header ──
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 4.h),
          child: GestureDetector(
            onTap: () => context.push('/profile/${repost.author.id}'),
            child: Row(
              children: [
                Icon(
                  Icons.repeat_rounded,
                  size: 14.r,
                  color: AppTheme.textLightColor,
                ),
                SizedBox(width: 6.w),
                CircleAvatar(
                  radius: 12.r,
                  backgroundColor: AppTheme.borderColor,
                  backgroundImage: repost.author.photoURL.isNotEmpty
                      ? CachedNetworkImageProvider(repost.author.photoURL)
                      : null,
                ),
                SizedBox(width: 6.w),
                Text(
                  '${repost.author.displayName} reposted',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: AppTheme.textLightColor,
                  ),
                ),
                const Spacer(),
                if (repost.createdAt != null)
                  Text(
                    timeago.format(repost.createdAt!, locale: 'en_short'),
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppTheme.textLightColor,
                    ),
                  ),
              ],
            ),
          ),
        ),

        // ── Original poem card (full, same as feed) ──
        // FIX: Add a ValueKey that includes social state so Flutter's
        // reconciliation correctly detects changes to the nested poem.
        // Without this, when the feed controller updates originalPoem's
        // isLikedByMe from false→true, the PoemCard's didUpdateWidget
        // may not fire because Flutter sees the "same" widget type at
        // the same position with no key change.
        if (original != null)
          PoemCard(
            key: ValueKey(
              'repost_${repost.id}_${original.id}_${original.isLikedByMe}_${original.likesCount}',
            ),
            poem: original,
          )
        else
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: AppTheme.borderColor.withValues(alpha: 0.6),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                'Original poem unavailable',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: AppTheme.textLightColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),

        Divider(height: 1, color: AppTheme.borderColor),
      ],
    );
  }
}
