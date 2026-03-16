import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/features/feed/controllers/feed_controller.dart';
import 'package:chatbee/features/poems/widgets/poem_card.dart';

class HomeFeedScreen extends ConsumerStatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  ConsumerState<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends ConsumerState<HomeFeedScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(homeFeedControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeFeedControllerProvider);

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
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(e.toString(),
                  style: TextStyle(color: Colors.red, fontSize: 14.sp)),
              TextButton(
                onPressed: () =>
                    ref.read(homeFeedControllerProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (poems) {
          if (poems.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_stories_rounded,
                      size: 64.r, color: AppTheme.textLightColor),
                  SizedBox(height: 12.h),
                  Text('No poems yet',
                      style: TextStyle(
                          fontSize: 16.sp, color: AppTheme.textMediumColor)),
                  SizedBox(height: 4.h),
                  Text('Follow poets to see their work here',
                      style: TextStyle(
                          fontSize: 13.sp, color: AppTheme.textLightColor)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(homeFeedControllerProvider.notifier).refresh(),
            child: ListView.builder(
              controller: _scrollController,
              itemCount: poems.length,
              itemBuilder: (_, i) => PoemCard(poem: poems[i]),
            ),
          );
        },
      ),
    );
  }
}
