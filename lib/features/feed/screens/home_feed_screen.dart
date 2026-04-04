import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/features/feed/controllers/feed_controller.dart';
import 'package:chatbee/features/poems/widgets/poem_card.dart';
import 'package:chatbee/features/poems/widgets/repost_card.dart';

class HomeFeedScreen extends ConsumerStatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  ConsumerState<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends ConsumerState<HomeFeedScreen> {
  final ScrollController _allScrollController = ScrollController();
  final ScrollController _audioScrollController = ScrollController();
  bool _showAudioOnly = false;

  ScrollController get _activeController =>
      _showAudioOnly ? _audioScrollController : _allScrollController;

  @override
  void initState() {
    super.initState();
    _allScrollController.addListener(_onScroll);
    _audioScrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _allScrollController.dispose();
    _audioScrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_activeController.position.pixels >=
        _activeController.position.maxScrollExtent - 300) {
      if (_showAudioOnly) {
        ref.read(audioFeedControllerProvider.notifier).loadMore();
      } else {
        ref.read(homeFeedControllerProvider.notifier).loadMore();
      }
    }
  }

  Future<void> _refresh() {
    if (_showAudioOnly) {
      return ref.read(audioFeedControllerProvider.notifier).refresh();
    }
    return ref.read(homeFeedControllerProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ChatBee',
            style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDarkColor)),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.notifications_outlined,
              size: 26.r,
              color: AppTheme.textDarkColor,
            ),
            onPressed: () => context.push('/notifications'),
          ),
          SizedBox(width: 4.w),
        ],
      ),
      body: Column(
        children: [
          // ── Toggles ──
          SizedBox(
            height: 48.h,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              children: [
                _buildToggleChip('All', false),
                SizedBox(width: 8.w),
                _buildToggleChip('Audio', true),
              ],
            ),
          ),
          
          Expanded(
            child: Consumer(builder: (context, ref, child) {
              final state = _showAudioOnly 
                  ? ref.watch(audioFeedControllerProvider)
                  : ref.watch(homeFeedControllerProvider);
                  
              return RefreshIndicator(
                onRefresh: _refresh,
                child: state.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: constraints.maxHeight,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(e.toString(),
                                  style: TextStyle(color: Colors.red, fontSize: 14.sp)),
                              TextButton(
                                onPressed: _refresh,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  data: (poems) {
                    if (poems.isEmpty) {
                      return LayoutBuilder(
                        builder: (context, constraints) => SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: SizedBox(
                            height: constraints.maxHeight,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.auto_stories_rounded,
                                      size: 64.r, color: AppTheme.textLightColor),
                                  SizedBox(height: 12.h),
                                  Text(_showAudioOnly ? 'No audio poems in your feed' : 'No poems yet',
                                      style: TextStyle(
                                          fontSize: 16.sp, fontWeight: FontWeight.w600, color: AppTheme.textDarkColor)),
                                  SizedBox(height: 4.h),
                                  Text(_showAudioOnly
                                      ? 'Follow poets who record audio, or create your own'
                                      : 'Follow poets to see their work here',
                                      style: TextStyle(
                                          fontSize: 13.sp, color: AppTheme.textMediumColor)),
                                  SizedBox(height: 16.h),
                                  FilledButton.icon(
                                    onPressed: () => context.go('/explore'),
                                    icon: const Icon(Icons.explore_rounded),
                                    label: const Text('Explore Poems'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      key: PageStorageKey(_showAudioOnly ? 'audio_feed' : 'all_feed'),
                      controller: _activeController,
                      itemCount: poems.length,
                      itemBuilder: (_, i) {
                        final poem = poems[i];
                        if (poem.isRepost) {
                          return RepostCard(repost: poem);
                        }
                        return PoemCard(poem: poem);
                      },
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleChip(String label, bool isAudioToggle) {
    final isActive = _showAudioOnly == isAudioToggle;
    return GestureDetector(
      onTap: () {
        if (isActive) return;
        HapticFeedback.lightImpact();
        setState(() => _showAudioOnly = isAudioToggle);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryColor : AppTheme.featureBackgroundColor,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: isActive ? AppTheme.primaryColor : AppTheme.borderColor),
        ),
        child: Row(
          children: [
            if (isAudioToggle) ...[
              Icon(Icons.mic_rounded, size: 14.r, color: isActive ? Colors.white : AppTheme.textMediumColor),
              SizedBox(width: 4.w),
            ],
            Text(
              label,
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
  }
}
