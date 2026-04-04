import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';
import 'package:chatbee/features/feed/repos/feed_repo.dart';
import 'package:chatbee/core/providers/auth_provider.dart';
import 'package:chatbee/features/social/providers/social_events.dart';
import 'package:chatbee/features/feed/controllers/feed_controller_mixin.dart';

part 'feed_controller.g.dart';

// ── Home Feed ──

@Riverpod(keepAlive: true)
class HomeFeedController extends _$HomeFeedController with FeedControllerMixin {
  bool _hasMore = true;
  bool _isLoadingMore = false;
  String? _currentCursor;

  @override
  FutureOr<List<PoemModel>> build() async {
    ref.watch(userSessionProvider);
    _currentCursor = null;
    
    final sub = ref.read(socialEventStreamProvider).stream.listen((event) {
      updatePoemSocialState(
        event.poemId,
        isLiked: event.isLiked,
        likesCount: event.likesCount,
        isReposted: event.isReposted,
        repostsCount: event.repostsCount,
        commentsCount: event.commentsCount,
      );
    });
    ref.onDispose(() => sub.cancel());

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
class ExploreFeedController extends _$ExploreFeedController with FeedControllerMixin {
  bool _hasMore = true;
  bool _isLoadingMore = false;
  String _activeHashtag = '';
  int _currentOffset = 0;

  @override
  FutureOr<List<PoemModel>> build() async {
    ref.watch(userSessionProvider);
    _currentOffset = 0;
    
    final sub = ref.read(socialEventStreamProvider).stream.listen((event) {
      updatePoemSocialState(
        event.poemId,
        isLiked: event.isLiked,
        likesCount: event.likesCount,
        isReposted: event.isReposted,
        repostsCount: event.repostsCount,
        commentsCount: event.commentsCount,
      );
    });
    ref.onDispose(() => sub.cancel());

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
class AudioFeedController extends _$AudioFeedController with FeedControllerMixin {
  bool _hasMore = true;
  bool _isLoadingMore = false;
  String _activeHashtag = '';
  int _currentOffset = 0;

  @override
  FutureOr<List<PoemModel>> build() async {
    ref.watch(userSessionProvider);
    _currentOffset = 0;
    
    final sub = ref.read(socialEventStreamProvider).stream.listen((event) {
      updatePoemSocialState(
        event.poemId,
        isLiked: event.isLiked,
        likesCount: event.likesCount,
        isReposted: event.isReposted,
        repostsCount: event.repostsCount,
        commentsCount: event.commentsCount,
      );
    });
    ref.onDispose(() => sub.cancel());

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
