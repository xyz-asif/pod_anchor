import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'package:timeago/timeago.dart' as timeago;
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';
import 'package:chatbee/features/feed/controllers/feed_controller.dart';
import 'package:chatbee/features/social/providers/social_events.dart';
import 'package:chatbee/features/social/repos/social_repo.dart';
import 'package:chatbee/features/social/widgets/comment_bottom_sheet.dart';

class PoemGridCard extends ConsumerStatefulWidget {
  final PoemModel poem;

  const PoemGridCard({super.key, required this.poem});

  @override
  ConsumerState<PoemGridCard> createState() => _PoemGridCardState();
}

class _PoemGridCardState extends ConsumerState<PoemGridCard> {
  late bool _isLiked;
  late int _likeCount;
  late bool _isReposted;
  late int _repostCount;
  late int _commentCount;
  late QuillController _quillController;
  bool _isLong = false;
  StreamSubscription? _socialSub;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.poem.isLikedByMe;
    _likeCount = widget.poem.likesCount;
    _isReposted = widget.poem.isRepostedByMe;
    _repostCount = widget.poem.repostsCount;
    _commentCount = widget.poem.commentsCount;

    _socialSub = ref.read(socialEventStreamProvider).stream.listen((event) {
      if (event.poemId == widget.poem.id && mounted) {
        setState(() {
          if (event.isLiked != null) _isLiked = event.isLiked!;
          if (event.likesCount != null) _likeCount = event.likesCount!;
          if (event.isReposted != null) _isReposted = event.isReposted!;
          if (event.repostsCount != null) _repostCount = event.repostsCount!;
          if (event.commentsCount != null) _commentCount = event.commentsCount!;
        });
      }
    });

