import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/features/profile/models/public_profile_model.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';
import 'package:chatbee/features/poems/widgets/poem_grid_card.dart';
import 'package:chatbee/shared/widgets/app_snackbar.dart';
import 'package:chatbee/features/profile/controllers/other_profile_controller.dart';
import 'package:chatbee/features/poems/widgets/repost_card.dart';

class OtherProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const OtherProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<OtherProfileScreen> createState() => _OtherProfileScreenState();
}

class _OtherProfileScreenState extends ConsumerState<OtherProfileScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1) {
        ref
            .read(otherProfileControllerProvider(widget.userId).notifier)
            .loadReposts();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for errors from the controller
    ref.listen<OtherProfileState>(
      otherProfileControllerProvider(widget.userId),
      (previous, next) {
        if (next.error != null && next.error != previous?.error) {
          AppSnackbar.show(
            context,
            message: next.error!,
            type: SnackbarType.error,
          );
        }
      },
    );

    final state = ref.watch(otherProfileControllerProvider(widget.userId));

    if (state.isLoadingProfile) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (state.error != null || state.profile == null) {
      return Scaffold(
        body: Center(child: Text(state.error ?? 'Profile not found')),
      );
    }

    final profile = state.profile!;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await ref
              .read(otherProfileControllerProvider(widget.userId).notifier)
              .refresh();
          if (_tabController.index == 1) {
            await ref
                .read(otherProfileControllerProvider(widget.userId).notifier)
                .loadReposts();
          }
        },
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            // ── Cover + avatar + info ──
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover image with avatar overlapping at the bottom
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Cover
                      Container(
                        height: 180.h,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppTheme.featureBackgroundColor,
                          image: profile.coverImageURL.isNotEmpty
                              ? DecorationImage(
                                  image: CachedNetworkImageProvider(
                                    profile.coverImageURL,
                                  ),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: profile.coverImageURL.isEmpty
                            ? Center(
                                child: Icon(
                                  Icons.add_photo_alternate_rounded,
                                  size: 48.r,
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      // Gradient overlay
                      Container(
                        height: 200.h,
                        color: Colors.transparent,
                        // decoration: BoxDecoration(
                        //   gradient: LinearGradient(
                        //     begin: Alignment.topCenter,
                        //     end: Alignment.bottomCenter,
                        //     colors: [
                        //       Colors.transparent,
                        //       AppTheme.surfaceColor,
                        //     ],
                        //   ),
                        // ),
                      ),
                      // Back button & Title
                      Positioned(
                        top: 40.h,
                        left: 0,
                        right: 0,
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                context.pop();
                              },
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  '@${profile.username}',
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 48.w), // Balance for back button
                          ],
                        ),
                      ),
                      // Avatar + Stats row overlapping bottom of cover
                      Positioned(
                        left: 16.w,
                        right: 16.w,
                        bottom: -40.h,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(3.r),
                              decoration: const BoxDecoration(
                                color: AppTheme.surfaceColor,
                                shape: BoxShape.circle,
                              ),
                              child: CircleAvatar(
                                radius: 40.r,
                                backgroundColor: AppTheme.borderColor,
                                backgroundImage: profile.photoURL.isNotEmpty
                                    ? CachedNetworkImageProvider(
                                        profile.photoURL,
                                      )
                                    : null,
                                child: profile.photoURL.isEmpty
                                    ? Text(
                                        profile.displayName.isNotEmpty
                                            ? profile.displayName[0]
                                                  .toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          fontSize: 28.sp,
                                          color: Colors.white,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(top: 30.h),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    Expanded(
                                      child: _StatItem(
                                        label: 'Poems',
                                        value: state.isLoadingPoems
                                            ? profile.postsCount
                                            : state.poems
                                                  .where(
                                                    (p) =>
                                                        p.visibility ==
                                                        'public',
                                                  )
                                                  .length,
                                      ),
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          context.push(
                                            '/profile/${profile.id}/followers',
                                          );
                                        },
                                        child: _StatItem(
                                          label: 'Followers',
                                          value: profile.followersCount,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          context.push(
                                            '/profile/${profile.id}/following',
                                          );
                                        },
                                        child: _StatItem(
                                          label: 'Following',
                                          value: profile.followingCount,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Spacer for the overlapping avatar row
                  SizedBox(height: 50.h),

                  // Name, Bio, and Actions
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              profile.displayName,
                              style: TextStyle(
                                fontSize: 22.sp,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: AppTheme.textDarkColor,
                              ),
                            ),
                            if (profile.isEditor) ...[
                              SizedBox(width: 6.w),
                              Icon(
                                Icons.verified_rounded,
                                size: 18.r,
                                color: AppTheme.primaryColor,
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '@${profile.username}',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppTheme.textLightColor,
                          ),
                        ),
                        if (profile.bio.isNotEmpty) ...[
                          SizedBox(height: 10.h),
                          Text(
                            profile.bio,
                            style: TextStyle(
                              fontSize: 15.sp,
                              color: AppTheme.textDarkColor.withValues(
                                alpha: 0.8,
                              ),
                              height: 1.5,
                            ),
                          ),
                        ],
                        if (profile.externalLink.isNotEmpty) ...[
                          SizedBox(height: 8.h),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              AppSnackbar.show(
                                context,
                                message: 'Opening ${profile.externalLink}',
                                type: SnackbarType.info,
                              );
                            },
                            child: Row(
                              children: [
                                Icon(
                                  Icons.link_rounded,
                                  size: 16.r,
                                  color: AppTheme.primaryColor,
                                ),
                                SizedBox(width: 4.w),
                                Expanded(
                                  child: Text(
                                    profile.externalLink,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Follow / Chat buttons
                        if (!profile.isMe) ...[
                          SizedBox(height: 16.h),
                          Row(
                            children: [
                              Expanded(
                                child: _buildFollowButton(
                                  profile,
                                  state.isFollowLoading,
                                ),
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: _buildChatButton(state.isChatLoading),
                              ),
                            ],
                          ),
                        ],
                        SizedBox(height: 10.h),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Tab bar ──
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppTheme.primaryColor,
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: AppTheme.textMediumColor,
                  tabs: const [
                    Tab(text: 'Poems'),
                    Tab(text: 'Reposts'),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildPoemsTab(state.poems, state.isLoadingPoems),
              _buildRepostsTab(state.reposts, state.isLoadingReposts),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFollowButton(PublicProfileModel profile, bool isFollowLoading) {
    return ElevatedButton(
      onPressed: isFollowLoading
          ? null
          : () {
              HapticFeedback.mediumImpact();
              ref
                  .read(otherProfileControllerProvider(widget.userId).notifier)
                  .toggleFollow();
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: profile.isFollowedByMe
            ? AppTheme.featureBackgroundColor
            : AppTheme.primaryColor,
        foregroundColor: profile.isFollowedByMe
            ? AppTheme.textDarkColor
            : Colors.white,
        elevation: 0,
        padding: EdgeInsets.symmetric(vertical: 12.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
      child: isFollowLoading
          ? SizedBox(
              width: 16.r,
              height: 16.r,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: profile.isFollowedByMe
                    ? AppTheme.primaryColor
                    : Colors.white,
              ),
            )
          : Text(
              profile.isFollowedByMe ? 'Unfollow' : 'Follow',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
            ),
    );
  }

  Widget _buildChatButton(bool isChatLoading) {
    return OutlinedButton(
      onPressed: isChatLoading
          ? null
          : () async {
              HapticFeedback.selectionClick();
              try {
                final room = await ref
                    .read(
                      otherProfileControllerProvider(widget.userId).notifier,
                    )
                    .openChat();
                if (mounted) context.push('/chat/${room.id}');
              } catch (_) {}
            },
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: AppTheme.borderColor),
        foregroundColor: AppTheme.textDarkColor,
        padding: EdgeInsets.symmetric(vertical: 12.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
      child: isChatLoading
          ? SizedBox(
              width: 16.r,
              height: 16.r,
              child: const CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              'Message',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
            ),
    );
  }

  Widget _buildPoemsTab(List<PoemModel> poems, bool isLoading) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final publicPoems = poems.where((p) => p.visibility == 'public' && !p.isRepost).toList();
    if (publicPoems.isEmpty) {
      return Center(
        child: Text(
          'No poems yet',
          style: TextStyle(fontSize: 15.sp, color: AppTheme.textMediumColor),
        ),
      );
    }
    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 12.h,
        childAspectRatio: 0.65,
      ),
      itemCount: publicPoems.length,
      itemBuilder: (_, i) => PoemGridCard(poem: publicPoems[i]),
    );
  }

  Widget _buildRepostsTab(List<PoemModel> reposts, bool isLoading) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (reposts.isEmpty) {
      return Center(
        child: Text(
          'No reposts yet',
          style: TextStyle(fontSize: 15.sp, color: AppTheme.textMediumColor),
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: reposts.length,
      itemBuilder: (_, i) => RepostCard(repost: reposts[i]),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: AppTheme.surfaceColor, child: tabBar);
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) {
    return oldDelegate.tabBar != tabBar;
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final int value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDarkColor,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12.sp, color: AppTheme.textLightColor),
          ),
        ],
      ),
    );
  }
}
