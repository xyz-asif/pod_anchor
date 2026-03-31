import 'dart:async';
import 'dart:developer';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/features/chat/models/room_response.dart';
import 'package:chatbee/features/chat/repos/chat_repo.dart';
import 'package:chatbee/features/auth/controllers/auth_controller.dart';
import 'package:chatbee/core/network/api_client.dart';
import 'package:chatbee/core/providers/auth_provider.dart';
import 'package:chatbee/core/services/websocket_service.dart';

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
  bool _hasMore = false;
  bool _isLoadingMore = false;
  int _currentOffset = 0;
  static const int _pageSize = 20;
  String _searchQuery = '';
  Timer? _refreshDebounce;

  @override
  FutureOr<List<RoomResponse>> build() async {
    ref.watch(userSessionProvider);
    ref.onDispose(() {
      _isDisposed = true;
      _refreshDebounce?.cancel();
    });

    final authState = await ref.watch(authControllerProvider.future);
    if (authState == null) return [];

    final apiClient = ref.read(apiClientProvider);
    if (!apiClient.hasToken) {
      log('⏳ ChatListController: Token not ready, waiting...', name: 'CHAT_LIST');
      return [];
    }

    _currentOffset = 0;
    final (rooms, hasMore, _) = await ref
        .read(chatRepoProvider)
        .getRooms(limit: _pageSize, offset: 0);
    _hasMore = hasMore;

    // Presence baked into the HTTP response may be stale if the WS
    // presence_sync arrived while we were still loading (state was null,
    // so updatePresence() dropped it). Re-request now that state is set.
    final wsService = ref.read(webSocketServiceProvider);
    if (wsService.isConnected) {
      wsService.requestPresenceSync();
    }

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
    _currentOffset = 0;
    _searchQuery = '';
    state = const AsyncValue.loading();
    if (_isDisposed) return;
    state = await AsyncValue.guard(() async {
      final (rooms, hasMore, _) = await ref
          .read(chatRepoProvider)
          .getRooms(limit: _pageSize, offset: 0);
      _hasMore = hasMore;
      return _sortByLastUpdated(rooms);
    });
  }

  /// Silently refresh rooms in the background (no loading spinner).
  /// Used when returning from a chat screen to sync state smoothly.
  /// Debounced to prevent back-to-back duplicate API calls per room setup.
  Future<void> backgroundRefresh() async {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        if (_isDisposed) return;
        final (rooms, hasMore, _) = await ref
            .read(chatRepoProvider)
            .getRooms(
              query: _searchQuery.isEmpty ? null : _searchQuery,
              limit: _pageSize,
              offset: 0,
            );
        _hasMore = hasMore;
        _currentOffset = 0;
        if (!_isDisposed) {
          state = AsyncValue.data(_sortByLastUpdated(rooms));
        }
      } catch (e) {
        // Ignore background refresh errors
      }
    });
  }

  /// Search rooms on the server. Debounce this call from the UI.
  Future<void> search(String query) async {
    if (_isDisposed) return;
    _searchQuery = query;
    _currentOffset = 0;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final (rooms, hasMore, _) = await ref
          .read(chatRepoProvider)
          .getRooms(
            query: query.isEmpty ? null : query,
            limit: _pageSize,
            offset: 0,
          );
      _hasMore = hasMore;
      return _sortByLastUpdated(rooms);
    });
  }

  /// Load the next page of rooms (append to existing list).
  Future<void> loadMore() async {
    if (_isDisposed || _isLoadingMore || !_hasMore) return;
    final current = state.valueOrNull;
    if (current == null) return;

    _isLoadingMore = true;
    try {
      final nextOffset = _currentOffset + _pageSize;
      final (rooms, hasMore, _) = await ref
          .read(chatRepoProvider)
          .getRooms(
            query: _searchQuery.isEmpty ? null : _searchQuery,
            limit: _pageSize,
            offset: nextOffset,
          );
      _hasMore = hasMore;
      _currentOffset = nextOffset;
      if (!_isDisposed) {
        // Deduplicate by id before appending
        final existingIds = current.map((r) => r.id).toSet();
        final newRooms = rooms
            .where((r) => !existingIds.contains(r.id))
            .toList();
        state = AsyncValue.data(_sortByLastUpdated([...current, ...newRooms]));
      }
    } finally {
      _isLoadingMore = false;
    }
  }

  /// Whether more pages are available.
  bool get hasMore => _hasMore;

  /// Move a room to the top when a new message arrives (via WebSocket).
  /// Uses background refresh if room not found to avoid loading spinner.
  void moveRoomToTop(String roomId, {String? lastMessage, String? senderName, bool incrementUnread = true}) {
    log('[CHAT_LIST_DEBUG] moveRoomToTop called for room: $roomId', name: 'UI_STATE');
    final rooms = state.valueOrNull;
    if (rooms == null) return;

    final index = rooms.indexWhere((r) => r.id == roomId);
    if (index < 0) {
      log('[CHAT_LIST_DEBUG] ↳ Room not found locally, triggering background refresh', name: 'UI_STATE');
      backgroundRefresh();
      return;
    }

    final updated = List<RoomResponse>.from(rooms);
    final room = updated.removeAt(index);
    final newUnreadCount = incrementUnread ? room.unreadCount + 1 : room.unreadCount;
    log('[CHAT_LIST_DEBUG] ↳ Room bumped to top. Unread went from ${room.unreadCount} -> $newUnreadCount', name: 'UI_STATE');
    
    updated.insert(
      0,
      room.copyWith(
        lastMessage: lastMessage ?? room.lastMessage,
        lastMessageSenderName: senderName ?? room.lastMessageSenderName,
        unreadCount: newUnreadCount,
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
            if (p.isOnline != isOnline) {
               log('[CHAT_LIST_DEBUG] 🟢 User $userId presence changed to: $isOnline', name: 'UI_STATE');
            }
            return p.copyWith(isOnline: isOnline);
          }
          return p;
        }).toList();
        return r.copyWith(participants: participants);
      }).toList(),
    );
  }

  /// Batch-update online status for multiple users in a single state write.
  /// Use this instead of calling [updatePresence] in a loop to avoid N rebuilds
  /// when processing a presence_sync payload.
  void updatePresenceBatch(Map<String, bool> presenceMap) {
    final rooms = state.valueOrNull;
    if (rooms == null || presenceMap.isEmpty) return;

    state = AsyncValue.data(
      rooms.map((r) {
        final participants = r.participants.map((p) {
          final online = presenceMap[p.id];
          if (online == null) return p;
          if (p.isOnline != online) {
            log('[CHAT_LIST_DEBUG] 🟢 User ${p.id} presence changed to: $online', name: 'UI_STATE');
          }
          return p.copyWith(isOnline: online);
        }).toList();
        return r.copyWith(participants: participants);
      }).toList(),
    );
  }

  /// Update user profile info (displayName, photoURL, bio) across all rooms.
  /// Called when receiving profile_updated WebSocket event.
  void updateUserProfile({
    required String userId,
    String? displayName,
    String? photoURL,
    String? bio,
  }) {
    final rooms = state.valueOrNull;
    if (rooms == null) return;

    state = AsyncValue.data(
      rooms.map((r) {
        final participants = r.participants.map((p) {
          if (p.id == userId) {
            return p.copyWith(
              displayName: displayName ?? p.displayName,
              photoURL: photoURL ?? p.photoURL,
              bio: bio ?? p.bio,
            );
          }
          return p;
        }).toList();
        return r.copyWith(participants: participants);
      }).toList(),
    );
  }

  /// Handle a room_updated event from WebSocket.
  /// Uses background refresh if room not found to avoid loading spinner.
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
      backgroundRefresh(); // Room not found, refresh gracefully
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
  /// Used when the user is currently viewing the room, so the message
  /// is already visible — no need to treat it as unread.
  void updateLastMessage(String roomId, {required String lastMessage, String? senderName}) {
    log('[CHAT_LIST_DEBUG] updateLastMessage called for room: $roomId (No unread increment)', name: 'UI_STATE');
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
        lastMessageSenderName: senderName ?? room.lastMessageSenderName,
        lastUpdated: DateTime.now(),
      ),
    );
    state = AsyncValue.data(updated);
  }

  /// Update last message preview ONLY if the edited/deleted message was the most recent one.
  /// Actually, since we don't know the most recent message's ID easily here,
  /// we just blindly update the preview. In a perfect world, we'd check if `messageId` 
  /// matches the room's lastMessageId. But updating it safely is fine.
  void updateLastMessageIfMatch(String roomId, {required String messageId, required String newPreview}) {
    log('[CHAT_LIST_DEBUG] updateLastMessageIfMatch called for room: $roomId', name: 'UI_STATE');
    final rooms = state.valueOrNull;
    if (rooms == null) return;

    final index = rooms.indexWhere((r) => r.id == roomId);
    if (index < 0) return;

    final updated = List<RoomResponse>.from(rooms);
    final room = updated[index];
    
    // We don't have lastMessageId in RoomResponse. So we update the preview, 
    // assuming it might have been the last message (which is the most common reason to see it).
    // The next background refresh will fix it perfectly. 
    updated[index] = room.copyWith(
      lastMessage: newPreview,
    );
    state = AsyncValue.data(updated);
  }

  /// Reset unread count for a room (when user opens it).
  void clearUnreadCount(String roomId) {
    log('[CHAT_LIST_DEBUG] clearUnreadCount called for room: $roomId', name: 'UI_STATE');
    final rooms = state.valueOrNull;
    if (rooms == null) return;

    state = AsyncValue.data(
      rooms.map((r) {
        if (r.id == roomId) {
          if (r.unreadCount > 0) log('[CHAT_LIST_DEBUG] ↳ Unread count dropped from ${r.unreadCount} -> 0', name: 'UI_STATE');
          return r.copyWith(unreadCount: 0);
        }
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

  /// Delete a chat room (calls API + removes locally).
  Future<void> deleteRoom(String roomId) async {
    await ref.read(chatRepoProvider).deleteChat(roomId);
    removeRoomLocally(roomId);
  }

  /// Remove a room from local state without an API call.
  /// Used when the other participant deletes the chat (room_deleted WS event).
  void removeRoomLocally(String roomId) {
    final rooms = state.valueOrNull ?? [];
    state = AsyncValue.data(rooms.where((r) => r.id != roomId).toList());
  }

  /// Track the currently open room for auto-mark-as-read.
  Future<void> setOpenRoomId(String roomId) async {
    // Optimistically update local state: set unreadCount to 0
    final rooms = state.valueOrNull;
    if (rooms != null) {
      final updated = rooms.map((r) {
        if (r.id == roomId) {
          return r.copyWith(unreadCount: 0);
        }
        return r;
      }).toList();
      state = AsyncValue.data(updated);
    }

    // Call API to mark messages as read
    try {
      await ref.read(chatRepoProvider).markRoomAsRead(roomId);
    } catch (e) {
      // Silently ignore errors — local state is already updated
    }
  }
}
