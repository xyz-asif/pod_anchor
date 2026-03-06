import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:chatbee/features/chat/controllers/message_controller.dart';
import 'package:chatbee/features/chat/controllers/ws_event_handler.dart';
import 'package:chatbee/features/chat/models/message_response.dart';
import 'package:chatbee/features/auth/controllers/auth_controller.dart';
import 'package:chatbee/shared/widgets/app_snackbar.dart';
import 'package:chatbee/config/theme/app_theme.dart';

/// Chat screen — message list with input bar.
///
/// Features:
/// - Scrollable message list (oldest at top)
/// - Optimistic message sending
/// - Typing indicator
/// - Reply preview
/// - Load older messages on scroll-to-top
class ChatScreen extends ConsumerStatefulWidget {
  final String roomId;

  const ChatScreen({super.key, required this.roomId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  String? _replyToId;
  String? _replyToContent;
  Timer? _typingDebounce;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    // Start listening to WS events
    ref.read(wsEventHandlerProvider);

    // Mark room as read explicitly when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(messageControllerProvider(widget.roomId).notifier).markAsRead();
    });

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingDebounce?.cancel();
    // Stop typing if still typing
    if (_isTyping) {
      ref.read(typingControllerProvider(widget.roomId).notifier).stopTyping();
    }
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 50) {
      ref.read(messageControllerProvider(widget.roomId).notifier).loadOlder();
    }
  }

  void _onTextChanged(String text) {
    if (text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      ref.read(typingControllerProvider(widget.roomId).notifier).startTyping();
    }

    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        _isTyping = false;
        ref.read(typingControllerProvider(widget.roomId).notifier).stopTyping();
      }
    });
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    ref
        .read(messageControllerProvider(widget.roomId).notifier)
        .sendMessage(content, replyToId: _replyToId);

    _messageController.clear();
    _clearReply();

    // Stop typing
    if (_isTyping) {
      _isTyping = false;
      ref.read(typingControllerProvider(widget.roomId).notifier).stopTyping();
    }
  }

  void _setReply(String messageId, String content) {
    setState(() {
      _replyToId = messageId;
      _replyToContent = content;
    });
  }

  void _clearReply() {
    setState(() {
      _replyToId = null;
      _replyToContent = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final messagesState = ref.watch(messageControllerProvider(widget.roomId));
    final typingState = ref.watch(typingControllerProvider(widget.roomId));
    final currentUserId =
        ref.watch(authControllerProvider).valueOrNull?.id ?? '';

    // Error snackbar & active reading & auto-scroll
    ref.listen(messageControllerProvider(widget.roomId), (prev, next) {
      next.whenOrNull(
        error: (e, _) => AppSnackbar.show(
          context,
          message: e.toString(),
          type: SnackbarType.error,
        ),
        data: (messages) {
          final prevList = prev?.valueOrNull ?? [];
          if (messages.length > prevList.length && messages.isNotEmpty) {
            final lastMsg =
                messages.last; // state is chronological, last is newest
            // If the newest incoming message is from someone else and unread, mark it read
            if (lastMsg.senderId != currentUserId && lastMsg.status != 'read') {
              ref
                  .read(messageControllerProvider(widget.roomId).notifier)
                  .markAsRead();
            }

            // Auto-scroll to bottom if user is near the end
            if (_scrollController.hasClients &&
                _scrollController.position.pixels <= 150) {
              Future.delayed(const Duration(milliseconds: 50), () {
                if (_scrollController.hasClients) {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  );
                }
              });
            }
          }
        },
      );
    });

    // Who is typing (exclude self)
    final typingUsers = typingState.entries
        .where((e) => e.value && e.key != currentUserId)
        .map((e) => e.key)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chat', style: TextStyle(fontSize: 16.sp)),
            if (typingUsers.isNotEmpty)
              Text(
                'typing...',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Message list
          Expanded(
            child: messagesState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  e.toString(),
                  style: TextStyle(fontSize: 14.sp, color: Colors.red),
                ),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet.\nSay hello! 👋',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppTheme.textMediumColor,
                      ),
                    ),
                  );
                }

                // Reverse messages for bottom-to-top layout
                final reversedMessages = messages.reversed.toList();

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 8.h,
                  ),
                  itemCount: reversedMessages.length,
                  itemBuilder: (context, index) {
                    final message = reversedMessages[index];
                    final isMe = message.senderId == currentUserId;

                    // Since it's reversed, the "previous" message in chronological order
                    // is actually at index + 1
                    final isLastInGroup = index == reversedMessages.length - 1;
                    final showDate =
                        isLastInGroup ||
                        _isDifferentDay(
                          reversedMessages[index + 1].createdAt,
                          message.createdAt,
                        );

                    return Column(
                      children: [
                        if (showDate && message.createdAt != null)
                          _DateSeparator(date: message.createdAt!),
                        _MessageBubble(
                          message: message,
                          isMe: isMe,
                          onReply: () => _setReply(message.id, message.content),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Reply preview
          if (_replyToContent != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              color: AppTheme.featureBackgroundColor,
              child: Row(
                children: [
                  Container(
                    width: 3.w,
                    height: 32.h,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      _replyToContent!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: AppTheme.textMediumColor,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 18.r),
                    onPressed: _clearReply,
                  ),
                ],
              ),
            ),

          // Input bar
          Container(
            padding: EdgeInsets.only(
              left: 12.w,
              right: 4.w,
              top: 8.h,
              bottom: MediaQuery.of(context).padding.bottom + 8.h,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: AppTheme.borderColor, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onChanged: _onTextChanged,
                    maxLines: 4,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(
                        fontSize: 14.sp,
                        color: AppTheme.textLightColor,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24.r),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppTheme.featureBackgroundColor,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 10.h,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 4.w),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.send_rounded,
                      size: 20.r,
                      color: Colors.white,
                    ),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isDifferentDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return true;
    return a.day != b.day || a.month != b.month || a.year != b.year;
  }
}

/// Date separator between message groups.
class _DateSeparator extends StatelessWidget {
  final DateTime date;

  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday =
        date.day == now.day && date.month == now.month && date.year == now.year;
    final isYesterday = () {
      final yesterday = now.subtract(const Duration(days: 1));
      return date.day == yesterday.day &&
          date.month == yesterday.month &&
          date.year == yesterday.year;
    }();

    String label;
    if (isToday) {
      label = 'Today';
    } else if (isYesterday) {
      label = 'Yesterday';
    } else {
      label = '${date.day}/${date.month}/${date.year}';
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: AppTheme.borderColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: 11.sp, color: AppTheme.textMediumColor),
          ),
        ),
      ),
    );
  }
}

