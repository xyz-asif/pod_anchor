import 'dart:async';
import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:just_audio/just_audio.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';
import 'package:chatbee/features/poems/repos/poem_repo.dart';
import 'package:chatbee/features/poems/controllers/poem_controller.dart';
import 'package:chatbee/features/feed/controllers/feed_controller.dart';
import 'package:chatbee/features/social/controllers/social_action_controller.dart';
import 'package:chatbee/features/social/widgets/comment_bottom_sheet.dart';
import 'package:chatbee/features/auth/controllers/auth_controller.dart';
import 'package:chatbee/features/poems/widgets/poem_share_sheet.dart';
import 'package:chatbee/shared/widgets/app_snackbar.dart';

class PoemCard extends ConsumerStatefulWidget {
  final PoemModel poem;
  final VoidCallback? onTap;
  final VoidCallback? onDeleted;
  final void Function(PoemModel)? onUpdated;

  const PoemCard({
    super.key,
    required this.poem,
    this.onTap,
    this.onDeleted,
    this.onUpdated,
  });

  @override
  ConsumerState<PoemCard> createState() => _PoemCardState();
}

class _PoemCardState extends ConsumerState<PoemCard> {
  // Optimistic UI state
  late bool _isLiked;
  late int _likeCount;
  late bool _isReposted;
  late int _repostCount;
  // FIX #8: Track comment count locally for optimistic updates
  late int _commentCount;
  bool _isLikeLoading = false;
  bool _isRepostLoading = false;
  late QuillController _quillController;

  // FIX #3: Manage TapGestureRecognizers properly to prevent memory leaks
  List<TapGestureRecognizer> _mentionRecognizers = [];

  // Audio seekbar state
  AudioPlayer? _audioPlayer;
  bool _isPlayingAudio = false;
  bool _isLoadingAudio = false;
  Duration _audioPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;
  StreamSubscription? _audioStateSub;
  StreamSubscription? _audioPositionSub;
  StreamSubscription? _audioDurationSub;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.poem.isLikedByMe;
    _likeCount = widget.poem.likesCount;
    _isReposted = widget.poem.isRepostedByMe;
    _repostCount = widget.poem.repostsCount;
    _commentCount = widget.poem.commentsCount;

