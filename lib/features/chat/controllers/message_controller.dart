import 'dart:developer';
import 'package:collection/collection.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/features/chat/models/message_response.dart';
import 'package:chatbee/features/chat/models/media_metadata.dart';
import 'package:chatbee/features/chat/models/message_type.dart';
import 'package:chatbee/features/chat/repos/chat_repo.dart';
import 'package:chatbee/features/chat/controllers/chat_list_controller.dart';
import 'package:chatbee/features/auth/controllers/auth_controller.dart';
import 'package:chatbee/core/services/cloudinary_service.dart';

part 'message_controller.g.dart';

/// Manages messages for a specific chat room.
///
/// Takes roomId as a family parameter. Supports:
/// - Initial load + pagination (load older)
/// - Optimistic message sending
/// - Append from WebSocket
/// - Edit/delete/reaction updates
@Riverpod(keepAlive: true)
class MessageController extends _$MessageController {
  bool _hasMore = true;
  bool _isLoadingOlder = false;

  @override
  FutureOr<List<MessageResponse>> build(String roomId) async {
    final result = await ref.read(chatRepoProvider).getMessages(roomId: roomId);

    _hasMore = result.$2;
    final messages = result.$1;

    return messages;
  }

  /// Mark the room as read (called when screen opens)
  void markAsRead() {
    ref.read(chatRepoProvider).markRoomAsRead(roomId);
  }

  /// Fetch the latest messages from API and merge with current state.
  /// Unlike build() which replaces state, this appends any messages
  /// not already present. Safe to call on resume with no loading flash.
  Future<void> silentRefresh() async {
    final current = state.valueOrNull;
    if (current == null) return;

    try {
      final result = await ref.read(chatRepoProvider).getMessages(roomId: roomId);
      final fetched = result.$1;
      
      // Merge: keep all existing, append any fetched messages not already present
      final existingIds = current.map((m) => m.id).toSet();
      final newMessages = fetched.where((m) => !existingIds.contains(m.id)).toList();
      
      if (newMessages.isNotEmpty) {
        state = AsyncValue.data([...current, ...newMessages]);
      }
    } catch (_) {
      // Silent — don't disturb existing state on failure
    }
  }

  /// Load older messages (pagination with cursor).
  Future<void> loadOlder() async {
    if (!_hasMore || _isLoadingOlder) return;
    _isLoadingOlder = true;

    try {
      final current = state.valueOrNull ?? [];
      if (current.isEmpty) {
        _isLoadingOlder = false;
        return;
      }

      // current list is chronological [oldest, ..., newest]
      // fetch messages older than the currently oldest message
      final result = await ref
          .read(chatRepoProvider)
          .getMessages(roomId: roomId, before: current.first.id);

      _hasMore = result.$2;
      final older = result.$1;

      // Prepend, deduplicating in case a WS message arrived between the fetch
      // and now (identical ID would appear in both `older` and `current`).
      final existingIds = current.map((m) => m.id).toSet();
      final uniqueOlder = older.where((m) => !existingIds.contains(m.id)).toList();
      state = AsyncValue.data([...uniqueOlder, ...current]);
    } finally {
      _isLoadingOlder = false;
    }
  }

