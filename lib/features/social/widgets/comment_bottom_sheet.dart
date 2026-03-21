import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/features/auth/controllers/auth_controller.dart';
import 'package:chatbee/features/social/providers/social_events.dart';
import 'package:chatbee/features/social/models/comment_model.dart';
import 'package:chatbee/features/social/repos/social_repo.dart';
import 'package:chatbee/shared/widgets/app_snackbar.dart';

class CommentBottomSheet extends ConsumerStatefulWidget {
  final String poemId;

  const CommentBottomSheet({super.key, required this.poemId});

  @override
  ConsumerState<CommentBottomSheet> createState() => _CommentBottomSheetState();
}

class _CommentBottomSheetState extends ConsumerState<CommentBottomSheet> with AutomaticKeepAliveClientMixin {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final GlobalKey<_CommentInputBarState> _inputBarKey = GlobalKey();

  List<CommentModel> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;

  // @mention suggestion state - use ValueNotifier to avoid rebuilding entire sheet
  final ValueNotifier<List<String>> _suggestionsNotifier = ValueNotifier([]);
  String _currentMentionQuery = '';
  Timer? _mentionDebounce;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _inputController.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    _mentionDebounce?.cancel();
    _suggestionsNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final page = await ref.read(socialRepoProvider).getComments(widget.poemId, limit: 20);
      if (mounted) {
        setState(() {
          _comments = page.comments;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendComment() async {
    final content = _inputController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      final comment = await ref.read(socialRepoProvider).addComment(widget.poemId, content);
      _inputController.clear();
      if (mounted) {
        setState(() {
          _comments.insert(0, comment);
        });
        _suggestionsNotifier.value = [];
        ref.read(socialEventStreamProvider).emit(SocialEvent(
            poemId: widget.poemId, commentsCount: _comments.length));
      }
    } catch (e) {
      if (mounted) AppSnackbar.show(context, message: 'Failed to post comment', type: SnackbarType.error);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _deleteComment(CommentModel comment) async {
    try {
      await ref.read(socialRepoProvider).deleteComment(comment.id);
      if (mounted) {
        setState(() => _comments.removeWhere((c) => c.id == comment.id));
        ref.read(socialEventStreamProvider).emit(SocialEvent(
            poemId: widget.poemId, commentsCount: _comments.length));
      }
    } catch (_) {}
  }

  Future<void> _toggleCommentLike(CommentModel comment) async {
    final index = _comments.indexWhere((c) => c.id == comment.id);
    if (index < 0) return;

    final wasLiked = comment.isLikedByMe;
    setState(() {
      _comments[index] = comment.copyWith(
        isLikedByMe: !wasLiked,
        likesCount: wasLiked ? comment.likesCount - 1 : comment.likesCount + 1,
      );
    });

    try {
      final result = await ref.read(socialRepoProvider).toggleCommentLike(comment.id);
      if (mounted) {
        setState(() {
          _comments[index] = _comments[index].copyWith(
            isLikedByMe: result.liked,
            likesCount: result.likesCount,
          );
        });
      }
    } catch (_) {
      if (mounted) setState(() { _comments[index] = comment; });
    }
  }

  void _onInputChanged() {
    final text = _inputController.text;
    final cursor = _inputController.selection.baseOffset;
    if (cursor < 0 || cursor > text.length) return;

    final textBeforeCursor = text.substring(0, cursor);
    final atIndex = textBeforeCursor.lastIndexOf('@');

    if (atIndex >= 0) {
      final query = textBeforeCursor.substring(atIndex + 1);
      // Only search if query has content and no spaces (still typing a username)
      if (!query.contains(' ') && query.isNotEmpty) {
        // Don't setState here — only update when results arrive
        _currentMentionQuery = query;
        _mentionDebounce?.cancel();
        _mentionDebounce = Timer(const Duration(milliseconds: 300), () => _fetchMentionSuggestions(query));
        return;
      }
      // User typed @ but no query yet, or query has a space — just clear if needed
      if (query.isEmpty && !query.contains(' ')) {
        // Just typed @ — don't do anything, wait for more characters
        _mentionDebounce?.cancel();
        if (_suggestionsNotifier.value.isNotEmpty) {
          _suggestionsNotifier.value = [];
          _currentMentionQuery = '';
        }
        return;
      }
    }

    // No @ context — clear suggestions only if they were showing
    if (_suggestionsNotifier.value.isNotEmpty || _currentMentionQuery.isNotEmpty) {
      _mentionDebounce?.cancel();
      _suggestionsNotifier.value = [];
      _currentMentionQuery = '';
    }
  }

  Future<void> _fetchMentionSuggestions(String query) async {
    try {
      final response = await ref.read(socialRepoProvider).searchUsersForMention(query);
      if (mounted && _currentMentionQuery == query) {
        _suggestionsNotifier.value = response;
        // Request focus back after the frame builds to keep keyboard open
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _inputFocusNode.requestFocus();
        });
      }
    } catch (_) {}
  }

  void _insertMention(String username) {
    final text = _inputController.text;
    final cursor = _inputController.selection.baseOffset;
    final textBeforeCursor = text.substring(0, cursor);
    final atIndex = textBeforeCursor.lastIndexOf('@');

    if (atIndex >= 0) {
      final newText = '${text.substring(0, atIndex)}@$username ${text.substring(cursor)}';
      _inputController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: atIndex + username.length + 2),
      );
    }
    _suggestionsNotifier.value = [];
    _currentMentionQuery = '';
    // Ensure focus returns to input after inserting mention
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inputFocusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final currentUserId = ref.read(authControllerProvider).valueOrNull?.id;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                // Drag handle
                Padding(
                  padding: EdgeInsets.only(top: 12.h, bottom: 8.h),
                  child: Center(
                    child: Container(
                      width: 40.w, height: 4.h,
                      decoration: BoxDecoration(color: AppTheme.borderColor, borderRadius: BorderRadius.circular(2.r)),
                    ),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 4.h),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Comments', style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700, color: AppTheme.textDarkColor)),
                  ),
                ),

