import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/features/profile/repos/follow_repo.dart';
import 'package:chatbee/features/profile/models/public_profile_model.dart';
import 'package:chatbee/features/poems/repos/poem_repo.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';
import 'package:chatbee/features/poems/widgets/poem_grid_card.dart';
import 'package:chatbee/features/chat/repos/chat_repo.dart';
import 'package:chatbee/shared/widgets/app_snackbar.dart';
import 'package:chatbee/features/auth/controllers/auth_controller.dart';
import 'package:chatbee/features/social/repos/social_repo.dart';
import 'package:chatbee/features/poems/widgets/repost_card.dart';

class OtherProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const OtherProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<OtherProfileScreen> createState() => _OtherProfileScreenState();
}

class _OtherProfileScreenState extends ConsumerState<OtherProfileScreen>
    with TickerProviderStateMixin {
  PublicProfileModel? _profile;
  List<PoemModel> _poems = [];
  List<PoemModel> _reposts = [];
  bool _isLoadingProfile = true;
  bool _isLoadingPoems = true;
  bool _isLoadingReposts = true;
  bool _isFollowLoading = false;
  bool _isChatLoading = false;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _isLoadingReposts) {
        _loadReposts();
      }
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReposts() async {
    try {
      final page = await ref
          .read(socialRepoProvider)
          .getUserReposts(widget.userId);
      if (mounted) {
        setState(() {
          _reposts = page.poems;
          _isLoadingReposts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingReposts = false);
    }
  }

  Future<void> _load() async {
    // Load profile first — this is required
    try {
      var profile = await ref
          .read(followRepoProvider)
          .getPublicProfile(widget.userId);

      // Backend bug: sometimes followersCount is returned as 0 even when we are following.
      // If we are following them, their follower count should be at least 1.
      if (profile.isFollowedByMe && profile.followersCount == 0) {
        profile = profile.copyWith(followersCount: 1);
      }

      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoadingProfile = false;
        });
      }
      return; // Can't show anything without profile
    }

    // Load poems separately — failure here shouldn't block the profile
    try {
      final page = await ref.read(poemRepoProvider).getUserPoems(widget.userId);
      if (mounted) {
        setState(() {
          _poems = page.poems;
          _isLoadingPoems = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingPoems = false);
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (_profile == null || _isFollowLoading) return;
    setState(() => _isFollowLoading = true);
    final prevFollowing = _profile?.isFollowedByMe ?? false;
    try {
      final isNowFollowing = await ref
          .read(followRepoProvider)
          .toggleFollow(
            widget.userId,
            currentlyFollowing: prevFollowing,
          );
      setState(() {
        // Only change count if the state actually flipped
        int newCount = _profile!.followersCount;

        if (isNowFollowing && !prevFollowing) {
          newCount += 1;
        } else if (!isNowFollowing && prevFollowing) {
          newCount -= 1;
        }

        if (newCount < 0) newCount = 0;

        _profile = _profile!.copyWith(
          isFollowedByMe: isNowFollowing,
          followersCount: newCount,
        );
      });
      // Refresh active user's profile to update following count in state
      ref.read(authControllerProvider.notifier).updateFollowingCount(
            isNowFollowing && !prevFollowing
                ? 1
                : (!isNowFollowing && prevFollowing ? -1 : 0),
          );
      // Optional: still refresh to be sure
      ref.read(authControllerProvider.notifier).refreshProfile();
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: e.toString(),
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isFollowLoading = false);
    }
  }

  Future<void> _openChat() async {
    if (_isChatLoading) return;
    setState(() => _isChatLoading = true);
    try {
      // getOrCreateDirectRoom — no connection required (guard removed in Phase 2)
      final room = await ref
          .read(chatRepoProvider)
          .getOrCreateDirectRoom(widget.userId);
      if (mounted) context.push('/chat/${room.id}');
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Could not open chat',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isChatLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _profile == null) {
      return Scaffold(body: Center(child: Text(_error ?? 'Profile not found')));
    }

    final profile = _profile!;

    return Scaffold(
      body: NestedScrollView(
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
                      height: 220.h,
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
                      height: 220.h,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.3),
                            Colors.transparent,
                            AppTheme.surfaceColor.withValues(alpha: 0.8),
                            AppTheme.surfaceColor,
                          ],
                        ),
                      ),
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
                              Icons.arrow_back_ios,
                              color: Colors.white,
                            ),
                            onPressed: () => context.pop(),
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
                              radius: 45.r,
                              backgroundColor: AppTheme.borderColor,
                              backgroundImage: profile.photoURL.isNotEmpty
                                  ? CachedNetworkImageProvider(profile.photoURL)
                                  : null,
                              child: profile.photoURL.isEmpty
                                  ? Text(
                                      profile.displayName.isNotEmpty
                                          ? profile.displayName[0].toUpperCase()
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
                                  _StatItem(
                                    label: 'Poems',
                                    value: profile.postsCount,
                                  ),
                                  GestureDetector(
                                    onTap: () => context.push(
                                      '/profile/${profile.id}/followers',
                                    ),
                                    child: _StatItem(
                                      label: 'Followers',
                                      value: profile.followersCount,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => context.push(
                                      '/profile/${profile.id}/following',
                                    ),
                                    child: _StatItem(
                                      label: 'Following',
                                      value: profile.followingCount,
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

                      // Follow / Chat buttons
                      if (!profile.isMe) ...[
                        SizedBox(height: 16.h),
                        Row(
                          children: [
                            Expanded(child: _buildFollowButton(profile)),
                            SizedBox(width: 10.w),
                            Expanded(child: _buildChatButton()),
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
          children: [_buildPoemsTab(), _buildRepostsTab()],
        ),
      ),
    );
  }

  Widget _buildFollowButton(PublicProfileModel profile) {
    return ElevatedButton(
      onPressed: _isFollowLoading ? null : _toggleFollow,
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
      child: _isFollowLoading
          ? SizedBox(
              width: 16.r,
              height: 16.r,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              profile.isFollowedByMe ? 'Unfollow' : 'Follow',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
            ),
    );
  }

  Widget _buildChatButton() {
    return OutlinedButton(
      onPressed: _openChat,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: AppTheme.borderColor),
        foregroundColor: AppTheme.textDarkColor,
        padding: EdgeInsets.symmetric(vertical: 12.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
      child: _isChatLoading
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

  Widget _buildPoemsTab() {
    if (_isLoadingPoems) {
      return const Center(child: CircularProgressIndicator());
    }
    final publicPoems = _poems.where((p) => p.visibility == 'public').toList();
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

  Widget _buildRepostsTab() {
    if (_isLoadingReposts) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_reposts.isEmpty) {
      return Center(
        child: Text(
          'No reposts yet',
          style: TextStyle(fontSize: 15.sp, color: AppTheme.textMediumColor),
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _reposts.length,
      itemBuilder: (_, i) => RepostCard(repost: _reposts[i]),
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
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}

class _StatItem extends StatelessWidget {
  final String label;
  final int value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
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
    );
  }
}