  /// Send a text message (or explicitly typed message like GIF).
  Future<void> sendMessage(
    String content, {
    String? replyToId,
    MessageType type = MessageType.text,
    MediaMetadata? metadata,
  }) async {
    final current = state.valueOrNull ?? [];
    final currentUserId =
        ref.read(authControllerProvider).valueOrNull?.id ?? '';

    // Optimistic: add a temporary message
    final optimistic = MessageResponse(
      id: 'temp_${DateTime.now().microsecondsSinceEpoch}',
      roomId: roomId,
      senderId: currentUserId,
      content: content,
      type: type.name,
      metadata: metadata,
      status: 'sent',
      createdAt: DateTime.now(),
    );
    state = AsyncValue.data([...current, optimistic]);

    try {
      final sent = await ref
          .read(chatRepoProvider)
          .sendMessage(
            roomId: roomId,
            content: content,
            replyToId: replyToId,
            type: type.name,
            metadata: metadata,
          );

      // Replace optimistic with real message, preserving status if it
      // already advanced (e.g. a fast room_read WS event marked it 'read'
      // before the REST response arrived with 'delivered').
      final updated = state.valueOrNull ?? [];
      final swapped = updated.map((m) {
        if (m.id == optimistic.id) {
          final preserved = _higherStatus(m.status, sent.status);
          return preserved != sent.status
              ? sent.copyWith(status: preserved)
              : sent;
        }
        return m;
      }).toList();

      // Deduplicate: a WS echo may have arrived before the REST response
      final seen = <String>{};
      state = AsyncValue.data(swapped.where((m) => seen.add(m.id)).toList());

      // Update chat list preview with sender's own message
      final preview = type == MessageType.text
          ? content
          : type.previewText(metadata?.fileName);
      ref
          .read(chatListControllerProvider.notifier)
          .updateLastMessage(roomId, lastMessage: preview);
    } catch (e, st) {
      log('[MESSAGE_CONTROLLER_DEBUG] Error sending message: $e', name: 'UI_STATE');
      if (e is FormatException) {
         log('[MESSAGE_CONTROLLER_DEBUG] FormatException details: ${e.message}', name: 'UI_STATE');
      } else {
        // Since we can't easily import DioException here without adding dio to file,
        // we use a loose check on toString to grab response data if it's a Dio error
        if (e.toString().contains('DioException')) {
          try {
            final dynamic dioErr = e;
            log('[MESSAGE_CONTROLLER_DEBUG] DioException Response: ${dioErr.response?.data}', name: 'UI_STATE');
            log('[MESSAGE_CONTROLLER_DEBUG] DioException StatusCode: ${dioErr.response?.statusCode}', name: 'UI_STATE');
          } catch (_) {}
        }
      }
      log('[MESSAGE_CONTROLLER_DEBUG] Stacktrace: $st', name: 'UI_STATE');

      // Mark optimistic message as 'failed' instead of removing it.
      // This way the user sees it didn't send instead of it mysteriously vanishing.
      final updated = state.valueOrNull ?? [];
      state = AsyncValue.data(
        updated.map((m) => m.id == optimistic.id
            ? m.copyWith(status: 'failed')
            : m).toList(),
      );
      // Don't rethrow — the error is logged and the UI shows the failed message.
      // Rethrowing would cause a snackbar AND the message stays, which is redundant.
    }
  }

