import 'package:chatbee/features/search/models/user_search_model.dart';
import 'package:chatbee/features/search/repos/user_search_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_search_controller.g.dart';

/// State for user search with pagination
@riverpod
class UserSearchController extends _$UserSearchController {
  static const int _limit = 20;
  String _currentQuery = '';
  int _offset = 0;
  bool _hasMore = true;
  List<UserSearchModel> _users = [];

  @override
  Future<UserSearchState> build() async {
    return const UserSearchState();
  }

  /// Search users with query
  Future<void> search(String query) async {
    _currentQuery = query;
    _offset = 0;
    _hasMore = true;
    _users = [];

    state = const AsyncValue.loading();

    try {
      final response = await ref.read(userSearchRepositoryProvider).searchUsers(
            query: query,
            limit: _limit,
            offset: _offset,
          );

      _users = response.users;
      _hasMore = response.hasMore;
      _offset = _users.length;

      state = AsyncValue.data(UserSearchState(
        users: _users,
        hasMore: _hasMore,
        isLoadingMore: false,
      ));
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  /// Load more users (pagination)
  Future<void> loadMore() async {
    if (!_hasMore || state.value?.isLoadingMore == true) return;

    final currentUsers = state.value?.users ?? [];
    state = AsyncValue.data(UserSearchState(
      users: currentUsers,
      hasMore: _hasMore,
      isLoadingMore: true,
    ));

    try {
      final response = await ref.read(userSearchRepositoryProvider).searchUsers(
            query: _currentQuery,
            limit: _limit,
            offset: _offset,
          );

      _users = [...currentUsers, ...response.users];
      _hasMore = response.hasMore;
      _offset = _users.length;

      state = AsyncValue.data(UserSearchState(
        users: _users,
        hasMore: _hasMore,
        isLoadingMore: false,
      ));
    } catch (e) {
      // Keep existing users on error
      state = AsyncValue.data(UserSearchState(
        users: currentUsers,
        hasMore: _hasMore,
        isLoadingMore: false,
        error: e.toString(),
      ));
    }
  }

  /// Send friend request to user
  Future<void> sendFriendRequest(String userId) async {
    await _updateUserConnection(userId, 'pending_sent');
    await ref.read(userSearchRepositoryProvider).sendFriendRequest(userId);
  }

  /// Accept friend request
  Future<void> acceptFriendRequest(String userId, String connectionId) async {
    await _updateUserConnection(userId, 'accepted');
    await ref.read(userSearchRepositoryProvider).acceptFriendRequest(connectionId);
  }

  /// Reject friend request
  Future<void> rejectFriendRequest(String userId, String connectionId) async {
    await _updateUserConnection(userId, 'none');
    await ref.read(userSearchRepositoryProvider).rejectFriendRequest(connectionId);
  }

  /// Cancel sent friend request
  Future<void> cancelFriendRequest(String userId, String connectionId) async {
    await _updateUserConnection(userId, 'none');
    await ref.read(userSearchRepositoryProvider).cancelFriendRequest(connectionId);
  }

  /// Unfriend / remove connection
  Future<void> removeConnection(String userId, String connectionId) async {
    await _updateUserConnection(userId, 'none');
    await ref.read(userSearchRepositoryProvider).removeConnection(connectionId);
  }

  /// Update user connection status locally
  Future<void> _updateUserConnection(String userId, String newStatus) async {
    final currentUsers = state.value?.users ?? [];
    final updatedUsers = currentUsers.map((user) {
      if (user.id == userId) {
        return user.copyWith(connectionStatus: newStatus);
      }
      return user;
    }).toList();

    state = AsyncValue.data(UserSearchState(
      users: updatedUsers,
      hasMore: _hasMore,
      isLoadingMore: false,
    ));
  }
}

/// State class for user search
class UserSearchState {
  final List<UserSearchModel> users;
  final bool hasMore;
  final bool isLoadingMore;
  final String? error;

  const UserSearchState({
    this.users = const [],
    this.hasMore = false,
    this.isLoadingMore = false,
    this.error,
  });
}
