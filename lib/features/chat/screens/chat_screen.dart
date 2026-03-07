import 'dart:async';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:chatbee/features/chat/controllers/message_controller.dart';
import 'package:chatbee/features/chat/controllers/ws_event_handler.dart';
import 'package:chatbee/features/chat/models/message_response.dart';
import 'package:chatbee/features/chat/models/message_type.dart';
import 'package:chatbee/features/chat/controllers/chat_list_controller.dart';
import 'package:chatbee/features/chat/screens/widgets/attachment_picker.dart';
import 'package:chatbee/features/chat/screens/widgets/gif_picker_sheet.dart';
import 'package:chatbee/features/chat/screens/widgets/media_bubble.dart';
import 'package:chatbee/features/chat/models/media_metadata.dart';
import 'package:chatbee/core/services/media_picker_service.dart';
import 'package:chatbee/core/services/giphy_service.dart';
import 'package:chatbee/core/services/audio_recorder_service.dart';
import 'package:chatbee/shared/widgets/app_snackbar.dart';
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/features/auth/controllers/auth_controller.dart';
import 'package:chatbee/features/chat/controllers/chat_state_controller.dart';

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
    ref
        .read(recordingControllerProvider(widget.roomId).notifier)
        .cancel(); // ensures recording is stopped if leaving screen
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

  void _showAttachmentPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (context) {
        return AttachmentPicker(
          onPickImage: _handlePickImage,
          onPickVideo: _handlePickVideo,
          onPickFile: _handlePickFile,
          onPickGif: _handlePickGif,
        );
      },
    );
  }

  void _handlePickGif() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GifPickerSheet(
          onGifSelected: (gif) {
            Navigator.pop(context); // close gif picker
            _sendGifMessage(gif);
          },
        );
      },
    );
  }

  Future<void> _stopRecording() async {
    ref.read(recordingControllerProvider(widget.roomId).notifier).stop();
    final (path, duration) = await ref
        .read(audioRecorderServiceProvider)
        .stopRecording();

    if (mounted) {
      if (path != null && duration >= 1) {
        final file = File(path);
        final size = file.existsSync() ? file.lengthSync() : 0;
        final inputState = ref.read(chatInputControllerProvider(widget.roomId));

        ref
            .read(messageControllerProvider(widget.roomId).notifier)
            .sendMediaMessage(
              filePath: path,
              fileName: 'Voice message',
              messageType: MessageType.audio,
              mimeType: 'audio/m4a',
              replyToId: inputState.replyToId,
              fileSize: size,
            );
        _clearPreview();
      }
    }
  }

  Future<void> _cancelRecording() async {
    ref.read(recordingControllerProvider(widget.roomId).notifier).cancel();
  }

  void _onAttachmentPressed() {
    _showAttachmentPicker();
  }

  void _onSendMessageRequested(String content) {
    if (content.isEmpty) return;

    final inputState = ref.read(chatInputControllerProvider(widget.roomId));

    if (inputState.editingMessageId != null) {
      ref
          .read(messageControllerProvider(widget.roomId).notifier)
          .editMessageRemote(inputState.editingMessageId!, content);
    } else {
      ref
          .read(messageControllerProvider(widget.roomId).notifier)
          .sendMessage(content, replyToId: inputState.replyToId);
    }
    _messageController.clear();
    _clearPreview();
  }

  void _sendGifMessage(GiphyGif gif) {
    try {
      final metadata = MediaMetadata(
        fileName: gif.title,
        mimeType: 'image/gif',
      );
      final inputState = ref.read(chatInputControllerProvider(widget.roomId));

      ref
          .read(messageControllerProvider(widget.roomId).notifier)
          .sendMessage(
            gif.url,
            replyToId: inputState.replyToId,
            type: MessageType.gif,
            metadata: metadata,
          );
      _clearPreview();
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Failed to send GIF: $e',
          type: SnackbarType.error,
        );
      }
    }
  }

  Future<void> _handlePickImage(ImageSource source) async {
    final pickerService = ref.read(mediaPickerServiceProvider);
    final picked = await pickerService.pickImage(source: source);
    if (picked == null) return;
    _sendMediaMessage(picked, MessageType.image);
  }

  Future<void> _handlePickVideo(ImageSource source) async {
    final pickerService = ref.read(mediaPickerServiceProvider);
    final picked = await pickerService.pickVideo(source: source);
    if (picked == null) return;
    _sendMediaMessage(picked, MessageType.video);
  }

  Future<void> _handlePickFile() async {
    final pickerService = ref.read(mediaPickerServiceProvider);
    final picked = await pickerService.pickFile();
    if (picked == null) return;
    _sendMediaMessage(picked, MessageType.file);
  }

  void _sendMediaMessage(PickedMedia picked, MessageType type) {
    try {
      final inputState = ref.read(chatInputControllerProvider(widget.roomId));
      ref
          .read(messageControllerProvider(widget.roomId).notifier)
          .sendMediaMessage(
            filePath: picked.filePath,
            fileName: picked.fileName,
            messageType: type,
            mimeType: picked.mimeType,
            fileSize: picked.fileSize,
            replyToId: inputState.replyToId,
          );
      _clearPreview();
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Failed to send media: $e',
          type: SnackbarType.error,
        );
      }
    }
  }

  void _clearPreview() {
    ref.read(chatInputControllerProvider(widget.roomId).notifier).clear();
    _messageController.clear();
  }

  void _setReply(MessageResponse message) {
    final content = message.isMedia
        ? message.messageType.previewText(message.metadata?.fileName)
        : message.content;
    ref
        .read(chatInputControllerProvider(widget.roomId).notifier)
        .setReply(message.id, content);
    _messageController.clear();
  }

  void _setEdit(String messageId, String content) {
    ref
        .read(chatInputControllerProvider(widget.roomId).notifier)
        .setEdit(messageId, content);
    _messageController.text = content;
  }

  void _showActionMenu(MessageResponse message, bool isMe) {
    if (message.isDeleted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ['👍', '❤️', '😂', '😮', '😢', '🙏'].map((emoji) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        ref
                            .read(
                              messageControllerProvider(widget.roomId).notifier,
                            )
                            .toggleReactionRemote(message.id, emoji);
                      },
                      child: Text(emoji, style: TextStyle(fontSize: 28.sp)),
                    );
                  }).toList(),
                ),
              ),
              Divider(height: 1, color: AppTheme.borderColor),
              ListTile(
                leading: const Icon(Icons.reply_rounded),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(context);
                  _setReply(message);
                },
              ),
              if (isMe && !message.isMedia) ...[
                ListTile(
                  leading: const Icon(Icons.edit_rounded),
                  title: const Text('Edit'),
                  onTap: () {
                    Navigator.pop(context);
                    _setEdit(message.id, message.content);
                  },
                ),
              ],
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.delete_rounded, color: Colors.red),
                  title: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    ref
                        .read(messageControllerProvider(widget.roomId).notifier)
                        .deleteMessageRemote(message.id);
                  },
                ),
            ],
          ),
        );
      },
    );
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

    // Get room details to find the other user's info
    final chatListState = ref.watch(chatListControllerProvider);
    final currentRoom = chatListState.valueOrNull?.firstWhere(
      (r) => r.id == widget.roomId,
      // fallback if not found
      orElse: () => throw StateError('Room not found'),
    );

    // Find the other participant
    final otherParticipant = currentRoom?.participants.firstWhere(
      (p) => p.id != currentUserId,
      // fallback
      orElse: () => throw StateError('Participant not found'),
    );

    final displayName = otherParticipant?.displayName ?? 'Chat';
    final photoURL = otherParticipant?.photoURL;
    final isOnline = otherParticipant?.isOnline ?? false;
    final isTyping = typingUsers.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 20.r,
                  backgroundColor: AppTheme.borderColor,
                  backgroundImage: photoURL != null
                      ? NetworkImage(photoURL)
                      : null,
                  child: photoURL == null
                      ? Icon(Icons.person, color: Colors.white, size: 20.r)
                      : null,
                ),
                if (isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12.r,
                      height: 12.r,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: 12.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  isTyping ? 'typing...' : (isOnline ? 'Online' : 'Offline'),
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: isTyping
                        ? AppTheme.primaryColor
                        : AppTheme.textMediumColor,
                    fontWeight: isTyping ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ],
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
                          onLongPress: () => _showActionMenu(message, isMe),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Action preview (reply/edit)
          Consumer(
            builder: (context, ref, child) {
              final inputState = ref.watch(
                chatInputControllerProvider(widget.roomId),
              );
              if (inputState.replyToContent == null &&
                  inputState.editingContent == null) {
                return const SizedBox.shrink();
              }
              return Container(
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            inputState.editingContent != null
                                ? 'Editing message'
                                : 'Replying to message',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            inputState.editingContent ??
                                inputState.replyToContent!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: AppTheme.textMediumColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 18.r),
                      onPressed: _clearPreview,
                    ),
                  ],
                ),
              );
            },
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
            child: Consumer(
              builder: (context, ref, child) {
                final isRecording = ref.watch(
                  recordingControllerProvider(
                    widget.roomId,
                  ).select((s) => s.isRecording),
                );
                if (isRecording) {
                  return _RecordingBar(
                    roomId: widget.roomId,
                    onStop: _stopRecording,
                    onCancel: _cancelRecording,
                  );
                } else {
                  return _ChatInputBar(
                    roomId: widget.roomId,
                    controller: _messageController,
                    onSend: _onSendMessageRequested,
                    onAttachment: _onAttachmentPressed,
                    onChanged: _onTextChanged,
                  );
                }
              },
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

class _ChatInputBar extends ConsumerWidget {
  final String roomId;
  final TextEditingController controller;
  final Function(String) onSend;
  final VoidCallback onAttachment;
  final Function(String) onChanged;

  const _ChatInputBar({
    required this.roomId,
    required this.controller,
    required this.onSend,
    required this.onAttachment,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasText = value.text.trim().isNotEmpty;
        return Row(
          children: [
            // Attachment button
            IconButton(
              icon: Icon(
                Icons.attach_file_rounded,
                size: 22.r,
                color: AppTheme.textMediumColor,
              ),
              onPressed: onAttachment,
            ),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
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
                color: hasText ? AppTheme.primaryColor : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  hasText ? Icons.send_rounded : Icons.mic_rounded,
                  size: 20.r,
                  color: hasText ? Colors.white : AppTheme.textDarkColor,
                ),
                onPressed: hasText
                    ? () => onSend(controller.text.trim())
                    : () => ref
                          .read(recordingControllerProvider(roomId).notifier)
                          .start(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RecordingBar extends ConsumerWidget {
  final String roomId;
  final VoidCallback onStop;
  final VoidCallback onCancel;

  const _RecordingBar({
    required this.roomId,
    required this.onStop,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordingControllerProvider(roomId));
    final minutes = (state.durationSeconds / 60).floor().toString().padLeft(
      2,
      '0',
    );
    final seconds = (state.durationSeconds % 60).floor().toString().padLeft(
      2,
      '0',
    );

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
          onPressed: onCancel,
        ),
        Expanded(
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mic, color: Colors.red, size: 16.sp),
                SizedBox(width: 8.w),
                Text(
                  '$minutes:$seconds',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textDarkColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(Icons.send_rounded, size: 20.r, color: Colors.white),
            onPressed: onStop,
          ),
        ),
      ],
    );
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
            color: AppTheme.borderColor.withValues(alpha: 0.5),
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
  final VoidCallback onLongPress;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDeleted = message.isDeleted;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
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
                        ? Colors.white.withValues(alpha: 0.15)
                        : AppTheme.borderColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    message.replyTo!.isMedia
                        ? message.replyTo!.messageType.previewText(
                            message.replyTo!.metadata?.fileName,
                          )
                        : message.replyTo!.content,
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
              if (message.isMedia)
                MediaBubble(message: message, isMe: isMe)
              else
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
                              ? Colors.white.withValues(alpha: 0.2)
                              : AppTheme.borderColor.withValues(alpha: 0.5),
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
