import 'package:chatbee/features/profile/models/user_search_result.dart';
import 'package:chatbee/features/profile/repos/follow_repo.dart';
import 'package:chatbee/features/auth/controllers/auth_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'follow_list_controller.g.dart';

class FollowListState {
  final List<UserSearchResult> users;
  final bool isLoading;
  final bool hasMore;
  final bool isLoadingMore;
  final String? error;
  final Set<String> loadingUserIds; // To track individual follow/unfollow loading

  const FollowListState({
    this.users = const [],
    this.isLoading = true,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.error,
    this.loadingUserIds = const {},
  });

  FollowListState copyWith({
    List<UserSearchResult>? users,
    bool? isLoading,
    bool? hasMore,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
    Set<String>? loadingUserIds,
  }) {
    return FollowListState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      loadingUserIds: loadingUserIds ?? this.loadingUserIds,
    );
  }
}

// Controller needs to know if it's followers or following, and the userId
// We can pass these via family arguments.
class FollowListArgs {
  final String userId;
  final bool isFollowers;

  const FollowListArgs({required this.userId, required this.isFollowers});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FollowListArgs &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          isFollowers == other.isFollowers;

  @override
  int get hashCode => userId.hashCode ^ isFollowers.hashCode;
}

@riverpod
class FollowListController extends _$FollowListController {
  @override
  FollowListState build(FollowListArgs args) {
    // Defer loading until after build returns initial state to avoid 
    // "uninitialized provider" error when reading/writing state.
    Future.microtask(() => _loadInitial());
    return const FollowListState();
  }

  Future<void> _loadInitial() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = ref.read(followRepoProvider);
      final page = args.isFollowers
          ? await repo.getFollowers(args.userId)
          : await repo.getFollowing(args.userId);

      state = state.copyWith(
        users: page.users,
        hasMore: page.hasMore,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.users.isEmpty) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final repo = ref.read(followRepoProvider);
      final page = args.isFollowers
          ? await repo.getFollowers(args.userId, before: state.users.last.id)
          : await repo.getFollowing(args.userId, before: state.users.last.id);

      state = state.copyWith(
        users: [...state.users, ...page.users],
        hasMore: page.hasMore,
        isLoadingMore: false,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> toggleFollow(String targetUserId) async {
    if (state.loadingUserIds.contains(targetUserId)) return;

    final userIndex = state.users.indexWhere((u) => u.id == targetUserId);
    if (userIndex == -1) return;

    final user = state.users[userIndex];
    final prevFollowing = user.isFollowing;

    // Optimistic UI
    state = state.copyWith(
      loadingUserIds: {...state.loadingUserIds, targetUserId},
    );
    _updateUser(targetUserId, !prevFollowing);

    try {
      final isNowFollowing = await ref.read(followRepoProvider).toggleFollow(targetUserId);

      // Reconcile
      _updateUser(targetUserId, isNowFollowing);
      state = state.copyWith(
        loadingUserIds: state.loadingUserIds.difference({targetUserId}),
      );

      // Update global auth state
      ref.read(authControllerProvider.notifier).updateFollowingCount(
        isNowFollowing && !prevFollowing ? 1 : (!isNowFollowing && prevFollowing ? -1 : 0),
      );
    } catch (e) {
      // Rollback
      _updateUser(targetUserId, prevFollowing);
      state = state.copyWith(
        loadingUserIds: state.loadingUserIds.difference({targetUserId}),
      );
      rethrow; // So UI can show snackbar
    }
  }

  void _updateUser(String id, bool isFollowing) {
    final newList = state.users.map((u) {
      if (u.id == id) {
        return u.copyWith(isFollowing: isFollowing);
      }
      return u;
    }).toList();
    state = state.copyWith(users: newList);
  }
}
