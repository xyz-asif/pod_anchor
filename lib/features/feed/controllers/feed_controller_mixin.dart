import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';

/// Shared logic for all feed controllers (Home, Explore, Audio).
///
/// Provides `updatePoemSocialState`, `prependPoem`, and `updatePoemInFeed`
/// so the three controllers don't duplicate ~90% identical code.
mixin FeedControllerMixin {
  /// Must be provided by the concrete controller.
  AsyncValue<List<PoemModel>> get state;
  set state(AsyncValue<List<PoemModel>> value);

  void updatePoemSocialState(
    String poemId, {
    bool? isLiked,
    int? likesCount,
    bool? isReposted,
    int? repostsCount,
    int? commentsCount,
  }) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(current.map((p) {
      if (p.id == poemId) {
        return p.copyWith(
          isLikedByMe: isLiked ?? p.isLikedByMe,
          likesCount: likesCount ?? p.likesCount,
          isRepostedByMe: isReposted ?? p.isRepostedByMe,
          repostsCount: repostsCount ?? p.repostsCount,
          commentsCount: commentsCount ?? p.commentsCount,
        );
      } else if (p.isRepost && p.originalPoem?.id == poemId) {
        return p.copyWith(
          originalPoem: p.originalPoem!.copyWith(
            isLikedByMe: isLiked ?? p.originalPoem!.isLikedByMe,
            likesCount: likesCount ?? p.originalPoem!.likesCount,
            isRepostedByMe: isReposted ?? p.originalPoem!.isRepostedByMe,
            repostsCount: repostsCount ?? p.originalPoem!.repostsCount,
            commentsCount: commentsCount ?? p.originalPoem!.commentsCount,
          ),
        );
      }
      return p;
    }).toList());
  }

  void prependPoem(PoemModel poem) {
    final current = state.valueOrNull ?? [];
    if (current.any((p) => p.id == poem.id)) return; // Dedup
    state = AsyncValue.data([poem, ...current]);
  }

  /// Fixed: uses map to skip unnecessary rebuilds when the poem
  /// isn't in this feed while correctly updating all instances of 
  /// the poem, including inside repost wrappers (Fix 3/4).
  void updatePoemInFeed(PoemModel updatedPoem) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(current.map((p) {
      if (p.id == updatedPoem.id) {
        return updatedPoem;
      } else if (p.isRepost && p.originalPoem?.id == updatedPoem.id) {
        return p.copyWith(originalPoem: updatedPoem);
      }
      return p;
    }).toList());
  }

  /// Remove a poem from the feed list (e.g. after deletion).
  void removePoem(String poemId) {
    final current = state.valueOrNull;
    if (current == null) return;
    final filtered = current.where((p) => p.id != poemId).toList();
    if (filtered.length != current.length) {
      state = AsyncValue.data(filtered);
    }
  }
}
