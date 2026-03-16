import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:chatbee/features/auth/controllers/auth_controller.dart';
import 'package:chatbee/features/profile/controllers/profile_controller.dart';
import 'package:chatbee/features/poems/controllers/poem_controller.dart';
import 'package:chatbee/core/services/cloudinary_service.dart';
import 'package:chatbee/shared/widgets/app_snackbar.dart';
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/features/social/repos/social_repo.dart';
import 'package:chatbee/features/profile/repos/follow_repo.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';
import 'package:chatbee/features/poems/widgets/poem_grid_card.dart';
import 'package:chatbee/features/poems/widgets/repost_card.dart';

/// Redesigned Profile screen — Instagram-style with tabs for poems, reposts, drafts
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with TickerProviderStateMixin {
  bool _isUploadingImage = false;
  bool _isUploadingCover = false;
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _imagePicker = ImagePicker();
  late TabController _tabController;

  List<PoemModel> _reposts = [];
  bool _isLoadingReposts = true;

  // Follow counts fetched from the public profile endpoint,
  // since /users/me does not return these fields.
  int? _followersCount;
  int? _followingCount;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _isLoadingReposts) {
        _loadReposts();
      }
    });
    // Fetch accurate follow counts from the public profile endpoint
    _loadFollowCounts();
  }

  Future<void> _loadFollowCounts() async {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) return;
    try {
      final profile = await ref.read(followRepoProvider).getPublicProfile(user.id);
      if (mounted) {
        setState(() {
          _followersCount = profile.followersCount;
          _followingCount = profile.followingCount;
        });
      }
    } catch (_) {
      // Fall back to the user model counts (which may be 0)
    }
  }

  Future<void> _loadReposts() async {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) return;
    try {
      final page = await ref.read(socialRepoProvider).getUserReposts(user.id);
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

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// Pick image from gallery and upload to Cloudinary for profile photo
  Future<void> _pickAndUploadImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() => _isUploadingImage = true);

      // Upload to Cloudinary
      final cloudinaryService = ref.read(cloudinaryServiceProvider);
      final result = await cloudinaryService.upload(
        filePath: pickedFile.path,
        folder: 'profile_photos',
      );

      // Update profile with new photo URL
      await ref
          .read(profileControllerProvider.notifier)
          .updateProfile(photoURL: result.secureUrl);

      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Profile photo updated',
          type: SnackbarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Failed to upload image: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  /// Pick image for cover photo
  Future<void> _pickAndUploadCoverImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() => _isUploadingCover = true);

      // Upload to Cloudinary
      final cloudinaryService = ref.read(cloudinaryServiceProvider);
      final result = await cloudinaryService.upload(
        filePath: pickedFile.path,
        folder: 'cover_photos',
      );

      // Update profile with new cover URL
      await ref
          .read(profileControllerProvider.notifier)
          .updateProfile(coverImageURL: result.secureUrl);

      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Cover photo updated',
          type: SnackbarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Failed to upload cover: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingCover = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Side effects
    ref.listen(profileControllerProvider, (prev, next) {
      next.whenOrNull(
        error: (e, _) => AppSnackbar.show(
          context,
          message: e.toString(),
          type: SnackbarType.error,
        ),
      );
    });

    final profileState = ref.watch(profileControllerProvider);
    final authUser = ref.watch(authControllerProvider).valueOrNull;
    final user = profileState.valueOrNull ?? authUser;

    return Scaffold(
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cover image with avatar overlapping at the bottom
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Cover photo
                          GestureDetector(
                            onTap: _isUploadingCover
                                ? null
                                : _pickAndUploadCoverImage,
                            child: Container(
                              height: 220.h,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppTheme.featureBackgroundColor,
                                image:
                                    user.coverImageURL != null &&
                                        user.coverImageURL!.isNotEmpty
                                    ? DecorationImage(
                                        image: CachedNetworkImageProvider(
                                          user.coverImageURL!,
                                        ),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child:
                                  user.coverImageURL == null ||
                                      user.coverImageURL!.isEmpty
                                  ? Center(
                                      child: Icon(
                                        Icons.add_photo_alternate_rounded,
                                        size: 48.r,
                                        color: AppTheme.primaryColor.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
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
                          // Cover photo upload indicator
                          if (_isUploadingCover)
                            Container(
                              height: 220.h,
                              color: Colors.black.withValues(alpha: 0.5),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          // Settings Button, Username Title & Edit Button
                          Positioned(
                            top: 40.h,
                            left: 0,
                            right: 0,
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.settings_rounded,
                                    color: Colors.white,
                                  ),
                                  onPressed: () =>
                                      context.push('/profile/edit'),
                                ),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      '@${user.username ?? 'username'}',
                                      style: TextStyle(
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_rounded,
                                    color: Colors.white,
                                  ),
                                  onPressed: () =>
                                      context.push('/profile/edit'),
                                ),
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
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      GestureDetector(
                                        onTap: _isUploadingImage
                                            ? null
                                            : _pickAndUploadImage,
                                        child: CircleAvatar(
                                          radius: 46.r,
                                          backgroundColor: AppTheme.borderColor,
                                          backgroundImage:
                                              user.photoURL != null &&
                                                  user.photoURL!.isNotEmpty
                                              ? CachedNetworkImageProvider(
                                                  user.photoURL!,
                                                )
                                              : null,
                                          child:
                                              user.photoURL == null ||
                                                  user.photoURL!.isEmpty
                                              ? Icon(
                                                  Icons.person_rounded,
                                                  size: 48.r,
                                                  color: AppTheme.primaryColor,
                                                )
                                              : null,
                                        ),
                                      ),
                                      if (_isUploadingImage)
                                        Container(
                                          width: 92.r,
                                          height: 92.r,
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.5,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 3,
                                            ),
                                          ),
                                        )
                                      else
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: GestureDetector(
                                            onTap: _pickAndUploadImage,
                                            child: Container(
                                              padding: EdgeInsets.all(8.r),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryColor,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 2,
                                                ),
                                              ),
                                              child: Icon(
                                                Icons.camera_alt_rounded,
                                                size: 16.r,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
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
                                          value: user.postsCount,
                                        ),
                                        GestureDetector(
                                          onTap: () => context.push(
                                            '/profile/${user.id}/followers',
                                          ),
                                          child: _StatItem(
                                            label: 'Followers',
                                            value: _followersCount ?? user.followersCount,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => context.push(
                                            '/profile/${user.id}/following',
                                          ),
                                          child: _StatItem(
                                            label: 'Following',
                                            value: _followingCount ?? user.followingCount,
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

                      // Name and Bio
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName ?? 'No name set',
                              style: TextStyle(
                                fontSize: 22.sp,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: AppTheme.textDarkColor,
                              ),
                            ),
                            Text(
                              '@${user.username ?? 'username'}',
                              style: TextStyle(
                                fontSize: 15.sp,
                                color: AppTheme.textMediumColor,
                              ),
                            ),
                            if (user.bio?.isNotEmpty ?? false) ...[
                              SizedBox(height: 10.h),
                              Text(
                                user.bio!,
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  color: AppTheme.textDarkColor.withValues(
                                    alpha: 0.8,
                                  ),
                                  height: 1.5,
                                ),
                              ),
                            ],
                            SizedBox(height: 16.h),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Tab bar
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabController,
                      indicatorColor: AppTheme.primaryColor,
                      indicatorWeight: 3,
                      labelColor: AppTheme.primaryColor,
                      unselectedLabelColor: AppTheme.textMediumColor,
                      tabs: const [
                        Tab(text: 'Poems'),
                        Tab(text: 'Reposts'),
                        Tab(text: 'Drafts'),
                      ],
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildPoemsTab(),
                  _buildRepostsTab(),
                  _buildDraftsTab(),
                ],
              ),
            ),
    );
  }

  Widget _buildPoemsTab() {
    final poemsState = ref.watch(myPoemsControllerProvider);

    return poemsState.when(
      data: (allPoems) {
        final poems = allPoems.where((p) => p.visibility == 'public').toList();
        if (poems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.edit_note_rounded,
                  size: 64.r,
                  color: AppTheme.textLightColor,
                ),
                SizedBox(height: 16.h),
                Text(
                  'No poems yet',
                  style: TextStyle(
                    fontSize: 18.sp,
                    color: AppTheme.textMediumColor,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Start writing your first poem!',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppTheme.textLightColor,
                  ),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12.w,
            mainAxisSpacing: 12.h,
            childAspectRatio: 0.65,
          ),
          itemCount: poems.length,
          itemBuilder: (context, index) {
            return PoemGridCard(poem: poems[index]);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text(
          'Error loading poems: $error',
          style: TextStyle(color: AppTheme.errorColor),
        ),
      ),
    );
  }

  Widget _buildRepostsTab() {
    if (_isLoadingReposts) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_reposts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.repeat_rounded,
              size: 64.r,
              color: AppTheme.textLightColor,
            ),
            SizedBox(height: 16.h),
            Text(
              'No reposts yet',
              style: TextStyle(
                fontSize: 18.sp,
                color: AppTheme.textMediumColor,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      itemCount: _reposts.length,
      itemBuilder: (context, index) {
        return RepostCard(repost: _reposts[index]);
      },
    );
  }

  Widget _buildDraftsTab() {
    final poemsState = ref.watch(myPoemsControllerProvider);

    return poemsState.when(
      data: (poems) {
        // Filter for private (draft) poems
        final drafts = poems
            .where((poem) => poem.visibility == 'private')
            .toList();

        if (drafts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.edit_document,
                  size: 64.r,
                  color: AppTheme.textLightColor,
                ),
                SizedBox(height: 16.h),
                Text(
                  'No drafts',
                  style: TextStyle(
                    fontSize: 18.sp,
                    color: AppTheme.textMediumColor,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Your draft poems will appear here',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppTheme.textLightColor,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: drafts.length,
          itemBuilder: (context, index) {
            final poem = drafts[index];
            return Container(
              margin: EdgeInsets.only(bottom: 12.h),
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                children: [
                  // Draft indicator
                  Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(
                      Icons.edit_document,
                      size: 20.r,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  SizedBox(width: 12.w),

                  // Poem info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          poem.title.isNotEmpty ? poem.title : 'Untitled Draft',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textDarkColor,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          poem.plainText.isNotEmpty
                              ? poem.plainText
                              : 'Empty draft...',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppTheme.textMediumColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text(
          'Error loading drafts: $error',
          style: TextStyle(color: AppTheme.errorColor),
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _SliverAppBarDelegate(this.tabBar);

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
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
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
