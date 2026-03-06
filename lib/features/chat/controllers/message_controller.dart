import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/features/chat/models/message_response.dart';
import 'package:chatbee/features/chat/repos/chat_repo.dart';
import 'package:chatbee/features/chat/controllers/chat_list_controller.dart';
import 'package:chatbee/features/auth/controllers/auth_controller.dart';

part 'message_controller.g.dart';

/// Manages messages for a specific chat room.
///
/// Takes roomId as a family parameter. Supports:
/// - Initial load + pagination (load older)
/// - Optimistic message sending
/// - Append from WebSocket
/// - Edit/delete/reaction updates
@riverpod
class MessageController extends _$MessageController {
  bool _hasMore = true;

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

  /// Load older messages (pagination with cursor).
  Future<void> loadOlder() async {
    if (!_hasMore) return;

    final current = state.valueOrNull ?? [];
    if (current.isEmpty) return;

    // current list is chronological [oldest, ..., newest]
    // fetch messages older than the currently oldest message
    final result = await ref
        .read(chatRepoProvider)
        .getMessages(roomId: roomId, before: current.first.id);

    _hasMore = result.$2;
    final older = result.$1;

    // Prepend the newly fetched older messages
    state = AsyncValue.data([...older, ...current]);
  }

  /// Send a message. Appends optimistically (pending), then replaces with server response.
  Future<void> sendMessage(String content, {String? replyToId}) async {
    final current = state.valueOrNull ?? [];
    final currentUserId =
        ref.read(authControllerProvider).valueOrNull?.id ?? '';

    // Optimistic: add a temporary message
    final optimistic = MessageResponse(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      roomId: roomId,
      senderId: currentUserId, // Use actual user ID instead of empty string
      content: content,
      status: 'sent',
      createdAt: DateTime.now(),
    );
    state = AsyncValue.data([...current, optimistic]);

    try {
      final sent = await ref
          .read(chatRepoProvider)
          .sendMessage(roomId: roomId, content: content, replyToId: replyToId);

      // Replace optimistic with real message
      final updated = state.valueOrNull ?? [];
      state = AsyncValue.data(
        updated.map((m) => m.id == optimistic.id ? sent : m).toList(),
      );

      // Update chat list preview with sender's own message
      ref
          .read(chatListControllerProvider.notifier)
          .updateLastMessage(roomId, lastMessage: content);
    } catch (e) {
      // Remove optimistic on failure
      final updated = state.valueOrNull ?? [];
      state = AsyncValue.data(
        updated.where((m) => m.id != optimistic.id).toList(),
      );
      rethrow;
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
  void updateMessageStatus(String messageId, String status) {
    final current = state.valueOrNull;
    if (current == null) return;

    state = AsyncValue.data(
      current.map((m) {
        if (m.id == messageId) return m.copyWith(status: status);
        return m;
      }).toList(),
    );
  }

  /// Mark all sent messages as "read" (batch room_read event).
  void markAllAsRead(String readByUserId) {
    final current = state.valueOrNull;
    if (current == null) return;

    state = AsyncValue.data(
      current.map((m) {
        // Only update messages NOT sent by the reader
        if (m.senderId != readByUserId && m.status != 'read') {
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
}
