import 'dart:convert';
import 'package:flutter/material.dart';
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

  late bool _isLiked;
  late int _likeCount;
  late bool _isReposted;
  late int _repostCount;
  bool _isLikeLoading = false;
  bool _isRepostLoading = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.poem.isLikedByMe;
    _likeCount = widget.poem.likesCount;
    _isReposted = widget.poem.isRepostedByMe;
    _repostCount = widget.poem.repostsCount;

    try {
      final doc = Document.fromJson(jsonDecode(widget.poem.contentJson) as List);
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
      if (widget.poem.audioUrl.isNotEmpty) {
        await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(widget.poem.audioUrl)));
        await _audioPlayer.play();
        setState(() => _isPlayingAudio = true);
        _audioPlayer.playerStateStream.listen((s) {
          if (s.processingState == ProcessingState.completed) {
            if (mounted) setState(() => _isPlayingAudio = false);
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    setState(() {
      _isLikeLoading = true;
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });
    try {
      final result = await ref.read(socialRepoProvider).togglePoemLike(widget.poem.id);
      if (mounted) setState(() { _isLiked = result.liked; _likeCount = result.likesCount; });
    } catch (_) {
      if (mounted) setState(() { _isLiked = !_isLiked; _likeCount += _isLiked ? 1 : -1; });
    } finally {
      if (mounted) setState(() => _isLikeLoading = false);
    }
  }

  Future<void> _toggleRepost() async {
    setState(() { _isRepostLoading = true; });
    try {
      final result = await ref.read(socialRepoProvider).toggleRepost(widget.poem.id);
      if (mounted) setState(() {
        _isReposted = result.reposted;
        _repostCount = result.repostsCount;
      });
    } catch (e) {
      if (mounted) AppSnackbar.show(context, message: e.toString(), type: SnackbarType.error);
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
    final poem = widget.poem;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (ref.watch(authControllerProvider).valueOrNull?.id == poem.author.id)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/editor', extra: poem),
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
                            Text(timeago.format(poem.createdAt!, locale: 'en_short'),
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
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: AppTheme.featureBackgroundColor,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _toggleAudio,
                      icon: Icon(
                        _isPlayingAudio ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                        size: 36.r,
                        color: AppTheme.primaryColor,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    SizedBox(width: 8.w),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Listen to this poem', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500, color: AppTheme.textDarkColor)),
                        if (poem.audioDuration > 0)
                          Text(
                            '${poem.audioDuration ~/ 60}:${(poem.audioDuration % 60).toString().padLeft(2, '0')}',
                            style: TextStyle(fontSize: 12.sp, color: AppTheme.textLightColor),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

            SizedBox(height: 16.h),

            // ── Hashtags ──
            if (poem.hashtags.isNotEmpty)
              Wrap(
                spacing: 8.w,
                runSpacing: 4.h,
                children: poem.hashtags.map((tag) => Text(
                  '#$tag',
                  style: TextStyle(fontSize: 13.sp, color: AppTheme.primaryColor),
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
                      Text('${widget.poem.commentsCount}', style: TextStyle(fontSize: 13.sp, color: AppTheme.textLightColor)),
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
