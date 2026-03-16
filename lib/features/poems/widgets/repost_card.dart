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
                Icon(Icons.repeat_rounded, size: 14.r, color: AppTheme.textLightColor),
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
                  style: TextStyle(fontSize: 13.sp, color: AppTheme.textLightColor),
                ),
                const Spacer(),
                if (repost.createdAt != null)
                  Text(
                    timeago.format(repost.createdAt!, locale: 'en_short'),
                    style: TextStyle(fontSize: 11.sp, color: AppTheme.textLightColor),
                  ),
              ],
            ),
          ),
        ),

        // ── Original poem card (full, same as feed) ──
        if (original != null)
          PoemCard(poem: original)
        else
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Text(
              'Original poem unavailable',
              style: TextStyle(fontSize: 13.sp, color: AppTheme.textLightColor, fontStyle: FontStyle.italic),
            ),
          ),

        Divider(height: 1, color: AppTheme.borderColor),
      ],
    );
  }
}