  /// Send a media message.
  ///
  /// 1. Shows optimistic placeholder with local file path for preview
  /// 2. Uploads to Cloudinary
  /// 3. Sends the URL to backend
  /// 4. Replaces optimistic with server response
  Future<void> sendMediaMessage({
    required String filePath,
    required String fileName,
    required MessageType messageType,
    String? mimeType,
    int? fileSize,
    String? replyToId,
  }) async {
    final currentUserId =
        ref.read(authControllerProvider).valueOrNull?.id ?? '';
    final current = state.valueOrNull ?? [];

    // Step 0: Validation
    if (fileSize != null) {
      const maxImageSize = 25 * 1024 * 1024; // 25MB
      const maxVideoSize = 100 * 1024 * 1024; // 100MB
      const maxFileSize = 50 * 1024 * 1024; // 50MB

      final limit = switch (messageType) {
        MessageType.image => maxImageSize,
        MessageType.video => maxVideoSize,
        _ => maxFileSize,
      };

      if (fileSize > limit) {
        throw Exception(
          'File too large. Max size: ${limit ~/ (1024 * 1024)}MB',
        );
      }
    }

    // Step 1: Optimistic placeholder (local path as content for preview)
    final optimistic = MessageResponse(
      id: 'temp_${DateTime.now().microsecondsSinceEpoch}',
      roomId: roomId,
      senderId: currentUserId,
      type: messageType.name,
      content: filePath, // local path for optimistic preview
      metadata: MediaMetadata(
        fileName: fileName,
        mimeType: mimeType,
        fileSize: fileSize,
      ),
      status: 'uploading',
      createdAt: DateTime.now(),
    );
    state = AsyncValue.data([...current, optimistic]);

    try {
      // Step 2: Upload to Cloudinary
      final uploadResult = await ref
          .read(cloudinaryServiceProvider)
          .upload(filePath: filePath);

      // Step 3: Build metadata from upload result
      String? thumbnailURL;
      if (messageType == MessageType.file) {
        thumbnailURL = CloudinaryService.generateDocumentThumbnail(
          uploadResult.secureUrl,
        );
      }

      final metadata = MediaMetadata(
        mimeType: mimeType,
        fileName: fileName,
        fileSize: uploadResult.bytes ?? fileSize,
        width: uploadResult.width,
        height: uploadResult.height,
        duration: uploadResult.duration?.toInt(),
        thumbnailURL: thumbnailURL,
      );

      // Step 4: Send URL to backend
      final sent = await ref
          .read(chatRepoProvider)
          .sendMessage(
            roomId: roomId,
            content: uploadResult.secureUrl,
            type: messageType.name,
            metadata: metadata,
            replyToId: replyToId,
          );

      // Step 5: Replace optimistic, preserving advanced status
      final updated = state.valueOrNull ?? [];
      final swapped = updated.map((m) {
        if (m.id == optimistic.id) {
          final preserved = _higherStatus(m.status, sent.status);
          return preserved != sent.status
              ? sent.copyWith(status: preserved)
              : sent;
        }
        return m;
      }).toList();
      final seen = <String>{};
      state = AsyncValue.data(swapped.where((m) => seen.add(m.id)).toList());

      // Update chat list
      final preview = messageType.previewText(fileName);
      ref
          .read(chatListControllerProvider.notifier)
          .updateLastMessage(roomId, lastMessage: preview);
    } catch (e, st) {
      log('[MESSAGE_CONTROLLER_DEBUG] Error sending media: $e', name: 'UI_STATE');
      log('[MESSAGE_CONTROLLER_DEBUG] Stacktrace: $st', name: 'UI_STATE');

      // Mark optimistic message as 'failed' so user sees it didn't send,
      // consistent with sendMessage() behavior.
      final updated = state.valueOrNull ?? [];
      state = AsyncValue.data(
        updated.map((m) => m.id == optimistic.id
            ? m.copyWith(status: 'failed')
            : m).toList(),
      );
    }
  }

  /// Append a new message from WebSocket.
  void appendMessage(MessageResponse message) {
    final current = state.valueOrNull ?? [];
    // Avoid duplicates
    if (current.any((m) => m.id == message.id)) return;
    state = AsyncValue.data([...current, message]);
  }

  /// Update a message's status (for tick progression).
  /// Guards against downgrades: sent → delivered → read only.
  void updateMessageStatus(String messageId, String status) {
    final current = state.valueOrNull;
    if (current == null) return;

    state = AsyncValue.data(
      current.map((m) {
        if (m.id == messageId) {
          // Only advance, never downgrade
          final higher = _higherStatus(m.status, status);
          if (higher == m.status) return m; // already at or above
          return m.copyWith(status: status);
        }
        return m;
      }).toList(),
    );
  }

  /// Returns whichever status is higher in the sent → delivered → read chain.
  static String _higherStatus(String a, String b) {
    const rank = {'uploading': -1, 'failed': -1, 'sent': 0, 'delivered': 1, 'read': 2};
    return (rank[a] ?? 0) >= (rank[b] ?? 0) ? a : b;
  }

