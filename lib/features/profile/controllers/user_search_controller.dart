import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/features/auth/models/user_model.dart';
import 'package:chatbee/features/profile/repos/user_repo.dart';

part 'user_search_controller.g.dart';

/// Manages user search state with debounced searching and pagination.
@riverpod
class UserSearchController extends _$UserSearchController {
  @override
  FutureOr<List<UserModel>> build() => [];

  /// Search users by query. Resets results on new search.
  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(userRepoProvider).searchUsers(query: query),
    );
  }

  /// Load more results (pagination).
  Future<void> loadMore(String query) async {
    final currentList = state.valueOrNull ?? [];
    final moreUsers = await ref
        .read(userRepoProvider)
        .searchUsers(query: query, offset: currentList.length);
    state = AsyncValue.data([...currentList, ...moreUsers]);
  }
}
