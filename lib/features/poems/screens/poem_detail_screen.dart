import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';
import 'package:chatbee/features/feed/controllers/feed_controller.dart';
import 'package:chatbee/features/social/providers/social_events.dart';
import 'package:chatbee/features/social/repos/social_repo.dart';
import 'package:chatbee/features/auth/controllers/auth_controller.dart';
import 'package:chatbee/features/social/widgets/comment_bottom_sheet.dart';
import 'package:chatbee/shared/widgets/app_snackbar.dart';

class PoemDetailScreen extends ConsumerStatefulWidget {
  final PoemModel poem;

  const PoemDetailScreen({super.key, required this.poem});

  @override
  ConsumerState<PoemDetailScreen> createState() => _PoemDetailScreenState();
}

class _PoemDetailScreenState extends ConsumerState<PoemDetailScreen> {
  late QuillController _quillController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingAudio = false;

  late PoemModel _poem;
  late bool _isLiked;
  late int _likeCount;
  late bool _isReposted;
  late int _repostCount;
  late int _commentCount;
  bool _isLikeLoading = false;
  bool _isRepostLoading = false;
  StreamSubscription? _socialSub;
  StreamSubscription? _audioStateSub;

  @override
  void initState() {
    super.initState();
    _poem = widget.poem;
    _isLiked = _poem.isLikedByMe;
    _likeCount = _poem.likesCount;
    _isReposted = _poem.isRepostedByMe;
    _repostCount = _poem.repostsCount;
    _commentCount = _poem.commentsCount;

    _socialSub = ref.read(socialEventStreamProvider).stream.listen((event) {
      if (event.poemId == _poem.id && mounted) {
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
      final doc = Document.fromJson(jsonDecode(_poem.contentJson) as List);
      _quillController = QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
    } catch (_) {
      _quillController = QuillController.basic();
    }
  }

  @override
  void dispose() {
    _socialSub?.cancel();
    _audioStateSub?.cancel();
    _quillController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    if (_isPlayingAudio) {
      await _audioPlayer.stop();
      setState(() => _isPlayingAudio = false);
      return;
    }
    try {
      if (_poem.audioUrl.isNotEmpty) {
        await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(_poem.audioUrl)));
        _audioPlayer.play();
        setState(() => _isPlayingAudio = true);
        
        _audioStateSub?.cancel();
        _audioStateSub = _audioPlayer.playerStateStream.listen((s) {
          if (s.processingState == ProcessingState.completed) {
            if (mounted) setState(() => _isPlayingAudio = false);
          }
        });
      }
    } catch (_) {}
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
      final result = await ref.read(socialRepoProvider).togglePoemLike(_poem.id);
      if (mounted) setState(() { _isLiked = result.liked; _likeCount = result.likesCount; });
      ref.read(socialEventStreamProvider).emit(SocialEvent(
          poemId: _poem.id, isLiked: result.liked, likesCount: result.likesCount));
    } catch (_) {
      if (mounted) setState(() { _isLiked = wasLiked; _likeCount = originalCount; });
    } finally {
      if (mounted) setState(() => _isLikeLoading = false);
    }
  }

  Future<void> _toggleRepost() async {
    HapticFeedback.lightImpact();
    final wasReposted = _isReposted;
    final originalCount = _repostCount;

    setState(() { _isRepostLoading = true; _isReposted = !_isReposted; _repostCount += _isReposted ? 1 : -1; });
    try {
      final result = await ref.read(socialRepoProvider).toggleRepost(_poem.id);
      if (mounted) setState(() {
        _isReposted = result.reposted;
        _repostCount = result.repostsCount;
      });
      ref.read(socialEventStreamProvider).emit(SocialEvent(
          poemId: _poem.id, isReposted: result.reposted, repostsCount: result.repostsCount));
    } catch (e) {
      if (mounted) {
        setState(() { _isReposted = wasReposted; _repostCount = originalCount; });
        AppSnackbar.show(context, message: e.toString(), type: SnackbarType.error);
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
      builder: (_) => CommentBottomSheet(poemId: _poem.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final poem = _poem;
    Color? bgColor;
    if (poem.coverColor.isNotEmpty) {
      try {
        bgColor = Color(int.parse(poem.coverColor.replaceFirst('#', '0xFF'))).withValues(alpha: 0.1);
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: bgColor ?? AppTheme.surfaceColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: 'https://chatbee.app/poem/${poem.id}'));
              AppSnackbar.show(context, message: 'Link copied to clipboard');
            },
          ),
          if (ref.watch(authControllerProvider).valueOrNull?.id == poem.author.id)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final updatedPoem = await context.push<PoemModel>('/editor', extra: _poem);
                if (updatedPoem != null && mounted) {
                  setState(() {
                    _poem = updatedPoem;
                    _quillController.dispose();
                    try {
                      final doc = Document.fromJson(jsonDecode(_poem.contentJson) as List);
                      _quillController = QuillController(
                        document: doc,
                        selection: const TextSelection.collapsed(offset: 0),
                        readOnly: true,
                      );
                    } catch (_) {
                      _quillController = QuillController.basic();
                    }
                  });
                }
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Repost indicator ──
            if (poem.isRepost) ...[
              Row(
                children: [
                  Icon(Icons.repeat_rounded, size: 14.r, color: AppTheme.textLightColor),
                  SizedBox(width: 8.w),
                  Text(
                    'Reposted',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppTheme.textLightColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
            ],

            // ── Author row (tappable → their profile) ──
            GestureDetector(
              onTap: () => context.push('/profile/${poem.author.id}'),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22.r,
                    backgroundColor: AppTheme.borderColor,
                    backgroundImage: poem.author.photoURL.isNotEmpty
                        ? CachedNetworkImageProvider(poem.author.photoURL)
                        : null,
                  ),
                  SizedBox(width: 12.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(poem.author.displayName,
                            style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600, color: AppTheme.textDarkColor)),
                        if (poem.author.isEditor) ...[
                          SizedBox(width: 4.w),
                          Icon(Icons.verified_rounded, size: 14.r, color: AppTheme.primaryColor),
                        ],
                      ]),
                      Row(
                        children: [
                          Text('@${poem.author.username}',
                              style: TextStyle(fontSize: 12.sp, color: AppTheme.textLightColor)),
                          if (poem.createdAt != null) ...[
                            Text(' • ', style: TextStyle(fontSize: 12.sp, color: AppTheme.textLightColor)),
                            Text(timeago.format(poem.createdAt!.toLocal(), locale: 'en_short'),
                                style: TextStyle(fontSize: 12.sp, color: AppTheme.textLightColor)),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (poem.mood.isNotEmpty)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        poem.mood,
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            SizedBox(height: 24.h),

            // ── Title ──
            if (poem.title.isNotEmpty && poem.title != 'Untitled Poem')
              Text(
                poem.title,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 26.sp,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDarkColor,
                  height: 1.3,
                ),
              ),

            SizedBox(height: 16.h),

            // ── Rich text content rendered via Quill (read-only) ──
            QuillEditor.basic(
              controller: _quillController,
              config: QuillEditorConfig(
                padding: EdgeInsets.zero,
                customStyles: DefaultStyles(
                  paragraph: DefaultTextBlockStyle(
                    GoogleFonts.lato(fontSize: 17.sp, height: 1.2, color: AppTheme.textDarkColor),
                    const HorizontalSpacing(0, 0),
                    const VerticalSpacing(0, 0),
                    const VerticalSpacing(0, 0),
                    null,
                  ),
                ),
              ),
            ),

            SizedBox(height: 24.h),

            // ── Audio player if present ──
            if (poem.hasAudio)
              Container(
                margin: EdgeInsets.only(top: 8.h),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: AppTheme.featureBackgroundColor,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: AppTheme.borderColor),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: StreamBuilder<PlayerState>(
                  stream: _audioPlayer.playerStateStream,
                  builder: (context, snapshot) {
                    final processingState = snapshot.data?.processingState;
                    final playing = snapshot.data?.playing ?? false;
                    
                    return Row(
                      children: [
                        Container(
                          width: 44.r,
                          height: 44.r,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: _toggleAudio,
                            icon: processingState == ProcessingState.buffering
                                ? const CircularProgressIndicator()
                                : Icon(
                                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                    size: 26.r,
                                    color: AppTheme.primaryColor,
                                  ),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: StreamBuilder<Duration>(
                            stream: _audioPlayer.positionStream,
                            builder: (context, posSnap) {
                              final position = posSnap.data ?? Duration.zero;
                              final durationText = '${(poem.audioDuration ~/ 60)}:${(poem.audioDuration % 60).toString().padLeft(2, '0')}';
                              final positionText = '${(position.inSeconds ~/ 60)}:${(position.inSeconds % 60).toString().padLeft(2, '0')}';
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Voice Recording', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: AppTheme.textDarkColor)),
                                      Text('$positionText / $durationText', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w500, color: AppTheme.primaryColor)),
                                    ],
                                  ),
                                  SizedBox(height: 4.h),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4.r),
                                    child: LinearProgressIndicator(
                                      value: poem.audioDuration > 0 ? position.inSeconds / poem.audioDuration : 0.0,
                                      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                                      minHeight: 4.h,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

            SizedBox(height: 16.h),

            // ── Hashtags ──
            if (poem.hashtags.isNotEmpty)
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: poem.hashtags.map((tag) => GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(exploreFeedControllerProvider.notifier).filterByHashtag(tag);
                    context.go('/explore'); // Switch tab
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Text(
                      '#$tag',
                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
                    ),
                  ),
                )).toList(),
              ),

            SizedBox(height: 20.h),

            // ── Footer: like / comment / repost + badges ──
            Row(
              children: [
                // Like button
                GestureDetector(
                  onTap: _isLikeLoading ? null : _toggleLike,
                  child: Row(
                    children: [
                      Icon(
                        _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        size: 18.r,
                        color: _isLiked ? Colors.red : AppTheme.textLightColor,
                      ),
                      SizedBox(width: 4.w),
                      Text('$_likeCount', style: TextStyle(fontSize: 13.sp, color: AppTheme.textLightColor)),
                    ],
                  ),
                ),

                SizedBox(width: 16.w),

                // Comment button — opens comment sheet
                GestureDetector(
                  onTap: () => _showComments(context),
                  child: Row(
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded, size: 18.r, color: AppTheme.textLightColor),
                      SizedBox(width: 4.w),
                      Text('$_commentCount', style: TextStyle(fontSize: 13.sp, color: AppTheme.textLightColor)),
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
                        color: _isReposted ? AppTheme.primaryColor : AppTheme.textLightColor,
                      ),
                      SizedBox(width: 4.w),
                      Text('$_repostCount',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: _isReposted ? AppTheme.primaryColor : AppTheme.textLightColor,
                          )),
                    ],
                  ),
                ),

                const Spacer(),

                if (poem.isOriginal)
                  Icon(Icons.copyright_rounded, size: 14.r, color: AppTheme.primaryColor),
              ],
            ),

            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }
}
