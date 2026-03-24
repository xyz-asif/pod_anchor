import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/features/social/repos/social_repo.dart';
import 'package:chatbee/features/social/providers/social_events.dart';
import 'package:chatbee/features/poems/repos/poem_repo.dart';
import 'package:chatbee/features/poems/controllers/poem_controller.dart';
import 'package:chatbee/features/feed/controllers/feed_controller.dart';

part 'social_action_controller.g.dart';

/// Centralized controller for social actions (like, repost, delete).
///
/// Eliminates duplicated setState logic from PoemCard and other widgets.
/// After each action, emits a [SocialEvent] so all feed controllers
/// and listening widgets update automatically.
@riverpod
class SocialActionController extends _$SocialActionController {
  @override
  FutureOr<void> build() => null;

  /// Toggle like on a poem. Returns the new like state.
  Future<LikeResult> toggleLike(String poemId) async {
    final result = await ref.read(socialRepoProvider).togglePoemLike(poemId);

    // Broadcast to all feeds via event bus
    ref.read(socialEventStreamProvider).emit(
      SocialEvent(
        poemId: poemId,
        isLiked: result.liked,
        likesCount: result.likesCount,
      ),
    );

    return result;
  }

  /// Toggle repost on a poem. Returns the new repost state.
  Future<RepostResult> toggleRepost(String poemId) async {
    final result = await ref.read(socialRepoProvider).toggleRepost(poemId);

    // Broadcast to all feeds via event bus
    ref.read(socialEventStreamProvider).emit(
      SocialEvent(
        poemId: poemId,
        isReposted: result.reposted,
        repostsCount: result.repostsCount,
      ),
    );

    return result;
  }

  /// Delete a poem and remove from all feed controllers.
  Future<void> deletePoem(String poemId) async {
    await ref.read(poemRepoProvider).deletePoem(poemId);

    // Remove from all lists
    ref.read(myPoemsControllerProvider.notifier).removePoem(poemId);
    try { ref.read(homeFeedControllerProvider.notifier).removePoem(poemId); } catch (_) {}
    try { ref.read(exploreFeedControllerProvider.notifier).removePoem(poemId); } catch (_) {}
    try { ref.read(audioFeedControllerProvider.notifier).removePoem(poemId); } catch (_) {}
  }
}
