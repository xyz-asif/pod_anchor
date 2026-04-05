import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';
import 'package:chatbee/features/poems/repos/poem_repo.dart';
import 'package:chatbee/core/providers/auth_provider.dart';
import 'package:chatbee/features/social/providers/social_events.dart';

part 'poem_controller.g.dart';

/// My poems list — keepAlive so it persists across navigation
@Riverpod(keepAlive: true)
class MyPoemsController extends _$MyPoemsController {
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  FutureOr<List<PoemModel>> build() async {
    ref.watch(userSessionProvider);

    // FIX: Subscribe to social events so like/repost/comment counts
    // stay in sync when actions happen from other screens (feed, explore,
    // standalone poem view, other user's profile, etc.)
    final sub = ref.read(socialEventStreamProvider).stream.listen((event) {
      _updatePoemSocialState(event);
    });
    ref.onDispose(() => sub.cancel());

    final page = await ref.read(poemRepoProvider).getMyPoems(limit: 20);
    _hasMore = page.hasMore;
    return page.poems;
  }

  /// Apply a social event (like, repost, comment count change) to any
  /// matching poem in the list.
  void _updatePoemSocialState(SocialEvent event) {
    final current = state.valueOrNull;
    if (current == null) return;

    bool changed = false;
    final updated = current.map((p) {
      if (p.id == event.poemId) {
        changed = true;
        return p.copyWith(
          isLikedByMe: event.isLiked ?? p.isLikedByMe,
          likesCount: event.likesCount ?? p.likesCount,
          isRepostedByMe: event.isReposted ?? p.isRepostedByMe,
          repostsCount: event.repostsCount ?? p.repostsCount,
          commentsCount: event.commentsCount ?? p.commentsCount,
        );
      }
      return p;
    }).toList();

    // Only update state if something actually changed to avoid unnecessary rebuilds
    if (changed) {
      state = AsyncValue.data(updated);
    }
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() async {
      final page = await ref.read(poemRepoProvider).getMyPoems(limit: 20);
      _hasMore = page.hasMore;
      return page.poems;
    });
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore) return;
    final current = state.valueOrNull;
    if (current == null || current.isEmpty) return;

    _isLoadingMore = true;
    try {
      final page = await ref
          .read(poemRepoProvider)
          .getMyPoems(limit: 20, before: current.last.id);
      _hasMore = page.hasMore;
      state = AsyncValue.data([...current, ...page.poems]);
    } finally {
      _isLoadingMore = false;
    }
  }

  /// Add a new poem to the top of the list after creation
  void prependPoem(PoemModel poem) {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([poem, ...current]);
  }

  /// Replace a poem after editing
  void updatePoem(PoemModel updatedPoem) {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
      current.map((p) => p.id == updatedPoem.id ? updatedPoem : p).toList(),
    );
  }

  /// Remove a poem after deletion
  void removePoem(String poemId) {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(current.where((p) => p.id != poemId).toList());
  }

  bool get hasMore => _hasMore;
}