    _initQuillController();
    _buildMentionRecognizers();
  }

  void _initQuillController() {
    try {
      final doc = Document.fromJson(
        jsonDecode(widget.poem.contentJson) as List,
      );

      // Trim empty trailing newlines
      String text = doc.toPlainText();
      int trimCount = 0;
      for (int i = text.length - 1; i >= 0; i--) {
        if (text[i] == '\n') {
          trimCount++;
        } else {
          break;
        }
      }
      if (trimCount > 1) {
        doc.delete(doc.length - trimCount, trimCount - 1);
      }

      // Apply backwards-compatibility global alignment
      // FIX #16: Guard against empty document
      if (doc.length > 0) {
        final attr = widget.poem.textAlign == 'center'
            ? Attribute.centerAlignment
            : (widget.poem.textAlign == 'right'
                  ? Attribute.rightAlignment
                  : Attribute.leftAlignment);
        doc.format(0, doc.length, attr);
      }

      _quillController = QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
    } catch (_) {
      _quillController = QuillController.basic();
    }
  }

  /// FIX #3: Build TapGestureRecognizers once, dispose them properly.
  void _buildMentionRecognizers() {
    // Dispose old recognizers first
    for (final r in _mentionRecognizers) {
      r.dispose();
    }
    _mentionRecognizers = [];

    final desc = widget.poem.description;
    if (desc.isEmpty) return;

    final mentionRegex = RegExp(r'@([a-zA-Z0-9_\-]+)');
    for (final match in mentionRegex.allMatches(desc)) {
      final username = match.group(1)!;
      final recognizer = TapGestureRecognizer()
        ..onTap = () {
          final mentioned = widget.poem.mentions
              .where((m) => m.username == username)
              .firstOrNull;
          if (mentioned != null) {
            context.push('/profile/${mentioned.id}');
          }
        };
      _mentionRecognizers.add(recognizer);
    }
  }

  @override
  void dispose() {
    // FIX #3: Dispose all TapGestureRecognizers
    for (final r in _mentionRecognizers) {
      r.dispose();
    }
    // FIX #14: Cancel all audio subscriptions and stop player
    _audioStateSub?.cancel();
    _audioPositionSub?.cancel();
    _audioDurationSub?.cancel();
    _audioPlayer?.stop();
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

    // Sync optimistic state with upstream (feed controller) changes
    if (!_isLikeLoading) {
      if (oldWidget.poem.isLikedByMe != widget.poem.isLikedByMe ||
          oldWidget.poem.likesCount != widget.poem.likesCount) {
        _isLiked = widget.poem.isLikedByMe;
        _likeCount = widget.poem.likesCount;
      }
    }
    if (!_isRepostLoading) {
      if (oldWidget.poem.isRepostedByMe != widget.poem.isRepostedByMe ||
          oldWidget.poem.repostsCount != widget.poem.repostsCount) {
        _isReposted = widget.poem.isRepostedByMe;
        _repostCount = widget.poem.repostsCount;
      }
    }
    // FIX #8: Sync comment count from upstream
    if (oldWidget.poem.commentsCount != widget.poem.commentsCount) {
      _commentCount = widget.poem.commentsCount;
    }

    // FIX #14: Full audio cleanup when poem ID changes
    if (oldWidget.poem.id != widget.poem.id) {
      _audioStateSub?.cancel();
      _audioPositionSub?.cancel();
      _audioDurationSub?.cancel();
      _audioPlayer?.stop();
      _audioPlayer?.dispose();
      _audioPlayer = null;
      _isPlayingAudio = false;
      _isLoadingAudio = false;
      _audioPosition = Duration.zero;
      _audioDuration = Duration.zero;
    }

    if (oldWidget.poem.id != widget.poem.id ||
        oldWidget.poem.contentJson != widget.poem.contentJson) {
      _quillController.dispose();
      _initQuillController();
    }

    // FIX #3: Rebuild mention recognizers when poem data changes
    if (oldWidget.poem.id != widget.poem.id ||
        oldWidget.poem.description != widget.poem.description) {
      _buildMentionRecognizers();
    }
  }

  TextAlign get _textAlignEnum {
    switch (widget.poem.textAlign) {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      default:
        return TextAlign.left;
    }
  }

  // ── Audio seekbar ──

  Future<void> _toggleAudio() async {
    if (_isLoadingAudio) return;

    if (_isPlayingAudio) {
      await _audioPlayer?.pause();
      setState(() => _isPlayingAudio = false);
      return;
    }

    // If already loaded (paused), just resume
    if (_audioPlayer != null && _audioDuration > Duration.zero) {
      _audioPlayer!.play();
      setState(() => _isPlayingAudio = true);
      return;
    }

    _audioPlayer ??= AudioPlayer();
    setState(() => _isLoadingAudio = true);

    try {
      await _audioPlayer!.setAudioSource(
        AudioSource.uri(Uri.parse(widget.poem.audioUrl)),
      );
      _audioPlayer!.play();
      if (mounted) {
        setState(() {
          _isPlayingAudio = true;
          _isLoadingAudio = false;
        });
      }

      _audioStateSub?.cancel();
      _audioStateSub = _audioPlayer!.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed && mounted) {
          setState(() {
            _isPlayingAudio = false;
            _audioPosition = Duration.zero;
          });
        }
      });

      _audioPositionSub?.cancel();
      _audioPositionSub = _audioPlayer!.positionStream.listen((pos) {
        if (mounted) setState(() => _audioPosition = pos);
      });

      _audioDurationSub?.cancel();
      _audioDurationSub = _audioPlayer!.durationStream.listen((dur) {
        if (dur != null && mounted) setState(() => _audioDuration = dur);
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingAudio = false);
    }
  }

  // ── Social actions ──

  Future<void> _toggleLike() async {
    HapticFeedback.lightImpact();
    final wasLiked = _isLiked;
    final originalCount = _likeCount;

    // Optimistic UI
    setState(() {
      _isLikeLoading = true;
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });
    try {
      final result = await ref
          .read(socialActionControllerProvider.notifier)
          .toggleLike(widget.poem.id);
      if (mounted) {
        setState(() {
          _isLiked = result.liked;
          _likeCount = result.likesCount;
        });
      }
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

    // Optimistic UI
    setState(() {
      _isRepostLoading = true;
      _isReposted = !_isReposted;
      _repostCount += _isReposted ? 1 : -1;
    });
    try {
      final result = await ref
          .read(socialActionControllerProvider.notifier)
          .toggleRepost(widget.poem.id);
      if (mounted) {
        setState(() {
          _isReposted = result.reposted;
          _repostCount = result.repostsCount;
        });
      }
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

  // FIX #8: Comments sheet now returns whether a comment was posted,
  // and we optimistically increment the count.
  void _showComments(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentBottomSheet(
        poemId: widget.poem.id,
        poemAuthorId: widget.poem.author.id,
      ),
    ).then((commentPosted) {
      if (commentPosted == true && mounted) {
        setState(() => _commentCount++);
      }
    });
  }

  // ── 3-dot menu ──

  Future<void> _deletePoem() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete poem?',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'This cannot be undone.',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.heavyImpact();
              Navigator.pop(ctx, true);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(socialActionControllerProvider.notifier)
          .deletePoem(widget.poem.id);
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Poem deleted',
          type: SnackbarType.success,
        );
        widget.onDeleted?.call();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Failed to delete poem',
          type: SnackbarType.error,
        );
      }
    }
  }

  // ── Description with tappable @mentions ──
  // FIX #3: Uses pre-built recognizers instead of creating new ones each build

  Widget _buildDescription() {
    final desc = widget.poem.description;
    if (desc.isEmpty) return const SizedBox.shrink();

    final mentionRegex = RegExp(r'@([a-zA-Z0-9_\-]+)');
    final spans = <InlineSpan>[];
    int lastEnd = 0;
    int recognizerIndex = 0;

    for (final match in mentionRegex.allMatches(desc)) {
      // Add text before this mention
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: desc.substring(lastEnd, match.start),
            style: TextStyle(fontSize: 12.sp, color: AppTheme.textMediumColor),
          ),
        );
      }
      // Add the mention itself with pre-built recognizer
      final username = match.group(1)!;
      spans.add(
        TextSpan(
          text: '@$username',
          style: TextStyle(
            fontSize: 12.sp,
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.w600,
          ),
          recognizer: recognizerIndex < _mentionRecognizers.length
              ? _mentionRecognizers[recognizerIndex]
              : null,
        ),
      );
      recognizerIndex++;
      lastEnd = match.end;
    }
    // Remaining text
    if (lastEnd < desc.length) {
      spans.add(
        TextSpan(
          text: desc.substring(lastEnd),
          style: TextStyle(fontSize: 12.sp, color: AppTheme.textMediumColor),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 8.h),
        if (widget.poem.hashtags.isNotEmpty) ...[
          Wrap(
            spacing: 8.w,
            runSpacing: 4.h,
            children: widget.poem.hashtags
                .take(5)
                .map(
                  (tag) => Text(
                    '#$tag',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
        RichText(text: TextSpan(children: spans)),
        SizedBox(height: 8.h),
        Divider(color: AppTheme.borderColor.withValues(alpha: 0.5), height: 1),
      ],
    );
  }

  // ── Audio seekbar ──

  Widget _buildAudioSeekbar() {
    if (!widget.poem.hasAudio) return const SizedBox.shrink();

    final totalDuration = _audioDuration > Duration.zero
        ? _audioDuration
        : Duration(seconds: widget.poem.audioDuration);

    String formatDuration(Duration d) {
      final m = d.inMinutes;
      final s = d.inSeconds % 60;
      return '$m:${s.toString().padLeft(2, '0')}';
    }

    return Padding(
      padding: EdgeInsets.only(top: 12.h),
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
            // Play/Pause button
            GestureDetector(
              onTap: _toggleAudio,
              child: Container(
                width: 36.r,
                height: 36.r,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: _isLoadingAudio
                    ? Padding(
                        padding: EdgeInsets.all(8.r),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryColor,
                        ),
                      )
                    : Icon(
                        _isPlayingAudio
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 22.r,
                        color: AppTheme.primaryColor,
                      ),
              ),
            ),
            SizedBox(width: 10.w),
            // Seekbar + duration
            Expanded(
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      thumbShape: RoundSliderThumbShape(
                        enabledThumbRadius: 5.r,
                      ),
                      overlayShape: RoundSliderOverlayShape(
                        overlayRadius: 12.r,
                      ),
                      activeTrackColor: AppTheme.primaryColor,
                      inactiveTrackColor: AppTheme.borderColor,
                      thumbColor: AppTheme.primaryColor,
                    ),
                    child: Slider(
                      value: totalDuration.inMilliseconds > 0
                          ? _audioPosition.inMilliseconds.toDouble().clamp(
                              0,
                              totalDuration.inMilliseconds.toDouble(),
                            )
                          : 0,
                      max: totalDuration.inMilliseconds > 0
                          ? totalDuration.inMilliseconds.toDouble()
                          : 1,
                      onChanged: (val) {
                        _audioPlayer?.seek(Duration(milliseconds: val.toInt()));
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formatDuration(_audioPosition),
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: AppTheme.textLightColor,
                          ),
                        ),
                        Text(
                          formatDuration(totalDuration),
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: AppTheme.textLightColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.read(authControllerProvider).valueOrNull?.id;
    final isOwnPoem =
        currentUserId != null && currentUserId == widget.poem.author.id;

    return Container(
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
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Author row ──
          Row(
            children: [
              _buildAvatar(context),
              SizedBox(width: 8.w),
              Expanded(child: _buildAuthorText(context)),
              // 3-dot menu
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  Icons.more_horiz,
                  size: 20.r,
                  color: AppTheme.textLightColor,
                ),
                color: AppTheme.surfaceColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                onSelected: (value) async {
                  switch (value) {
                    case 'edit':
                      final updated = await context.push<PoemModel>(
                        '/editor',
                        extra: widget.poem,
                      );
                      if (updated != null) widget.onUpdated?.call(updated);
                      break;
                    case 'delete':
                      _deletePoem();
                      break;
                    case 'report':
                      AppSnackbar.show(
                        context,
                        message: 'Report submitted',
                        type: SnackbarType.success,
                      );
                      break;
                    case 'plagiarism':
                      AppSnackbar.show(
                        context,
                        message: 'Plagiarism check coming soon',
                        type: SnackbarType.info,
                      );
                      break;
                    case 'share':
                      AppSnackbar.show(
                        context,
                        message: 'Sharing coming soon',
                        type: SnackbarType.info,
                      );
                      break;
                  }
                },
                itemBuilder: (ctx) => [
                  if (isOwnPoem) ...[
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ] else ...[
                    const PopupMenuItem(value: 'report', child: Text('Report')),
                  ],
                  const PopupMenuItem(
                    value: 'plagiarism',
                    child: Text('Check Plagiarism'),
                  ),
                ],
              ),
            ],
          ),

          // ── Description with @mentions ──
          _buildDescription(),

          SizedBox(height: 12.h),

          // ── Title ──
          if (widget.poem.title.isNotEmpty &&
              widget.poem.title != 'Untitled Poem')
            Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  widget.poem.title,
                  textAlign: _textAlignEnum,
                  style: TextStyle(
                    fontFamily: 'JosefinSans',
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                    color: AppTheme.textDarkColor,
                  ),
                ),
              ),
            ),

          // ── Poem body (full, no truncation) ──
          IgnorePointer(
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
                    TextStyle(
                      fontFamily: 'JosefinSans',
                      fontSize: 15.sp,
                      color: AppTheme.textDarkColor.withValues(alpha: 0.85),
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

          // ── Attribution (only for original poems) ──
          if (widget.poem.isOriginal)
            Padding(
              padding: EdgeInsets.only(top: 24.h),
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  '— @${widget.poem.author.username}',
                  textAlign: _textAlignEnum,
                  style: TextStyle(
                    fontFamily: 'JosefinSans',
                    fontSize: 14.sp,
                    fontStyle: FontStyle.normal,
                    color: AppTheme.textMediumColor,
                  ),
                ),
              ),
            ),

          // ── Audio seekbar ──
          _buildAudioSeekbar(),

          SizedBox(height: 16.h),
          Divider(
            color: AppTheme.borderColor.withValues(alpha: 0.5),
            height: 1,
          ),
          SizedBox(height: 12.h),

          // ── Footer: like / comment / repost + copyright + share ──
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

              // Comment button — FIX #8: uses local _commentCount
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

              // Copyright badge
              if (widget.poem.isOriginal)
                Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: Icon(
                    Icons.copyright_rounded,
                    size: 14.r,
                    color: AppTheme.primaryColor,
                  ),
                ),

              // Share icon
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => PoemShareSheet(poem: widget.poem),
                  );
                },
                child: Icon(
                  Icons.share_outlined,
                  size: 18.r,
                  color: AppTheme.textLightColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/profile/${widget.poem.author.id}'),
      child: CircleAvatar(
        radius: 17.r,
        backgroundColor: AppTheme.borderColor,
        backgroundImage: widget.poem.author.photoURL.isNotEmpty
            ? CachedNetworkImageProvider(widget.poem.author.photoURL)
            : null,
        child: widget.poem.author.photoURL.isEmpty
            ? Text(
                widget.poem.author.displayName.isNotEmpty
                    ? widget.poem.author.displayName[0].toUpperCase()
                    : '?',
                style: TextStyle(fontSize: 14.sp, color: Colors.white),
              )
            : null,
      ),
    );
  }

  Widget _buildAuthorText(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/profile/${widget.poem.author.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  widget.poem.author.displayName,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDarkColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '@${widget.poem.author.username}',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppTheme.textLightColor,
                ),
              ),
              if (widget.poem.createdAt != null) ...[
                SizedBox(width: 6.w),
                Text(
                  '•',
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: AppTheme.textLightColor,
                  ),
                ),
                SizedBox(width: 6.w),
                Text(
                  timeago.format(widget.poem.createdAt!, locale: 'en_short'),
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppTheme.textLightColor,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
