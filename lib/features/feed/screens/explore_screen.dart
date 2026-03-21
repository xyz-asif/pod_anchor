import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/features/feed/controllers/feed_controller.dart';
import 'package:chatbee/features/feed/repos/feed_repo.dart';
import 'package:chatbee/features/poems/widgets/poem_card.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';
import 'package:chatbee/features/profile/models/user_search_result.dart';

// Static hashtag list for filter chips
const List<String> kHashtagFilters = [
  'love',
  'grief',
  'nature',
  'nostalgia',
  'hope',
  'dark',
  'spiritual',
  'humour',
  'life',
  'longing',
];

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  // Fix 1: Separate scroll controllers for All and Audio feeds
  final ScrollController _allFeedScrollController = ScrollController();
  final ScrollController _audioFeedScrollController = ScrollController();
  late TabController _searchTabController;

  bool _isSearching = false;
  Timer? _searchDebounce;
  bool _showAudioOnly = false;

  // Search results (loaded on demand)
  List<PoemModel> _poemResults = [];
  List<UserSearchResult> _userResults = [];
  bool _isSearchLoading = false;

  // Fix 4: Search pagination state
  bool _hasMorePoemResults = true;
  bool _hasMoreUserResults = true;
  bool _isLoadingMorePoemResults = false;
  bool _isLoadingMoreUserResults = false;
  int _poemSearchOffset = 0;
  int _userSearchOffset = 0;
  String _lastSearchQuery = '';

  ScrollController get _activeFeedController =>
      _showAudioOnly ? _audioFeedScrollController : _allFeedScrollController;

  @override
  void initState() {
    super.initState();
    _searchTabController = TabController(length: 2, vsync: this);
    _allFeedScrollController.addListener(_onFeedScroll);
    _audioFeedScrollController.addListener(_onFeedScroll);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _allFeedScrollController.dispose();
    _audioFeedScrollController.dispose();
    _searchTabController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onFeedScroll() {
    if (!_isSearching &&
        _activeFeedController.position.pixels >=
            _activeFeedController.position.maxScrollExtent - 300) {
      if (_showAudioOnly) {
        ref.read(audioFeedControllerProvider.notifier).loadMore();
      } else {
        ref.read(exploreFeedControllerProvider.notifier).loadMore();
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    setState(() {
      _isSearching = query.isNotEmpty;
    });

    if (query.isEmpty) {
      setState(() {
        _poemResults = [];
        _userResults = [];
      });
      return;
    }

    _searchDebounce?.cancel();
    _searchDebounce =
        Timer(const Duration(milliseconds: 400), () => _runSearch(query));
  }

  // Fix 4: Modified to reset pagination state
  Future<void> _runSearch(String query) async {
    _lastSearchQuery = query;
    _poemSearchOffset = 0;
    _userSearchOffset = 0;
    setState(() => _isSearchLoading = true);
    try {
      final feedRepo = ref.read(feedRepoProvider);
      final results = await Future.wait([
        feedRepo.searchPoems(query, limit: 20, offset: 0),
        feedRepo.searchUsers(query, limit: 20, offset: 0),
      ]);
      if (mounted && _lastSearchQuery == query) {
        setState(() {
          _poemResults = (results[0] as PoemsPage).poems;
          _userResults = (results[1] as UserSearchPage).users;
          _hasMorePoemResults = (results[0] as PoemsPage).hasMore;
          _hasMoreUserResults = (results[1] as UserSearchPage).hasMore;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSearchLoading = false);
    }
  }

  // Fix 4: Load more poem search results
  Future<void> _loadMorePoemResults() async {
    if (!_hasMorePoemResults || _isLoadingMorePoemResults) return;
    _isLoadingMorePoemResults = true;
    _poemSearchOffset += 20;
    try {
      final page = await ref.read(feedRepoProvider).searchPoems(
        _lastSearchQuery,
        limit: 20,
        offset: _poemSearchOffset,
      );
      if (mounted) {
        setState(() {
          _poemResults = [..._poemResults, ...page.poems];
          _hasMorePoemResults = page.hasMore;
        });
      }
    } finally {
      _isLoadingMorePoemResults = false;
    }
  }

  // Fix 4: Load more user search results
  Future<void> _loadMoreUserResults() async {
    if (!_hasMoreUserResults || _isLoadingMoreUserResults) return;
    _isLoadingMoreUserResults = true;
    _userSearchOffset += 20;
    try {
      final page = await ref.read(feedRepoProvider).searchUsers(
        _lastSearchQuery,
        limit: 20,
        offset: _userSearchOffset,
      );
      if (mounted) {
        setState(() {
          _userResults = [..._userResults, ...page.users];
          _hasMoreUserResults = page.hasMore;
        });
      }
    } finally {
      _isLoadingMoreUserResults = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _buildSearchBar(),
        titleSpacing: 0,
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: _isSearching ? _buildSearchResults() : _buildFeed(),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: TextField(
        controller: _searchController,
        style: TextStyle(fontSize: 15.sp, color: AppTheme.textDarkColor),
        decoration: InputDecoration(
          hintText: 'Search poems or poets...',
          hintStyle: TextStyle(fontSize: 15.sp, color: AppTheme.textLightColor),
          prefixIcon: Icon(Icons.search_rounded,
              size: 20.r, color: AppTheme.textMediumColor),
          suffixIcon: _isSearching
              ? IconButton(
                  icon: Icon(Icons.close_rounded, size: 20.r),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _isSearching = false;
                      _poemResults = [];
                      _userResults = [];
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: AppTheme.featureBackgroundColor,
          contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16.w),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24.r),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24.r),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24.r),
              borderSide: const BorderSide(
                  color: AppTheme.primaryColor, width: 1.5)),
        ),
      ),
    );
  }

  Widget _buildFeed() {
    final activeHashtag = _showAudioOnly ? '' : ref.watch(exploreFeedControllerProvider.notifier).activeHashtag;

    return Column(
      children: [
        // ── Hashtag filter chips ──
        SizedBox(
          height: 48.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            itemCount: kHashtagFilters.length + 2, // +2 for "All" and "Audio"
            separatorBuilder: (_, __) => SizedBox(width: 8.w),
            itemBuilder: (_, i) {
              final isAll = i == 0;
              final isAudio = i == 1;
              final tag = (isAll || isAudio) ? '' : kHashtagFilters[i - 2];
              
              final isActive = isAudio 
                  ? _showAudioOnly 
                  : (!_showAudioOnly && (isAll ? activeHashtag.isEmpty : activeHashtag == tag));

              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  // Fix 5: Only call filterByHashtag if needed
                  if (isAudio) {
                    setState(() => _showAudioOnly = true);
                  } else {
                    setState(() => _showAudioOnly = false);
                    // Only refetch if the hashtag actually changed
                    final currentHashtag = ref.read(exploreFeedControllerProvider.notifier).activeHashtag;
                    if (currentHashtag != tag) {
                      ref.read(exploreFeedControllerProvider.notifier).filterByHashtag(tag);
                    }
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: isActive ? AppTheme.primaryColor : AppTheme.featureBackgroundColor,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: isActive ? AppTheme.primaryColor : AppTheme.borderColor),
                  ),
                  child: Row(
                    children: [
                      if (isAudio) ...[
                        Icon(Icons.mic_rounded, size: 14.r, color: isActive ? Colors.white : AppTheme.textMediumColor),
                        SizedBox(width: 4.w),
                      ],
                      Text(
                        isAll ? 'All' : (isAudio ? 'Audio' : '#$tag'),
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: isActive ? Colors.white : AppTheme.textMediumColor,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // ── Feed ──
        Expanded(
          child: Consumer(builder: (context, ref, child) {
            final currentState = _showAudioOnly 
                ? ref.watch(audioFeedControllerProvider)
                : ref.watch(exploreFeedControllerProvider);
                
            return currentState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: TextButton(
                  onPressed: () => _showAudioOnly 
                      ? ref.read(audioFeedControllerProvider.notifier).refresh()
                      : ref.read(exploreFeedControllerProvider.notifier).refresh(),
                  child: const Text('Retry'),
                ),
              ),
              data: (poems) {
                if (poems.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.explore_off_rounded, size: 60.r, color: AppTheme.textLightColor),
                        SizedBox(height: 12.h),
                        Text('No poems found', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: AppTheme.textDarkColor)),
                        SizedBox(height: 4.h),
                        Text('Try expanding your search or selecting "All"', style: TextStyle(fontSize: 13.sp, color: AppTheme.textMediumColor)),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => _showAudioOnly 
                      ? ref.read(audioFeedControllerProvider.notifier).refresh()
                      : ref.read(exploreFeedControllerProvider.notifier).refresh(),
                  child: ListView.builder(
                    key: PageStorageKey(_showAudioOnly ? 'explore_audio_feed' : 'explore_all_feed'),
                    controller: _activeFeedController,
                    itemCount: poems.length,
                    itemBuilder: (_, i) => PoemCard(poem: poems[i]),
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isSearchLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Search tabs
        TabBar(
          controller: _searchTabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textMediumColor,
          indicatorColor: AppTheme.primaryColor,
          tabs: [
            Tab(text: 'Poems (${_poemResults.length})'),
            Tab(text: 'People (${_userResults.length})'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _searchTabController,
            children: [
              // ── Poem results (Fix 4: with pagination) ──
              _poemResults.isEmpty
                  ? Center(
                      child: Text('No poems found',
                          style: TextStyle(
                              fontSize: 14.sp,
                              color: AppTheme.textMediumColor)))
                  : NotificationListener<ScrollNotification>(
                      onNotification: (scroll) {
                        if (scroll.metrics.pixels >=
                            scroll.metrics.maxScrollExtent - 200) {
                          _loadMorePoemResults();
                        }
                        return false;
                      },
                      child: ListView.builder(
                        itemCount: _poemResults.length +
                            (_hasMorePoemResults ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i == _poemResults.length) {
                            return Padding(
                              padding: EdgeInsets.all(16.r),
                              child: const Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                            );
                          }
                          return PoemCard(poem: _poemResults[i]);
                        },
                      ),
                    ),

              // ── People results (Fix 4: with pagination) ──
              _userResults.isEmpty
                  ? Center(
                      child: Text('No users found',
                          style: TextStyle(
                              fontSize: 14.sp,
                              color: AppTheme.textMediumColor)))
                  : NotificationListener<ScrollNotification>(
                      onNotification: (scroll) {
                        if (scroll.metrics.pixels >=
                            scroll.metrics.maxScrollExtent - 200) {
                          _loadMoreUserResults();
                        }
                        return false;
                      },
                      child: ListView.builder(
                        itemCount: _userResults.length +
                            (_hasMoreUserResults ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i == _userResults.length) {
                            return Padding(
                              padding: EdgeInsets.all(16.r),
                              child: const Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                            );
                          }
                          final user = _userResults[i];
                          return ListTile(
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16.w, vertical: 4.h),
                            onTap: () => context.push('/profile/${user.id}'),
                            leading: CircleAvatar(
                              radius: 22.r,
                              backgroundColor: AppTheme.borderColor,
                              backgroundImage: user.photoURL.isNotEmpty
                                  ? CachedNetworkImageProvider(user.photoURL)
                                  : null,
                            ),
                            title: Row(
                              children: [
                                Text(user.displayName,
                                    style: TextStyle(
                                        fontSize: 15.sp,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textDarkColor)),
                                if (user.isEditor) ...[
                                  SizedBox(width: 4.w),
                                  Icon(Icons.verified_rounded,
                                      size: 14.r, color: AppTheme.primaryColor),
                                ],
                              ],
                            ),
                            subtitle: Text('@${user.username}',
                                style: TextStyle(
                                    fontSize: 13.sp,
                                    color: AppTheme.textLightColor)),
                          );
                        },
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }
}
