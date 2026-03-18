import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';
import 'package:chatbee/features/feed/repos/feed_repo.dart';

part 'feed_controller.g.dart';

// ── Home Feed ──

@Riverpod(keepAlive: true)
class HomeFeedController extends _$HomeFeedController {
  bool _hasMore = true;
  bool _isLoadingMore = false;
  String? _currentCursor;

  @override
  FutureOr<List<PoemModel>> build() async {
    _currentCursor = null;
    final page = await ref
        .read(feedRepoProvider)
        .getHomeFeed(limit: 20, before: _currentCursor);
    _hasMore = page.hasMore;
    if (page.poems.isNotEmpty) {
      _currentCursor = page.poems.last.id;
    }
    return page.poems;
  }

  Future<void> refresh() async {
    _currentCursor = null;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final page = await ref
          .read(feedRepoProvider)
          .getHomeFeed(limit: 20, before: _currentCursor);
      _hasMore = page.hasMore;
      if (page.poems.isNotEmpty) {
        _currentCursor = page.poems.last.id;
      }
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
          .read(feedRepoProvider)
          .getHomeFeed(limit: 20, before: _currentCursor);
      _hasMore = page.hasMore;
      if (page.poems.isNotEmpty) {
        _currentCursor = page.poems.last.id;
      }
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
  int _currentOffset = 0;

  @override
  FutureOr<List<PoemModel>> build() async {
    _currentOffset = 0;
    final page = await ref
        .read(feedRepoProvider)
        .getExploreFeed(limit: 20, offset: _currentOffset);
    _hasMore = page.hasMore;
    return page.poems;
  }

  Future<void> filterByHashtag(String hashtag) async {
    _activeHashtag = hashtag;
    _currentOffset = 0;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final page = await ref
          .read(feedRepoProvider)
          .getExploreFeed(
            limit: 20,
            offset: _currentOffset,
            hashtag: hashtag.isEmpty ? null : hashtag,
          );
      _hasMore = page.hasMore;
      return page.poems;
    });
  }

  Future<void> refresh() async {
    _activeHashtag = '';
    _currentOffset = 0;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final page = await ref
          .read(feedRepoProvider)
          .getExploreFeed(limit: 20, offset: _currentOffset);
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
      _currentOffset += 20;
      final page = await ref
          .read(feedRepoProvider)
          .getExploreFeed(
            limit: 20,
            offset: _currentOffset,
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

// ── Audio Feed ──

@Riverpod(keepAlive: true)
class AudioFeedController extends _$AudioFeedController {
  bool _hasMore = true;
  bool _isLoadingMore = false;
  String _activeHashtag = '';
  int _currentOffset = 0;

  @override
  FutureOr<List<PoemModel>> build() async {
    _currentOffset = 0;
    final page = await ref
        .read(feedRepoProvider)
        .getAudioFeed(limit: 20, offset: _currentOffset);
    _hasMore = page.hasMore;
    return page.poems;
  }

  Future<void> filterByHashtag(String hashtag) async {
    _activeHashtag = hashtag;
    _currentOffset = 0;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final page = await ref
          .read(feedRepoProvider)
          .getAudioFeed(
            limit: 20,
            offset: _currentOffset,
            hashtag: hashtag.isEmpty ? null : hashtag,
          );
      _hasMore = page.hasMore;
      return page.poems;
    });
  }

  Future<void> refresh() async {
    _activeHashtag = '';
    _currentOffset = 0;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final page = await ref
          .read(feedRepoProvider)
          .getAudioFeed(limit: 20, offset: _currentOffset);
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
      _currentOffset += 20;
      final page = await ref
          .read(feedRepoProvider)
          .getAudioFeed(
            limit: 20,
            offset: _currentOffset,
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
