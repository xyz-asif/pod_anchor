import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/features/chat/models/room_response.dart';
import 'package:chatbee/features/chat/repos/chat_repo.dart';

part 'chat_list_controller.g.dart';

/// Manages the chat room list state (main chat list screen).
///
/// Auto-loads rooms on build. Supports:
/// - Refresh (pull-to-refresh)
/// - Optimistic room reordering on new message
/// - Unread count updates
@Riverpod(keepAlive: true)
class ChatListController extends _$ChatListController {
  @override
  FutureOr<List<RoomResponse>> build() async {
    return ref.read(chatRepoProvider).getRooms();
  }

  /// Refresh rooms from server.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(chatRepoProvider).getRooms());
  }

  /// Move a room to the top when a new message arrives (via WebSocket).
  void moveRoomToTop(String roomId, {String? lastMessage, String? senderName}) {
    final rooms = state.valueOrNull;
    if (rooms == null) return;

    final index = rooms.indexWhere((r) => r.id == roomId);
    if (index < 0) {
      // Room not in list — refresh to get it
      refresh();
      return;
    }

    final updated = List<RoomResponse>.from(rooms);
    final room = updated.removeAt(index);
    updated.insert(
      0,
      room.copyWith(
        lastMessage: lastMessage ?? room.lastMessage,
        lastMessageSenderName: senderName ?? room.lastMessageSenderName,
        unreadCount: room.unreadCount + 1,
        lastUpdated: DateTime.now(),
      ),
    );
    state = AsyncValue.data(updated);
  }

  /// Reset unread count for a room (when user opens it).
  void clearUnreadCount(String roomId) {
    final rooms = state.valueOrNull;
    if (rooms == null) return;

    state = AsyncValue.data(
      rooms.map((r) {
        if (r.id == roomId) return r.copyWith(unreadCount: 0);
        return r;
      }).toList(),
    );
  }

  /// Add or update a room in the list.
  void upsertRoom(RoomResponse room) {
    final rooms = state.valueOrNull ?? [];
    final index = rooms.indexWhere((r) => r.id == room.id);
    if (index >= 0) {
      final updated = List<RoomResponse>.from(rooms);
      updated[index] = room;
      state = AsyncValue.data(updated);
    } else {
      state = AsyncValue.data([room, ...rooms]);
    }
  }
}
