import 'dart:async';
import 'package:flutter/material.dart';
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
  final ScrollController _feedScrollController = ScrollController();
  late TabController _searchTabController;

  bool _isSearching = false;
  Timer? _searchDebounce;

  // Search results (loaded on demand)
  List<PoemModel> _poemResults = [];
  List<UserSearchResult> _userResults = [];
  bool _isSearchLoading = false;

  @override
  void initState() {
    super.initState();
    _searchTabController = TabController(length: 2, vsync: this);
    _feedScrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _feedScrollController.dispose();
    _searchTabController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (!_isSearching &&
        _feedScrollController.position.pixels >=
            _feedScrollController.position.maxScrollExtent - 300) {
      ref.read(exploreFeedControllerProvider.notifier).loadMore();
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

  Future<void> _runSearch(String query) async {
    setState(() => _isSearchLoading = true);
    try {
      final feedRepo = ref.read(feedRepoProvider);
      final poemsFuture = feedRepo.searchPoems(query);
      final usersFuture = feedRepo.searchUsers(query);
      final results = await Future.wait([poemsFuture, usersFuture]);
      if (mounted) {
        setState(() {
          _poemResults = (results[0] as PoemsPage).poems;
          _userResults = (results[1] as UserSearchPage).users;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSearchLoading = false);
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
    final exploreState = ref.watch(exploreFeedControllerProvider);
    final activeHashtag =
        ref.watch(exploreFeedControllerProvider.notifier).activeHashtag;

    return Column(
      children: [
        // ── Hashtag filter chips ──
        SizedBox(
          height: 44.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
            itemCount: kHashtagFilters.length + 1, // +1 for "All"
            separatorBuilder: (_, __) => SizedBox(width: 8.w),
            itemBuilder: (_, i) {
              final isAll = i == 0;
              final tag = isAll ? '' : kHashtagFilters[i - 1];
              final isActive =
                  isAll ? activeHashtag.isEmpty : activeHashtag == tag;
              return GestureDetector(
                onTap: () => ref
                    .read(exploreFeedControllerProvider.notifier)
                    .filterByHashtag(tag),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppTheme.primaryColor
                        : AppTheme.featureBackgroundColor,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                        color: isActive
                            ? AppTheme.primaryColor
                            : AppTheme.borderColor),
                  ),
                  child: Text(
                    isAll ? 'All' : '#${kHashtagFilters[i - 1]}',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: isActive ? Colors.white : AppTheme.textMediumColor,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // ── Feed ──
        Expanded(
          child: exploreState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: TextButton(
                onPressed: () =>
                    ref.read(exploreFeedControllerProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ),
            data: (poems) {
              if (poems.isEmpty) {
                return Center(
                  child: Text('No poems found',
                      style: TextStyle(
                          fontSize: 15.sp, color: AppTheme.textMediumColor)),
                );
              }
              return RefreshIndicator(
                onRefresh: () =>
                    ref.read(exploreFeedControllerProvider.notifier).refresh(),
                child: ListView.builder(
                  controller: _feedScrollController,
                  itemCount: poems.length,
                  itemBuilder: (_, i) => PoemCard(poem: poems[i]),
                ),
              );
            },
          ),
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
              // ── Poem results ──
              _poemResults.isEmpty
                  ? Center(
                      child: Text('No poems found',
                          style: TextStyle(
                              fontSize: 14.sp,
                              color: AppTheme.textMediumColor)))
                  : ListView.builder(
                      itemCount: _poemResults.length,
                      itemBuilder: (_, i) => PoemCard(poem: _poemResults[i]),
                    ),

              // ── People results ──
              _userResults.isEmpty
                  ? Center(
                      child: Text('No users found',
                          style: TextStyle(
                              fontSize: 14.sp,
                              color: AppTheme.textMediumColor)))
                  : ListView.builder(
                      itemCount: _userResults.length,
                      itemBuilder: (_, i) {
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
            ],
          ),
        ),
      ],
    );
  }
}
