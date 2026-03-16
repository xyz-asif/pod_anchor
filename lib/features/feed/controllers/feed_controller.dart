import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';
import 'package:chatbee/features/feed/repos/feed_repo.dart';

part 'feed_controller.g.dart';

// ── Home Feed ──

@Riverpod(keepAlive: true)
class HomeFeedController extends _$HomeFeedController {
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  FutureOr<List<PoemModel>> build() async {
    final page = await ref.read(feedRepoProvider).getHomeFeed(limit: 20);
    _hasMore = page.hasMore;
    return page.poems;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final page = await ref.read(feedRepoProvider).getHomeFeed(limit: 20);
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
      final page = await ref.read(feedRepoProvider).getHomeFeed(
            limit: 20,
            before: current.last.id,
          );
      _hasMore = page.hasMore;
      state = AsyncValue.data([...current, ...page.poems]);
    } finally {
      _isLoadingMore = false;
    }
  }

  bool get hasMore => _hasMore;
}

// ── Explore Feed ──

@Riverpod(keepAlive: true)
class ExploreFeedController extends _$ExploreFeedController {
  bool _hasMore = true;
  bool _isLoadingMore = false;
  String _activeHashtag = '';

  @override
  FutureOr<List<PoemModel>> build() async {
    final page = await ref.read(feedRepoProvider).getExploreFeed(limit: 20);
    _hasMore = page.hasMore;
    return page.poems;
  }

  Future<void> filterByHashtag(String hashtag) async {
    _activeHashtag = hashtag;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final page = await ref.read(feedRepoProvider).getExploreFeed(
            limit: 20,
            hashtag: hashtag.isEmpty ? null : hashtag,
          );
      _hasMore = page.hasMore;
      return page.poems;
    });
  }

  Future<void> refresh() async {
    _activeHashtag = '';
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final page = await ref.read(feedRepoProvider).getExploreFeed(limit: 20);
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
      final page = await ref.read(feedRepoProvider).getExploreFeed(
            limit: 20,
            before: current.last.id,
            hashtag: _activeHashtag.isEmpty ? null : _activeHashtag,
          );
      _hasMore = page.hasMore;
      state = AsyncValue.data([...current, ...page.poems]);
    } finally {
      _isLoadingMore = false;
    }
  }

  String get activeHashtag => _activeHashtag;
  bool get hasMore => _hasMore;
}