/// Individual message bubble.
class _MessageBubble extends StatelessWidget {
  final MessageResponse message;
  final bool isMe;
  final VoidCallback onReply;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final isDeleted = message.isDeleted;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onReply,
        child: Container(
          constraints: BoxConstraints(maxWidth: 280.w),
          margin: EdgeInsets.only(
            top: 2.h,
            bottom: 2.h,
            left: isMe ? 48.w : 0,
            right: isMe ? 0 : 48.w,
          ),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: isDeleted
                ? Colors.grey.shade100
                : isMe
                ? AppTheme.primaryColor
                : AppTheme.featureBackgroundColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16.r),
              topRight: Radius.circular(16.r),
              bottomLeft: Radius.circular(isMe ? 16.r : 4.r),
              bottomRight: Radius.circular(isMe ? 4.r : 16.r),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Reply preview
              if (message.replyTo != null)
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(bottom: 4.h),
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: isMe
                        ? Colors.white.withOpacity(0.15)
                        : AppTheme.borderColor.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    message.replyTo!.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: isMe ? Colors.white70 : AppTheme.textMediumColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),

              // Message content
              Text(
                message.content,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: isDeleted
                      ? AppTheme.textMediumColor
                      : isMe
                      ? Colors.white
                      : AppTheme.textDarkColor,
                  fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
                ),
              ),

              SizedBox(height: 2.h),

              // Time + status
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.isEdited)
                    Text(
                      'edited  ',
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: isMe ? Colors.white60 : AppTheme.textLightColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  if (message.createdAt != null)
                    Text(
                      '${message.createdAt!.hour.toString().padLeft(2, '0')}:${message.createdAt!.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: isMe ? Colors.white60 : AppTheme.textLightColor,
                      ),
                    ),
                  if (isMe) ...[
                    SizedBox(width: 4.w),
                    _StatusIcon(status: message.status, isMe: isMe),
                  ],
                ],
              ),

              // Reactions
              if (message.reactions.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 4.h),
                  child: Wrap(
                    spacing: 4.w,
                    children: message.reactions.values.toSet().map((emoji) {
                      final count = message.reactions.values
                          .where((e) => e == emoji)
                          .length;
                      return Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.white.withOpacity(0.2)
                              : AppTheme.borderColor.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Text(
                          count > 1 ? '$emoji $count' : emoji,
                          style: TextStyle(fontSize: 12.sp),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Message status tick icon.
class _StatusIcon extends StatelessWidget {
  final String status;
  final bool isMe;

  const _StatusIcon({required this.status, required this.isMe});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'read':
        return Icon(
          Icons.done_all_rounded,
          size: 16.r,
          color: Colors.lightBlueAccent,
        );
      case 'delivered':
        return Icon(Icons.done_all_rounded, size: 16.r, color: Colors.white70);
      case 'sent':
      default:
        return Icon(Icons.done_rounded, size: 16.r, color: Colors.white70);
    }
  }
}
