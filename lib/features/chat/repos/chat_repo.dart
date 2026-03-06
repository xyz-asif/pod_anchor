import 'package:chatbee/core/constants/api_endpoints.dart';
import 'package:chatbee/core/network/api_client.dart';
import 'package:chatbee/features/chat/models/message_response.dart';
import 'package:chatbee/features/chat/models/room_response.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'chat_repo.g.dart';

/// Handles all chat room and message API calls.
class ChatRepo {
  final ApiClient apiClient;

  ChatRepo({required this.apiClient});

  // ── Rooms ──

  /// Get all chat rooms (sorted by lastUpdated, newest first).
  Future<List<RoomResponse>> getRooms() async {
    final response = await apiClient.get(ApiEndpoints.chatRooms);
    final list = response.data as List;
    return list
        .map((e) => RoomResponse.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get or create a 1-on-1 chat room with a user.
  /// Must be friends (accepted connection) first.
  Future<RoomResponse> getOrCreateDirectRoom(String userId) async {
    final response = await apiClient.post(ApiEndpoints.chatRoomDirect(userId));
    return RoomResponse.fromJson(response.data);
  }

  /// Mark a room as read (resets unread count, marks messages as "read").
  Future<void> markRoomAsRead(String roomId) async {
    await apiClient.post(ApiEndpoints.chatRoomRead(roomId));
  }

  // ── Messages ──

  /// Get message history for a room (paginated with cursor).
  Future<(List<MessageResponse>, bool)> getMessages({
    required String roomId,
    int limit = 50,
    String? before,
  }) async {
    final query = <String, dynamic>{'limit': limit};
    if (before != null) query['before'] = before;

    final response = await apiClient.get(
      ApiEndpoints.chatRoomMessages(roomId),
      queryParameters: query,
    );

    // New V2 format: { "messages": [...], "hasMore": true }
    final jsonDate = response.data as Map<String, dynamic>;
    final messagesList = jsonDate['messages'] as List;
    final hasMore = jsonDate['hasMore'] as bool? ?? false;

    final messages = messagesList
        .map((e) => MessageResponse.fromJson(e as Map<String, dynamic>))
        .toList();

    return (messages, hasMore);
  }

  /// Send a message in a room.
  Future<MessageResponse> sendMessage({
    required String roomId,
    required String content,
    String? replyToId,
  }) async {
    final data = <String, dynamic>{'content': content};
    if (replyToId != null) data['replyToId'] = replyToId;

    final response = await apiClient.post(
      ApiEndpoints.chatRoomMessages(roomId),
      data: data,
    );
    return MessageResponse.fromJson(response.data);
  }

  /// Update message status (delivered/read).
  Future<void> updateMessageStatus({
    required String messageId,
    required String status,
  }) async {
    await apiClient.patch(
      ApiEndpoints.messageStatus(messageId),
      data: {'status': status},
    );
  }

  /// Add/remove emoji reaction on a message.
  Future<void> toggleReaction({
    required String messageId,
    required String emoji,
  }) async {
    await apiClient.put(
      ApiEndpoints.messageReactions(messageId),
      data: {'emoji': emoji},
    );
  }

  /// Edit a message (sender only).
  Future<void> editMessage({
    required String messageId,
    required String content,
  }) async {
    await apiClient.patch(
      ApiEndpoints.messageEdit(messageId),
      data: {'content': content},
    );
  }

  /// Delete a message (soft delete, sender only).
  Future<void> deleteMessage(String messageId) async {
    await apiClient.delete(ApiEndpoints.messageDelete(messageId));
  }
}

/// Riverpod provider for ChatRepo.
@riverpod
ChatRepo chatRepo(Ref ref) {
  return ChatRepo(apiClient: ref.read(apiClientProvider));
}
