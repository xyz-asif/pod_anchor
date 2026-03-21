import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';
import 'package:chatbee/features/feed/controllers/feed_controller.dart';
import 'package:chatbee/features/social/providers/social_events.dart';
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
  late int _commentCount;
  bool _isLikeLoading = false;
  bool _isRepostLoading = false;
  late QuillController _quillController;
  bool _isLong = false;
  StreamSubscription? _socialSub;

  AudioPlayer? _audioPlayer;
  bool _isPlayingAudio = false;
  bool _isLoadingAudio = false;
  StreamSubscription? _audioStateSub;

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
    _socialSub?.cancel();
    _audioStateSub?.cancel();
    _audioPlayer?.dispose();
    _quillController.dispose();
    super.dispose();
  }

  @override
  void deactivate() {
    if (_isPlayingAudio) {
      _audioPlayer?.stop();
      _isPlayingAudio = false;
    }
    super.deactivate();
  }

  @override
  void didUpdateWidget(PoemCard oldWidget) {
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

    if (oldWidget.poem.id != widget.poem.id) {
      _audioPlayer?.stop();
      _isPlayingAudio = false;
      _isLoadingAudio = false;
    }

    if (oldWidget.poem.id != widget.poem.id ||
        oldWidget.poem.contentJson != widget.poem.contentJson) {

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

  Future<void> _toggleAudio() async {
    if (_isLoadingAudio) return;

    if (_isPlayingAudio) {
      await _audioPlayer?.stop();
      setState(() => _isPlayingAudio = false);
      return;
    }

    _audioPlayer ??= AudioPlayer();
    setState(() => _isLoadingAudio = true);

    try {
      await _audioPlayer!.setAudioSource(AudioSource.uri(Uri.parse(widget.poem.audioUrl)));
      _audioPlayer!.play();
      if (mounted) setState(() { _isPlayingAudio = true; _isLoadingAudio = false; });

      _audioStateSub?.cancel();
      _audioStateSub = _audioPlayer!.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed && mounted) {
          setState(() => _isPlayingAudio = false);
        }
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingAudio = false);
    }
  }

  Future<void> _toggleLike() async {
    HapticFeedback.lightImpact();
    final wasLiked = _isLiked;
    final originalCount = _likeCount;

    setState(() {
      _isLikeLoading = true;
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });
    try {
      final result = await ref
          .read(socialRepoProvider)
          .togglePoemLike(widget.poem.id);
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
    } finally {
      if (mounted) setState(() => _isLikeLoading = false);
    }
  }

  Future<void> _toggleRepost() async {
    HapticFeedback.lightImpact();
    final wasReposted = _isReposted;
    final originalCount = _repostCount;
    
    setState(() {
      _isRepostLoading = true;
      _isReposted = !_isReposted;
      _repostCount += _isReposted ? 1 : -1;
    });
    try {
      final result = await ref
          .read(socialRepoProvider)
          .toggleRepost(widget.poem.id);
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _isReposted = wasReposted;
          _repostCount = originalCount;
        });
        AppSnackbar.show(
          context,
          message: e.toString(),
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isRepostLoading = false);
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
      onTap: widget.onTap ?? () {
        _audioPlayer?.stop();
        if (_isPlayingAudio) setState(() => _isPlayingAudio = false);
        context.push('/poem/${widget.poem.id}', extra: widget.poem);
      },
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
                ClipRect(
                  child: ConstrainedBox(
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
                            scrollable: false,
                            expands: false,
                            showCursor: false,
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

            if (widget.poem.hasAudio) ...[
              SizedBox(height: 12.h),
              GestureDetector(
                onTap: _toggleAudio,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: _isPlayingAudio
                        ? AppTheme.primaryColor.withValues(alpha: 0.08)
                        : AppTheme.featureBackgroundColor,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: _isPlayingAudio
                          ? AppTheme.primaryColor.withValues(alpha: 0.3)
                          : AppTheme.borderColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36.r, height: 36.r,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: _isLoadingAudio
                            ? Padding(
                                padding: EdgeInsets.all(8.r),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppTheme.primaryColor),
                              )
                            : Icon(
                                _isPlayingAudio ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                size: 22.r, color: AppTheme.primaryColor,
                              ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isPlayingAudio ? 'Playing...' : 'Listen to this poem',
                              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500,
                                  color: AppTheme.textDarkColor),
                            ),
                            if (widget.poem.audioDuration > 0)
                              Text(
                                '${widget.poem.audioDuration ~/ 60}:${(widget.poem.audioDuration % 60).toString().padLeft(2, '0')}',
                                style: TextStyle(fontSize: 11.sp, color: AppTheme.textLightColor),
                              ),
                          ],
                        ),
                      ),
                      Icon(Icons.headphones_rounded, size: 18.r, color: AppTheme.textLightColor),
                    ],
                  ),
                ),
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
                        '$_commentCount',
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}
