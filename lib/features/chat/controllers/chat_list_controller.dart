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
/// - Sorted by lastUpdated (newest first)
@Riverpod(keepAlive: true)
class ChatListController extends _$ChatListController {
  bool _isDisposed = false;

  @override
  FutureOr<List<RoomResponse>> build() async {
    // Track disposal
    ref.onDispose(() => _isDisposed = true);
    
    final rooms = await ref.read(chatRepoProvider).getRooms();
    return _sortByLastUpdated(rooms);
  }

  /// Sort rooms by lastUpdated, newest first.
  List<RoomResponse> _sortByLastUpdated(List<RoomResponse> rooms) {
    final sorted = List<RoomResponse>.from(rooms);
    sorted.sort((a, b) {
      final aTime = a.lastUpdated ?? DateTime(2000);
      final bTime = b.lastUpdated ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });
    return sorted;
  }

  /// Refresh rooms from server.
  Future<void> refresh() async {
    if (_isDisposed) return;
    state = const AsyncValue.loading();
    if (_isDisposed) return;
    state = await AsyncValue.guard(() async {
      final rooms = await ref.read(chatRepoProvider).getRooms();
      return _sortByLastUpdated(rooms);
    });
  }

  /// Silently refresh rooms in the background (no loading spinner).
  /// Used when returning from a chat screen to sync state smoothly.
  Future<void> backgroundRefresh() async {
    try {
      final rooms = await ref.read(chatRepoProvider).getRooms();
      // Only update state if provider hasn't been disposed
      if (!_isDisposed) {
        state = AsyncValue.data(_sortByLastUpdated(rooms));
      }
    } catch (e) {
      // Ignore background refresh errors — let existing state persist
    }
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

  /// Update online status for a specific user across all rooms.
  void updatePresence(String userId, {required bool isOnline}) {
    final rooms = state.valueOrNull;
    if (rooms == null) return;

    state = AsyncValue.data(
      rooms.map((r) {
        final participants = r.participants.map((p) {
          if (p.id == userId) {
            return p.copyWith(isOnline: isOnline);
          }
          return p;
        }).toList();
        return r.copyWith(participants: participants);
      }).toList(),
    );
  }

  /// Handle a room_updated event from WebSocket.
  void handleRoomUpdated({
    required String roomId,
    required String lastMessage,
    required DateTime lastUpdated,
    required String lastSenderId,
  }) {
    final rooms = state.valueOrNull;
    if (rooms == null) return;

    final index = rooms.indexWhere((r) => r.id == roomId);
    if (index < 0) {
      refresh(); // Room not found, need full fetch
      return;
    }

    final updated = List<RoomResponse>.from(rooms);
    final room = updated.removeAt(index);

    updated.insert(
      0,
      room.copyWith(lastMessage: lastMessage, lastUpdated: lastUpdated),
    );

    // Sort just in case to maintain order
    state = AsyncValue.data(_sortByLastUpdated(updated));
  }

  /// Update last message preview without incrementing unread count.
  /// Used when the current user sends a message (no unread for self).
  void updateLastMessage(String roomId, {required String lastMessage}) {
    final rooms = state.valueOrNull;
    if (rooms == null) return;

    final index = rooms.indexWhere((r) => r.id == roomId);
    if (index < 0) return;

    final updated = List<RoomResponse>.from(rooms);
    final room = updated.removeAt(index);
    updated.insert(
      0,
      room.copyWith(
        lastMessage: lastMessage,
        lastMessageSenderName: 'You',
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
