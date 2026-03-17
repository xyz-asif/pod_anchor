import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';
import 'package:chatbee/features/social/repos/social_repo.dart';
import 'package:chatbee/features/social/widgets/comment_bottom_sheet.dart';
import 'package:chatbee/shared/widgets/app_snackbar.dart';

class PoemCard extends ConsumerStatefulWidget {
  final PoemModel poem;
  final VoidCallback? onTap;

  const PoemCard({super.key, required this.poem, this.onTap});

  @override
  ConsumerState<PoemCard> createState() => _PoemCardState();
}

class _PoemCardState extends ConsumerState<PoemCard> {
  late bool _isLiked;
  late int _likeCount;
  late bool _isReposted;
  late int _repostCount;
  bool _isLikeLoading = false;
  bool _isRepostLoading = false;
  late QuillController _quillController;
  bool _isLong = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.poem.isLikedByMe;
    _likeCount = widget.poem.likesCount;
    _isReposted = widget.poem.isRepostedByMe;
    _repostCount = widget.poem.repostsCount;

    try {
      final doc = Document.fromJson(
        jsonDecode(widget.poem.contentJson) as List,
      );
      _quillController = QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );

      // Detect if long (more than 8 lines or very long text)
      final plainText = doc.toPlainText();
      _isLong = plainText.split('\n').length > 14 || plainText.length > 500;
    } catch (_) {
      _quillController = QuillController.basic();
    }
  }

  @override
  void dispose() {
    _quillController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PoemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.poem.id != widget.poem.id ||
        oldWidget.poem.contentJson != widget.poem.contentJson) {
      _isLiked = widget.poem.isLikedByMe;
      _likeCount = widget.poem.likesCount;
      _isReposted = widget.poem.isRepostedByMe;
      _repostCount = widget.poem.repostsCount;

      _quillController.dispose();
      try {
        final doc = Document.fromJson(
          jsonDecode(widget.poem.contentJson) as List,
        );
        _quillController = QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
          readOnly: true,
        );
        final plainText = doc.toPlainText();
        _isLong = plainText.split('\n').length > 14 || plainText.length > 500;
      } catch (_) {
        _quillController = QuillController.basic();
        _isLong = false;
      }
    }
  }

  Future<void> _toggleLike() async {
    setState(() {
      _isLikeLoading = true;
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });
    try {
      final result = await ref
          .read(socialRepoProvider)
          .togglePoemLike(widget.poem.id);
      if (mounted)
        setState(() {
          _isLiked = result.liked;
          _likeCount = result.likesCount;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _isLiked = !_isLiked;
          _likeCount += _isLiked ? 1 : -1;
        });
    } finally {
      if (mounted) setState(() => _isLikeLoading = false);
    }
  }

  Future<void> _toggleRepost() async {
    setState(() {
      _isRepostLoading = true;
    });
    try {
      final result = await ref
          .read(socialRepoProvider)
          .toggleRepost(widget.poem.id);
      if (mounted)
        setState(() {
          _isReposted = result.reposted;
          _repostCount = result.repostsCount;
        });
    } catch (e) {
      if (mounted)
        AppSnackbar.show(
          context,
          message: e.toString(),
          type: SnackbarType.error,
        );
    } finally {
      if (mounted) setState(() => _isRepostLoading = false);
    }
  }

  void _showComments(BuildContext context) {
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
      onTap:
          widget.onTap ??
          () => context.push('/poem/${widget.poem.id}', extra: widget.poem),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: AppTheme.borderColor.withValues(alpha: 0.6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Author row ──
            GestureDetector(
              onTap: () => context.push('/profile/${widget.poem.author.id}'),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18.r,
                    backgroundColor: AppTheme.borderColor,
                    backgroundImage: widget.poem.author.photoURL.isNotEmpty
                        ? CachedNetworkImageProvider(
                            widget.poem.author.photoURL,
                          )
                        : null,
                    child: widget.poem.author.photoURL.isEmpty
                        ? Text(
                            widget.poem.author.displayName.isNotEmpty
                                ? widget.poem.author.displayName[0]
                                      .toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.poem.author.displayName,
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textDarkColor,
                              ),
                            ),
                            if (widget.poem.author.isEditor) ...[
                              SizedBox(width: 4.w),
                              Icon(
                                Icons.verified_rounded,
                                size: 14.r,
                                color: AppTheme.primaryColor,
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '@${widget.poem.author.username}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppTheme.textLightColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.poem.createdAt != null)
                    Text(
                      timeago.format(
                        widget.poem.createdAt!,
                        locale: 'en_short',
                      ),
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppTheme.textLightColor,
                      ),
                    ),
                ],
              ),
            ),

            SizedBox(height: 12.h),

            // ── Title ──
            if (widget.poem.title.isNotEmpty &&
                widget.poem.title != 'Untitled Poem')
              Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: Text(
                  widget.poem.title,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: AppTheme.textDarkColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // ── Poem preview (Rich text) ──
            Stack(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: 280.h,
                  ), // Fits ~14 lines comfortably
                  child: IgnorePointer(
                    child: ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white,
                            _isLong
                                ? Colors.white.withValues(alpha: 0.0)
                                : Colors.white,
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
                              GoogleFonts.lato(
                                fontSize: 15.sp,
                                color: AppTheme.textDarkColor.withValues(
                                  alpha: 0.8,
                                ),
                                height: 1.2,
                                letterSpacing: 0.1,
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
                ),
                if (_isLong)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.chipTextColor,
                        borderRadius: BorderRadius.circular(12.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'Show more...',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            if (widget.poem.hashtags.isNotEmpty) ...[
              SizedBox(height: 12.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 4.h,
                children: widget.poem.hashtags
                    .take(5)
                    .map(
                      (tag) => Text(
                        '#$tag',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],

            SizedBox(height: 16.h),
            Divider(
              color: AppTheme.borderColor.withValues(alpha: 0.5),
              height: 1,
            ),
            SizedBox(height: 12.h),

            // ── Footer: like / comment / repost + badges ──
            Row(
              children: [
                // Like button
                GestureDetector(
                  onTap: _isLikeLoading ? null : _toggleLike,
                  child: Row(
                    children: [
                      Icon(
                        _isLiked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 18.r,
                        color: _isLiked ? Colors.red : AppTheme.textLightColor,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '$_likeCount',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: AppTheme.textLightColor,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(width: 16.w),

                // Comment button — opens comment sheet
                GestureDetector(
                  onTap: () => _showComments(context),
                  child: Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 18.r,
                        color: AppTheme.textLightColor,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '${widget.poem.commentsCount}',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: AppTheme.textLightColor,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(width: 16.w),

                // Repost button
                GestureDetector(
                  onTap: _isRepostLoading ? null : _toggleRepost,
                  child: Row(
                    children: [
                      Icon(
                        Icons.repeat_rounded,
                        size: 18.r,
                        color: _isReposted
                            ? AppTheme.primaryColor
                            : AppTheme.textLightColor,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '$_repostCount',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: _isReposted
                              ? AppTheme.primaryColor
                              : AppTheme.textLightColor,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                if (widget.poem.isOriginal)
                  Icon(
                    Icons.copyright_rounded,
                    size: 14.r,
                    color: AppTheme.primaryColor,
                  ),
                if (widget.poem.hasAudio) ...[
                  SizedBox(width: 6.w),
                  Icon(
                    Icons.mic_rounded,
                    size: 14.r,
                    color: AppTheme.textLightColor,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