    try {
      final doc = Document.fromJson(jsonDecode(widget.poem.contentJson) as List);
      _quillController = QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
      _isLong = doc.toPlainText().split('\n').length > 14 || doc.toPlainText().length > 400;
    } catch (_) {
      _quillController = QuillController.basic();
    }
  }

  @override
  void dispose() {
    _socialSub?.cancel();
    _quillController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PoemGridCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.poem.isLikedByMe != widget.poem.isLikedByMe ||
        oldWidget.poem.likesCount != widget.poem.likesCount) {
      _isLiked = widget.poem.isLikedByMe;
      _likeCount = widget.poem.likesCount;
    }
    if (oldWidget.poem.isRepostedByMe != widget.poem.isRepostedByMe ||
        oldWidget.poem.repostsCount != widget.poem.repostsCount) {
      _isReposted = widget.poem.isRepostedByMe;
      _repostCount = widget.poem.repostsCount;
    }
    if (oldWidget.poem.commentsCount != widget.poem.commentsCount) {
      _commentCount = widget.poem.commentsCount;
    }

    if (oldWidget.poem.id != widget.poem.id || oldWidget.poem.contentJson != widget.poem.contentJson) {
      _isLiked = widget.poem.isLikedByMe;
      _likeCount = widget.poem.likesCount;
      _isReposted = widget.poem.isRepostedByMe;
      _repostCount = widget.poem.repostsCount;
      
      _quillController.dispose();
      try {
        final doc = Document.fromJson(jsonDecode(widget.poem.contentJson) as List);
        _quillController = QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
          readOnly: true,
        );
        _isLong = doc.toPlainText().split('\n').length > 14 || doc.toPlainText().length > 400;
      } catch (_) {
        _quillController = QuillController.basic();
        _isLong = false;
      }
    }
  }

  Future<void> _toggleLike() async {
    HapticFeedback.lightImpact();
    final wasLiked = _isLiked;
    final originalCount = _likeCount;

    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });
    try {
      final result = await ref.read(socialRepoProvider).togglePoemLike(widget.poem.id);
      if (mounted) {
        setState(() {
          _isLiked = result.liked;
          _likeCount = result.likesCount;
        });
      }
      ref.read(socialEventStreamProvider).emit(SocialEvent(
          poemId: widget.poem.id, isLiked: result.liked, likesCount: result.likesCount));
      try { ref.read(homeFeedControllerProvider.notifier).updatePoemSocialState(
          widget.poem.id, isLiked: result.liked, likesCount: result.likesCount); } catch (_) {}
      try { ref.read(exploreFeedControllerProvider.notifier).updatePoemSocialState(
          widget.poem.id, isLiked: result.liked, likesCount: result.likesCount); } catch (_) {}
      try { ref.read(audioFeedControllerProvider.notifier).updatePoemSocialState(
          widget.poem.id, isLiked: result.liked, likesCount: result.likesCount); } catch (_) {}
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLiked = wasLiked;
          _likeCount = originalCount;
        });
      }
    }
  }

  Future<void> _toggleRepost() async {
    HapticFeedback.lightImpact();
    final wasReposted = _isReposted;
    final originalCount = _repostCount;

    setState(() {
      _isReposted = !_isReposted;
      _repostCount += _isReposted ? 1 : -1;
    });
    try {
      final result = await ref.read(socialRepoProvider).toggleRepost(widget.poem.id);
      if (mounted) {
        setState(() {
          _isReposted = result.reposted;
          _repostCount = result.repostsCount;
        });
      }
      ref.read(socialEventStreamProvider).emit(SocialEvent(
          poemId: widget.poem.id, isReposted: result.reposted, repostsCount: result.repostsCount));
      try { ref.read(homeFeedControllerProvider.notifier).updatePoemSocialState(
          widget.poem.id, isReposted: result.reposted, repostsCount: result.repostsCount); } catch (_) {}
      try { ref.read(exploreFeedControllerProvider.notifier).updatePoemSocialState(
          widget.poem.id, isReposted: result.reposted, repostsCount: result.repostsCount); } catch (_) {}
      try { ref.read(audioFeedControllerProvider.notifier).updatePoemSocialState(
          widget.poem.id, isReposted: result.reposted, repostsCount: result.repostsCount); } catch (_) {}
    } catch (_) {
      if (mounted) {
        setState(() {
          _isReposted = wasReposted;
          _repostCount = originalCount;
        });
      }
    }
  }

  void _showComments(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentBottomSheet(poemId: widget.poem.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/poem/${widget.poem.id}', extra: widget.poem);
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: AppTheme.borderColor.withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top section: Content
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(12.w, 14.h, 12.w, 4.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    // Date at the top
                    if (widget.poem.createdAt != null)
                      Text(
                        timeago.format(widget.poem.createdAt!, locale: 'en_short'),
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: AppTheme.textLightColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    SizedBox(height: 6.h),
                    // Title
                    if (widget.poem.title.isNotEmpty && widget.poem.title != 'Untitled Poem')
                      Text(
                        widget.poem.title,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textDarkColor,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    SizedBox(height: 4.h),
                    // Body
                    Expanded(
                      child: Stack(
                        children: [
                          IgnorePointer(
                            child: ShaderMask(
                              shaderCallback: (Rect bounds) {
                                return LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white,
                                    _isLong ? Colors.white.withValues(alpha: 0.0) : Colors.white
                                  ],
                                  stops: const [0.7, 1.0],
                                ).createShader(bounds);
                              },
                              blendMode: BlendMode.dstIn,
                              child: QuillEditor.basic(
                                controller: _quillController,
                                config: QuillEditorConfig(
                                  padding: EdgeInsets.zero,
                                  scrollPhysics: const NeverScrollableScrollPhysics(),
                                  customStyles: DefaultStyles(
                                    paragraph: DefaultTextBlockStyle(
                                      TextStyle(
                                        fontFamily: 'JosefinSans',
                                        fontSize: 12.sp,
                                        color: AppTheme.textDarkColor.withValues(alpha: 0.7),
                                        height: 1.2,
                                      ),
                                      const HorizontalSpacing(0, 0),
                                      const VerticalSpacing(0, 0),
                                      const VerticalSpacing(0, 0),
                                      null,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_isLong)
                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceColor.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(8.r),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'more...',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (widget.poem.hasAudio) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: AppTheme.featureBackgroundColor,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: AppTheme.borderColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24.r,
                        height: 24.r,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 16.r,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: Text(
                          'Listen',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDarkColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.headphones_rounded,
                        size: 12.r,
                        color: AppTheme.textLightColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            // Bottom section: Stats
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: AppTheme.featureBackgroundColor.withValues(alpha: 0.3),
              border: Border(
                top: BorderSide(
                  color: AppTheme.borderColor.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatItem(
                  icon: _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  count: _likeCount,
                  color: _isLiked ? Colors.redAccent : AppTheme.textLightColor,
                  onTap: _toggleLike,
                ),
                _StatItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  count: _commentCount,
                  color: AppTheme.textLightColor,
                  // Open comment bottom sheet
                  onTap: () => _showComments(context),
                ),
                _StatItem(
                  icon: Icons.repeat_rounded,
                  count: _repostCount,
                  color: _isReposted ? AppTheme.primaryColor : AppTheme.textLightColor,
                  onTap: _toggleRepost,
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;
  final VoidCallback? onTap;

  const _StatItem({
    required this.icon,
    required this.count,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.r, color: color),
          SizedBox(width: 3.w),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 11.sp,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