                Divider(height: 1, color: AppTheme.borderColor),

                // ── Comment list ──
                Flexible(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _comments.isEmpty
                          ? Center(
                              child: Text('No comments yet. Be the first!',
                                  style: TextStyle(fontSize: 14.sp, color: AppTheme.textMediumColor)))
                          : ListView.separated(
                              controller: scrollController,
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                              itemCount: _comments.length,
                              separatorBuilder: (_, __) => Divider(height: 1, color: AppTheme.borderColor.withValues(alpha: 0.5)),
                              itemBuilder: (_, i) {
                                final comment = _comments[i];
                                final isOwn = comment.author.id == currentUserId;

                                return Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10.h),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 16.r,
                                        backgroundColor: AppTheme.borderColor,
                                        backgroundImage: comment.author.photoURL.isNotEmpty
                                            ? CachedNetworkImageProvider(comment.author.photoURL)
                                            : null,
                                      ),
                                      SizedBox(width: 10.w),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(comment.author.displayName,
                                                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: AppTheme.textDarkColor)),
                                                if (comment.createdAt != null) ...[
                                                  SizedBox(width: 6.w),
                                                  Text(
                                                    timeago.format(comment.createdAt!, locale: 'en_short'),
                                                    style: TextStyle(fontSize: 11.sp, color: AppTheme.textLightColor),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            SizedBox(height: 4.h),
                                            Text(
                                              comment.content,
                                              style: TextStyle(fontSize: 14.sp, color: AppTheme.textMediumColor, height: 1.4),
                                            ),
                                            SizedBox(height: 6.h),
                                            Row(
                                              children: [
                                                // Comment like button
                                                GestureDetector(
                                                  onTap: () => _toggleCommentLike(comment),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        comment.isLikedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                                        size: 14.r,
                                                        color: comment.isLikedByMe ? Colors.red : AppTheme.textLightColor,
                                                      ),
                                                      SizedBox(width: 3.w),
                                                      if (comment.likesCount > 0)
                                                        Text('${comment.likesCount}',
                                                            style: TextStyle(fontSize: 12.sp, color: AppTheme.textLightColor)),
                                                    ],
                                                  ),
                                                ),
                                                const Spacer(),
                                                // Delete button — own comments only
                                                if (isOwn)
                                                  GestureDetector(
                                                    onTap: () => _deleteComment(comment),
                                                    child: Text('Delete',
                                                        style: TextStyle(fontSize: 12.sp, color: Colors.red.withValues(alpha: 0.7))),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),

                // ── Mention suggestions ──
                ValueListenableBuilder<List<String>>(
                  valueListenable: _suggestionsNotifier,
                  builder: (context, suggestions, child) {
                    if (suggestions.isEmpty) return const SizedBox.shrink();
                    return Container(
                      constraints: BoxConstraints(maxHeight: 160.h),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        border: Border(top: BorderSide(color: AppTheme.borderColor)),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: suggestions.length,
                        itemBuilder: (_, i) => ListTile(
                          dense: true,
                          title: Text('@${suggestions[i]}',
                              style: TextStyle(fontSize: 14.sp, color: AppTheme.textDarkColor)),
                          onTap: () => _insertMention(suggestions[i]),
                        ),
                      ),
                    );
                  },
                ),

                // ── Input bar (extracted to maintain focus) ──
                _CommentInputBar(
                  key: _inputBarKey,
                  controller: _inputController,
                  focusNode: _inputFocusNode,
                  isSending: _isSending,
                  onSend: _sendComment,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Extracted input bar widget to maintain focus state across parent rebuilds
class _CommentInputBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final VoidCallback onSend;

  const _CommentInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.onSend,
  });

  @override
  State<_CommentInputBar> createState() => _CommentInputBarState();
}

class _CommentInputBarState extends State<_CommentInputBar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, MediaQuery.of(context).viewInsets.bottom + 12.h),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              maxLines: 3,
              minLines: 1,
              style: TextStyle(fontSize: 14.sp, color: AppTheme.textDarkColor),
              decoration: InputDecoration(
                hintText: 'Add a comment... use @username to mention',
                hintStyle: TextStyle(fontSize: 13.sp, color: AppTheme.textLightColor),
                filled: true,
                fillColor: AppTheme.featureBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.r),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: widget.isSending ? null : widget.onSend,
            child: Container(
              width: 40.r, height: 40.r,
              decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
              child: widget.isSending
                  ? Padding(
                      padding: EdgeInsets.all(10.r),
                      child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Icon(Icons.send_rounded, color: Colors.white, size: 18.r),
            ),
          ),
        ],
      ),
    );
  }
}