  /// Mark all sent messages as "read" (batch room_read event).
  void markAllAsRead(String readByUserId) {
    final current = state.valueOrNull;
    if (current == null) return;

    state = AsyncValue.data(
      current.map((m) {
        // Only update messages NOT sent by the reader, and skip local-only states
        if (m.senderId != readByUserId &&
            m.status != 'read' &&
            m.status != 'failed' &&
            m.status != 'uploading') {
          return m.copyWith(status: 'read');
        }
        return m;
      }).toList(),
    );
  }

  /// Update a message's content (edit event).
  void editMessage(String messageId, String newContent) {
    final current = state.valueOrNull;
    if (current == null) return;

    state = AsyncValue.data(
      current.map((m) {
        if (m.id == messageId) {
          return m.copyWith(content: newContent, isEdited: true);
        }
        return m;
      }).toList(),
    );
  }

  /// Soft-delete a message.
  void deleteMessage(String messageId) {
    final current = state.valueOrNull;
    if (current == null) return;

    state = AsyncValue.data(
      current.map((m) {
        if (m.id == messageId) {
          return m.copyWith(
            content: 'This message was deleted',
            isDeleted: true,
          );
        }
        return m;
      }).toList(),
    );
  }

  /// Update a reaction on a message.
  void updateReaction(String messageId, String userId, String emoji) {
    final current = state.valueOrNull;
    if (current == null) return;

    state = AsyncValue.data(
      current.map((m) {
        if (m.id == messageId) {
          final reactions = Map<String, String>.from(m.reactions);
          if (emoji.isEmpty) {
            reactions.remove(userId);
          } else {
            reactions[userId] = emoji;
          }
          return m.copyWith(reactions: reactions);
        }
        return m;
      }).toList(),
    );
  }

  /// Edit a message remotely and locally.
  Future<void> editMessageRemote(String messageId, String newContent) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final oldMsg = current.firstWhereOrNull((m) => m.id == messageId);
    if (oldMsg == null) return;

    // Optimistically update locally
    editMessage(messageId, newContent);

    try {
      await ref
          .read(chatRepoProvider)
          .editMessage(messageId: messageId, content: newContent);
    } catch (e) {
      // Revert on failure
      final updated = state.valueOrNull ?? [];
      state = AsyncValue.data(
        updated.map((m) => m.id == messageId ? oldMsg : m).toList(),
      );
      rethrow;
    }
  }

  /// Delete a message remotely and locally.
  Future<void> deleteMessageRemote(String messageId) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final oldMsg = current.firstWhereOrNull((m) => m.id == messageId);
    if (oldMsg == null) return;

    // Optimistically update locally
    deleteMessage(messageId);

    try {
      await ref.read(chatRepoProvider).deleteMessage(messageId);
    } catch (e) {
      // Revert on failure
      final updated = state.valueOrNull ?? [];
      state = AsyncValue.data(
        updated.map((m) => m.id == messageId ? oldMsg : m).toList(),
      );
      rethrow;
    }
  }

  /// Toggle a reaction remotely and locally.
  Future<void> toggleReactionRemote(String messageId, String emoji) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final currentUserId =
        ref.read(authControllerProvider).valueOrNull?.id ?? '';
    if (currentUserId.isEmpty) return;

    final oldMsg = current.firstWhereOrNull((m) => m.id == messageId);
    if (oldMsg == null) return;

    // Check existing reaction to see if we are removing it
    final exists = oldMsg.reactions[currentUserId] == emoji;

    // Optimistically update locally
    updateReaction(messageId, currentUserId, exists ? '' : emoji);

    try {
      await ref
          .read(chatRepoProvider)
          .toggleReaction(messageId: messageId, emoji: emoji);
    } catch (e) {
      // Revert on failure
      final updated = state.valueOrNull ?? [];
      state = AsyncValue.data(
        updated.map((m) => m.id == messageId ? oldMsg : m).toList(),
      );
      rethrow;
    }
  }
}
