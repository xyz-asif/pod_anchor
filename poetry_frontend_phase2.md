# ChatBee Poetry App — Frontend Phase 2
### Flutter + Riverpod — Extends Existing Codebase

---

## Overview

This document covers:
1. Hide connections UI (do not delete files)
2. Profile edit screen
3. Self profile screen
4. Other user profile screen (with Follow + Chat buttons)
5. Poem detail screen
6. Home feed screen
7. Explore feed screen (with hashtag filters + search for poems and users)
8. New repos and controllers for follows and feed
9. Bottom navigation updates

---

## Part 1 — Hide Connections UI

### File: `lib/core/routes/app_router.dart`

Do not delete any connection feature files. Only remove the connections tab/icon from the bottom navigation bar and remove any routes that go to connection request screens. The files stay in the project but are not navigable.

If there is a "People" or "Connections" tab in the bottom nav, remove it. Do not replace it — the tab count will decrease by one.

---

## Part 2 — New API Endpoints

### File: `lib/core/constants/api_endpoints.dart`

Add to the existing `ApiEndpoints` class:

```dart
// Follow
static String userFollow(String userId) => '/users/$userId/follow';
static String userProfile(String userId) => '/users/$userId/profile';
static String userFollowers(String userId) => '/users/$userId/followers';
static String userFollowing(String userId) => '/users/$userId/following';

// Feed
static const String homeFeed = '/feed';
static const String exploreFeed = '/feed/explore';

// Search
static const String searchPoems = '/search/poems';
static const String searchUsers = '/search/users';
```

---

## Part 3 — New Models

### File: `lib/features/profile/models/public_profile_model.dart`

```dart
class PublicProfileModel {
  final String id;
  final String displayName;
  final String username;
  final String photoURL;
  final String coverImageURL;
  final String bio;
  final String externalLink;
  final bool isEditor;
  final int postsCount;
  final int followersCount;
  final int followingCount;
  final bool isFollowedByMe;
  final bool isMe;

  const PublicProfileModel({
    required this.id,
    required this.displayName,
    required this.username,
    required this.photoURL,
    this.coverImageURL = '',
    this.bio = '',
    this.externalLink = '',
    this.isEditor = false,
    this.postsCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.isFollowedByMe = false,
    this.isMe = false,
  });

  factory PublicProfileModel.fromJson(Map<String, dynamic> json) {
    return PublicProfileModel(
      id: json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      username: json['username'] as String? ?? '',
      photoURL: json['photoURL'] as String? ?? '',
      coverImageURL: json['coverImageURL'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      externalLink: json['externalLink'] as String? ?? '',
      isEditor: json['isEditor'] as bool? ?? false,
      postsCount: json['postsCount'] as int? ?? 0,
      followersCount: json['followersCount'] as int? ?? 0,
      followingCount: json['followingCount'] as int? ?? 0,
      isFollowedByMe: json['isFollowedByMe'] as bool? ?? false,
      isMe: json['isMe'] as bool? ?? false,
    );
  }

  PublicProfileModel copyWith({
    bool? isFollowedByMe,
    int? followersCount,
  }) {
    return PublicProfileModel(
      id: id,
      displayName: displayName,
      username: username,
      photoURL: photoURL,
      coverImageURL: coverImageURL,
      bio: bio,
      externalLink: externalLink,
      isEditor: isEditor,
      postsCount: postsCount,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount,
      isFollowedByMe: isFollowedByMe ?? this.isFollowedByMe,
      isMe: isMe,
    );
  }
}
```

### File: `lib/features/profile/models/user_search_result.dart`

```dart
class UserSearchResult {
  final String id;
  final String displayName;
  final String username;
  final String photoURL;
  final bool isEditor;
  final bool isFollowing;

  const UserSearchResult({
    required this.id,
    required this.displayName,
    required this.username,
    required this.photoURL,
    this.isEditor = false,
    this.isFollowing = false,
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      id: json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      username: json['username'] as String? ?? '',
      photoURL: json['photoURL'] as String? ?? '',
      isEditor: json['isEditor'] as bool? ?? false,
      isFollowing: json['isFollowing'] as bool? ?? false,
    );
  }
}

class UserSearchPage {
  final List<UserSearchResult> users;
  final bool hasMore;

  const UserSearchPage({required this.users, required this.hasMore});

  factory UserSearchPage.fromJson(Map<String, dynamic> json) {
    final list = json['users'] as List? ?? [];
    return UserSearchPage(
      users: list.map((e) => UserSearchResult.fromJson(e as Map<String, dynamic>)).toList(),
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}
```

---

## Part 4 — Follow Repo

### File: `lib/features/profile/repos/follow_repo.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/core/constants/api_endpoints.dart';
import 'package:chatbee/core/network/api_client.dart';
import 'package:chatbee/features/profile/models/public_profile_model.dart';
import 'package:chatbee/features/profile/models/user_search_result.dart';

part 'follow_repo.g.dart';

class FollowRepo {
  final ApiClient apiClient;
  FollowRepo({required this.apiClient});

  /// Toggle follow/unfollow. Returns true if now following.
  Future<bool> toggleFollow(String userId) async {
    final response = await apiClient.post(ApiEndpoints.userFollow(userId));
    final data = response.data as Map<String, dynamic>;
    return data['following'] as bool? ?? false;
  }

  /// Get another user's public profile including isFollowedByMe.
  Future<PublicProfileModel> getPublicProfile(String userId) async {
    final response = await apiClient.get(ApiEndpoints.userProfile(userId));
    return PublicProfileModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Get followers of a user.
  Future<UserSearchPage> getFollowers(String userId, {int limit = 20, String? before}) async {
    final query = <String, dynamic>{'limit': limit};
    if (before != null) query['before'] = before;
    final response = await apiClient.get(ApiEndpoints.userFollowers(userId), queryParameters: query);
    return UserSearchPage.fromJson(response.data as Map<String, dynamic>);
  }

  /// Get users that a user follows.
  Future<UserSearchPage> getFollowing(String userId, {int limit = 20, String? before}) async {
    final query = <String, dynamic>{'limit': limit};
    if (before != null) query['before'] = before;
    final response = await apiClient.get(ApiEndpoints.userFollowing(userId), queryParameters: query);
    return UserSearchPage.fromJson(response.data as Map<String, dynamic>);
  }
}

@riverpod
FollowRepo followRepo(Ref ref) {
  return FollowRepo(apiClient: ref.read(apiClientProvider));
}
```

---

## Part 5 — Feed Repo

### File: `lib/features/feed/repos/feed_repo.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/core/constants/api_endpoints.dart';
import 'package:chatbee/core/network/api_client.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';
import 'package:chatbee/features/profile/models/user_search_result.dart';

part 'feed_repo.g.dart';

class FeedRepo {
  final ApiClient apiClient;
  FeedRepo({required this.apiClient});

  Future<PoemsPage> getHomeFeed({int limit = 20, String? before}) async {
    final query = <String, dynamic>{'limit': limit};
    if (before != null) query['before'] = before;
    final response = await apiClient.get(ApiEndpoints.homeFeed, queryParameters: query);
    return PoemsPage.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PoemsPage> getExploreFeed({int limit = 20, String? before, String? hashtag}) async {
    final query = <String, dynamic>{'limit': limit};
    if (before != null) query['before'] = before;
    if (hashtag != null && hashtag.isNotEmpty) query['hashtag'] = hashtag;
    final response = await apiClient.get(ApiEndpoints.exploreFeed, queryParameters: query);
    return PoemsPage.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PoemsPage> searchPoems(String q, {int limit = 20, String? before}) async {
    final query = <String, dynamic>{'q': q, 'limit': limit};
    if (before != null) query['before'] = before;
    final response = await apiClient.get(ApiEndpoints.searchPoems, queryParameters: query);
    return PoemsPage.fromJson(response.data as Map<String, dynamic>);
  }

  Future<UserSearchPage> searchUsers(String q, {int limit = 20, int offset = 0}) async {
    final response = await apiClient.get(ApiEndpoints.searchUsers, queryParameters: {
      'q': q, 'limit': limit, 'offset': offset,
    });
    return UserSearchPage.fromJson(response.data as Map<String, dynamic>);
  }
}

@riverpod
FeedRepo feedRepo(Ref ref) {
  return FeedRepo(apiClient: ref.read(apiClientProvider));
}
```

---

## Part 6 — Feed Controllers

### File: `lib/features/feed/controllers/feed_controller.dart`

```dart
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
        limit: 20, before: current.last.id,
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
```

---

## Part 7 — Profile Edit Screen

### File: `lib/features/profile/screens/profile_edit_screen.dart`

This screen is reached by tapping the edit (pencil) icon on the self profile screen.

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/core/services/cloudinary_service.dart';
import 'package:chatbee/features/auth/controllers/auth_controller.dart';
import 'package:chatbee/features/profile/repos/profile_repo.dart';
import 'package:chatbee/shared/widgets/app_snackbar.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _linkController;

  String? _currentPhotoURL;
  String? _currentCoverURL;
  File? _newPhoto;
  File? _newCover;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).valueOrNull;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
    _linkController = TextEditingController(text: user?.externalLink ?? '');
    _currentPhotoURL = user?.photoURL;
    _currentCoverURL = user?.coverImageURL;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (picked != null) setState(() => _newPhoto = File(picked.path));
  }

  Future<void> _pickCover() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (picked != null) setState(() => _newCover = File(picked.path));
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppSnackbar.show(context, message: 'Name cannot be empty', type: SnackbarType.error);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final cloudinary = ref.read(cloudinaryServiceProvider);

      String photoURL = _currentPhotoURL ?? '';
      if (_newPhoto != null) {
        final result = await cloudinary.upload(filePath: _newPhoto!.path);
        photoURL = result.secureUrl;
      }

      String coverURL = _currentCoverURL ?? '';
      if (_newCover != null) {
        final result = await cloudinary.upload(filePath: _newCover!.path);
        coverURL = result.secureUrl;
      }

      final updatedUser = await ref.read(profileRepoProvider).setupProfile(
        displayName: name,
        bio: _bioController.text.trim(),
        externalLink: _linkController.text.trim(),
        photoURL: photoURL,
        coverImageURL: coverURL,
      );

      ref.read(authControllerProvider.notifier).updateUser(updatedUser);

      if (mounted) {
        AppSnackbar.show(context, message: 'Profile updated', type: SnackbarType.success);
        context.pop();
      }
    } catch (e) {
      if (mounted) AppSnackbar.show(context, message: e.toString(), type: SnackbarType.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile', style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600)),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 12.w),
            child: TextButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? SizedBox(width: 18.r, height: 18.r, child: const CircularProgressIndicator(strokeWidth: 2))
                  : Text('Save', style: TextStyle(fontSize: 15.sp, color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Cover image ──
            GestureDetector(
              onTap: _pickCover,
              child: Stack(
                children: [
                  Container(
                    height: 140.h,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.featureBackgroundColor,
                      image: _newCover != null
                          ? DecorationImage(image: FileImage(_newCover!), fit: BoxFit.cover)
                          : (_currentCoverURL != null && _currentCoverURL!.isNotEmpty
                              ? DecorationImage(image: NetworkImage(_currentCoverURL!), fit: BoxFit.cover)
                              : null),
                    ),
                  ),
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                        child: Icon(Icons.camera_alt, color: Colors.white, size: 20.r),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Avatar ──
            Transform.translate(
              offset: Offset(0, -40.h),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _pickPhoto,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 44.r,
                            backgroundColor: AppTheme.borderColor,
                            backgroundImage: _newPhoto != null
                                ? FileImage(_newPhoto!) as ImageProvider
                                : (_currentPhotoURL != null ? NetworkImage(_currentPhotoURL!) : null),
                            child: (_newPhoto == null && _currentPhotoURL == null)
                                ? Icon(Icons.person, size: 40.r, color: Colors.white)
                                : null,
                          ),
                          Positioned(
                            right: 0, bottom: 0,
                            child: Container(
                              padding: EdgeInsets.all(4.r),
                              decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
                              child: Icon(Icons.camera_alt, size: 14.r, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Username (read-only) ──
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Transform.translate(
                    offset: Offset(0, -28.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Username', style: TextStyle(fontSize: 12.sp, color: AppTheme.textLightColor)),
                        SizedBox(height: 4.h),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                          decoration: BoxDecoration(
                            color: AppTheme.featureBackgroundColor.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            '@${user?.username ?? ''}',
                            style: TextStyle(fontSize: 14.sp, color: AppTheme.textLightColor),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'Username cannot be changed',
                          style: TextStyle(fontSize: 11.sp, color: AppTheme.textLightColor),
                        ),
                      ],
                    ),
                  ),

                  // ── Editable fields ──
                  _buildField('Name', _nameController, 'Your name', maxLength: 50),
                  SizedBox(height: 16.h),
                  _buildField('Bio', _bioController, 'A few words about yourself...', maxLines: 3, maxLength: 200),
                  SizedBox(height: 16.h),
                  _buildField('Link', _linkController, 'https://yoursite.com', keyboardType: TextInputType.url),
                  SizedBox(height: 32.h),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12.sp, color: AppTheme.textLightColor, fontWeight: FontWeight.w500)),
        SizedBox(height: 6.h),
        TextField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          keyboardType: keyboardType,
          style: TextStyle(fontSize: 15.sp, color: AppTheme.textDarkColor),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppTheme.textLightColor),
            counterText: '',
            filled: true,
            fillColor: AppTheme.featureBackgroundColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r), borderSide: BorderSide(color: AppTheme.borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r), borderSide: BorderSide(color: AppTheme.borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r), borderSide: const BorderSide(color: AppTheme.primaryColor)),
          ),
        ),
      ],
    );
  }
}
```

---

## Part 8 — Poem Card Widget (Shared)

### File: `lib/features/poems/widgets/poem_card.dart`

This card is used in home feed, explore feed, and profile poem grids. Tapping it goes to the poem detail screen. Tapping the author avatar/name goes to that user's profile.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';

class PoemCard extends StatelessWidget {
  final PoemModel poem;
  final VoidCallback? onTap;

  const PoemCard({super.key, required this.poem, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => context.push('/poem/${poem.id}', extra: poem),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Author row ──
            GestureDetector(
              onTap: () => context.push('/profile/${poem.author.id}'),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18.r,
                    backgroundColor: AppTheme.borderColor,
                    backgroundImage: poem.author.photoURL.isNotEmpty
                        ? CachedNetworkImageProvider(poem.author.photoURL)
                        : null,
                    child: poem.author.photoURL.isEmpty
                        ? Text(poem.author.displayName.isNotEmpty ? poem.author.displayName[0].toUpperCase() : '?',
                            style: TextStyle(fontSize: 14.sp, color: Colors.white))
                        : null,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              poem.author.displayName,
                              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: AppTheme.textDarkColor),
                            ),
                            if (poem.author.isEditor) ...[
                              SizedBox(width: 4.w),
                              Icon(Icons.verified_rounded, size: 14.r, color: AppTheme.primaryColor),
                            ],
                          ],
                        ),
                        Text(
                          '@${poem.author.username}',
                          style: TextStyle(fontSize: 12.sp, color: AppTheme.textLightColor),
                        ),
                      ],
                    ),
                  ),
                  if (poem.createdAt != null)
                    Text(
                      timeago.format(poem.createdAt!, locale: 'en_short'),
                      style: TextStyle(fontSize: 11.sp, color: AppTheme.textLightColor),
                    ),
                ],
              ),
            ),

            SizedBox(height: 12.h),

            // ── Title ──
            if (poem.title.isNotEmpty && poem.title != 'Untitled Poem')
              Padding(
                padding: EdgeInsets.only(bottom: 6.h),
                child: Text(
                  poem.title,
                  style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700, color: AppTheme.textDarkColor),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // ── Poem preview (plain text, up to 6 lines) ──
            Text(
              poem.plainText,
              style: TextStyle(fontSize: 15.sp, color: AppTheme.textMediumColor, height: 1.6),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),

            SizedBox(height: 10.h),

            // ── Hashtags ──
            if (poem.hashtags.isNotEmpty)
              Wrap(
                spacing: 6.w,
                children: poem.hashtags.take(4).map((tag) => Text(
                  '#$tag',
                  style: TextStyle(fontSize: 12.sp, color: AppTheme.primaryColor),
                )).toList(),
              ),

            SizedBox(height: 10.h),

            // ── Footer: engagement + badges ──
            Row(
              children: [
                Icon(Icons.favorite_border_rounded, size: 16.r, color: AppTheme.textLightColor),
                SizedBox(width: 4.w),
                Text('${poem.likesCount}', style: TextStyle(fontSize: 13.sp, color: AppTheme.textLightColor)),
                SizedBox(width: 16.w),
                Icon(Icons.chat_bubble_outline_rounded, size: 16.r, color: AppTheme.textLightColor),
                SizedBox(width: 4.w),
                Text('${poem.commentsCount}', style: TextStyle(fontSize: 13.sp, color: AppTheme.textLightColor)),
                const Spacer(),
                if (poem.isOriginal)
                  Icon(Icons.copyright_rounded, size: 14.r, color: AppTheme.primaryColor),
                if (poem.hasAudio) ...[
                  SizedBox(width: 6.w),
                  Icon(Icons.mic_rounded, size: 14.r, color: AppTheme.textLightColor),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Part 9 — Poem Detail Screen

### File: `lib/features/poems/screens/poem_detail_screen.dart`

Tapping a poem card anywhere in the app opens this screen.

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';

class PoemDetailScreen extends ConsumerStatefulWidget {
  final PoemModel poem;

  const PoemDetailScreen({super.key, required this.poem});

  @override
  ConsumerState<PoemDetailScreen> createState() => _PoemDetailScreenState();
}

class _PoemDetailScreenState extends ConsumerState<PoemDetailScreen> {
  late QuillController _quillController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingAudio = false;

  @override
  void initState() {
    super.initState();
    try {
      final doc = Document.fromJson(jsonDecode(widget.poem.contentJson) as List);
      _quillController = QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
    } catch (_) {
      _quillController = QuillController.basic();
    }
  }

  @override
  void dispose() {
    _quillController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    if (_isPlayingAudio) {
      await _audioPlayer.stop();
      setState(() => _isPlayingAudio = false);
      return;
    }
    try {
      await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(widget.poem.audioUrl)));
      await _audioPlayer.play();
      setState(() => _isPlayingAudio = true);
      _audioPlayer.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed) {
          if (mounted) setState(() => _isPlayingAudio = false);
        }
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final poem = widget.poem;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Author row (tappable → their profile) ──
            GestureDetector(
              onTap: () => context.push('/profile/${poem.author.id}'),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22.r,
                    backgroundColor: AppTheme.borderColor,
                    backgroundImage: poem.author.photoURL.isNotEmpty
                        ? CachedNetworkImageProvider(poem.author.photoURL) as ImageProvider
                        : null,
                  ),
                  SizedBox(width: 10.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(poem.author.displayName,
                            style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600, color: AppTheme.textDarkColor)),
                        if (poem.author.isEditor) ...[
                          SizedBox(width: 4.w),
                          Icon(Icons.verified_rounded, size: 14.r, color: AppTheme.primaryColor),
                        ],
                      ]),
                      Text('@${poem.author.username}',
                          style: TextStyle(fontSize: 12.sp, color: AppTheme.textLightColor)),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 24.h),

            // ── Title ──
            if (poem.title.isNotEmpty && poem.title != 'Untitled Poem')
              Text(
                poem.title,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 26.sp,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDarkColor,
                  height: 1.3,
                ),
              ),

            SizedBox(height: 16.h),

            // ── Rich text content rendered via Quill (read-only) ──
            QuillEditor.basic(
              controller: _quillController,
              config: QuillEditorConfig(
                padding: EdgeInsets.zero,
                customStyles: DefaultStyles(
                  paragraph: DefaultTextBlockStyle(
                    GoogleFonts.lato(fontSize: 17.sp, height: 1.7, color: AppTheme.textDarkColor),
                    HorizontalSpacing(0, 0),
                    VerticalSpacing(0, 0),
                    VerticalSpacing(0, 0),
                    null,
                  ),
                ),
              ),
            ),

            SizedBox(height: 24.h),

            // ── Audio player if present ──
            if (poem.hasAudio)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: AppTheme.featureBackgroundColor,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _toggleAudio,
                      icon: Icon(
                        _isPlayingAudio ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                        size: 36.r,
                        color: AppTheme.primaryColor,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    SizedBox(width: 8.w),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Listen to this poem', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500, color: AppTheme.textDarkColor)),
                        if (poem.audioDuration > 0)
                          Text(
                            '${poem.audioDuration ~/ 60}:${(poem.audioDuration % 60).toString().padLeft(2, '0')}',
                            style: TextStyle(fontSize: 12.sp, color: AppTheme.textLightColor),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

            SizedBox(height: 16.h),

            // ── Hashtags ──
            if (poem.hashtags.isNotEmpty)
              Wrap(
                spacing: 8.w,
                runSpacing: 4.h,
                children: poem.hashtags.map((tag) => Text(
                  '#$tag',
                  style: TextStyle(fontSize: 13.sp, color: AppTheme.primaryColor),
                )).toList(),
              ),

            SizedBox(height: 20.h),

            // ── Badges ──
            Row(
              children: [
                if (poem.isOriginal) ...[
                  Icon(Icons.copyright_rounded, size: 14.r, color: AppTheme.primaryColor),
                  SizedBox(width: 4.w),
                  Text('Original work', style: TextStyle(fontSize: 12.sp, color: AppTheme.primaryColor)),
                  SizedBox(width: 16.w),
                ],
                Icon(Icons.favorite_border_rounded, size: 16.r, color: AppTheme.textLightColor),
                SizedBox(width: 4.w),
                Text('${poem.likesCount}', style: TextStyle(fontSize: 13.sp, color: AppTheme.textLightColor)),
                SizedBox(width: 16.w),
                Icon(Icons.chat_bubble_outline_rounded, size: 16.r, color: AppTheme.textLightColor),
                SizedBox(width: 4.w),
                Text('${poem.commentsCount}', style: TextStyle(fontSize: 13.sp, color: AppTheme.textLightColor)),
              ],
            ),

            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }
}
```

---

## Part 10 — Home Feed Screen

### File: `lib/features/feed/screens/home_feed_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/features/feed/controllers/feed_controller.dart';
import 'package:chatbee/features/poems/widgets/poem_card.dart';
import 'package:chatbee/shared/widgets/app_snackbar.dart';

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
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      ref.read(homeFeedControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeFeedControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Home', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700)),
        centerTitle: false,
        elevation: 0,
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(e.toString(), style: TextStyle(color: Colors.red, fontSize: 14.sp)),
              TextButton(
                onPressed: () => ref.read(homeFeedControllerProvider.notifier).refresh(),
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
                  Icon(Icons.auto_stories_rounded, size: 64.r, color: AppTheme.textLightColor),
                  SizedBox(height: 12.h),
                  Text('No poems yet', style: TextStyle(fontSize: 16.sp, color: AppTheme.textMediumColor)),
                  SizedBox(height: 4.h),
                  Text('Follow poets to see their work here', style: TextStyle(fontSize: 13.sp, color: AppTheme.textLightColor)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(homeFeedControllerProvider.notifier).refresh(),
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
```

---

## Part 11 — Explore Feed Screen

### File: `lib/features/feed/screens/explore_screen.dart`

Single screen with three states: default feed, hashtag filter active, search active. Search shows two tabs (Poems / People) automatically when the user types.

```dart
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
  'love', 'grief', 'nature', 'nostalgia', 'hope',
  'dark', 'spiritual', 'humour', 'life', 'longing',
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
  String _searchQuery = '';
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
      _searchQuery = query;
    });

    if (query.isEmpty) {
      setState(() { _poemResults = []; _userResults = []; });
      return;
    }

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () => _runSearch(query));
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
          prefixIcon: Icon(Icons.search_rounded, size: 20.r, color: AppTheme.textMediumColor),
          suffixIcon: _isSearching
              ? IconButton(
                  icon: Icon(Icons.close_rounded, size: 20.r),
                  onPressed: () {
                    _searchController.clear();
                    setState(() { _isSearching = false; _searchQuery = ''; _poemResults = []; _userResults = []; });
                  },
                )
              : null,
          filled: true,
          fillColor: AppTheme.featureBackgroundColor,
          contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16.w),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24.r), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24.r), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24.r), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5)),
        ),
      ),
    );
  }

  Widget _buildFeed() {
    final exploreState = ref.watch(exploreFeedControllerProvider);
    final activeHashtag = ref.watch(exploreFeedControllerProvider.notifier).activeHashtag;

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
              final isActive = isAll ? activeHashtag.isEmpty : activeHashtag == tag;
              return GestureDetector(
                onTap: () => ref.read(exploreFeedControllerProvider.notifier).filterByHashtag(tag),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: isActive ? AppTheme.primaryColor : AppTheme.featureBackgroundColor,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: isActive ? AppTheme.primaryColor : AppTheme.borderColor),
                  ),
                  child: Text(
                    isAll ? 'All' : '#${kHashtagFilters[i - 1]}',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: isActive ? Colors.white : AppTheme.textMediumColor,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
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
                onPressed: () => ref.read(exploreFeedControllerProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ),
            data: (poems) {
              if (poems.isEmpty) {
                return Center(
                  child: Text('No poems found', style: TextStyle(fontSize: 15.sp, color: AppTheme.textMediumColor)),
                );
              }
              return RefreshIndicator(
                onRefresh: () => ref.read(exploreFeedControllerProvider.notifier).refresh(),
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
    if (_isSearchLoading) return const Center(child: CircularProgressIndicator());

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
                  ? Center(child: Text('No poems found', style: TextStyle(fontSize: 14.sp, color: AppTheme.textMediumColor)))
                  : ListView.builder(
                      itemCount: _poemResults.length,
                      itemBuilder: (_, i) => PoemCard(poem: _poemResults[i]),
                    ),

              // ── People results ──
              _userResults.isEmpty
                  ? Center(child: Text('No users found', style: TextStyle(fontSize: 14.sp, color: AppTheme.textMediumColor)))
                  : ListView.builder(
                      itemCount: _userResults.length,
                      itemBuilder: (_, i) {
                        final user = _userResults[i];
                        return ListTile(
                          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
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
                              Text(user.displayName, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600, color: AppTheme.textDarkColor)),
                              if (user.isEditor) ...[
                                SizedBox(width: 4.w),
                                Icon(Icons.verified_rounded, size: 14.r, color: AppTheme.primaryColor),
                              ],
                            ],
                          ),
                          subtitle: Text('@${user.username}', style: TextStyle(fontSize: 13.sp, color: AppTheme.textLightColor)),
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
```

---

## Part 12 — Other User Profile Screen

### File: `lib/features/profile/screens/other_profile_screen.dart`

```dart
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
import 'package:chatbee/features/poems/widgets/poem_card.dart';
import 'package:chatbee/features/chat/repos/chat_repo.dart';
import 'package:chatbee/shared/widgets/app_snackbar.dart';

class OtherProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const OtherProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<OtherProfileScreen> createState() => _OtherProfileScreenState();
}

class _OtherProfileScreenState extends ConsumerState<OtherProfileScreen> {
  PublicProfileModel? _profile;
  List<PoemModel> _poems = [];
  bool _isLoadingProfile = true;
  bool _isLoadingPoems = true;
  bool _isFollowLoading = false;
  bool _isChatLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await ref.read(followRepoProvider).getPublicProfile(widget.userId);
      final page = await ref.read(poemRepoProvider).getUserPoems(widget.userId);
      if (mounted) {
        setState(() {
          _profile = profile;
          _poems = page.poems;
          _isLoadingProfile = false;
          _isLoadingPoems = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoadingProfile = false; });
    }
  }

  Future<void> _toggleFollow() async {
    if (_profile == null || _isFollowLoading) return;
    setState(() => _isFollowLoading = true);
    try {
      final isNowFollowing = await ref.read(followRepoProvider).toggleFollow(widget.userId);
      setState(() {
        _profile = _profile!.copyWith(
          isFollowedByMe: isNowFollowing,
          followersCount: isNowFollowing
              ? _profile!.followersCount + 1
              : _profile!.followersCount - 1,
        );
      });
    } catch (e) {
      if (mounted) AppSnackbar.show(context, message: e.toString(), type: SnackbarType.error);
    } finally {
      if (mounted) setState(() => _isFollowLoading = false);
    }
  }

  Future<void> _openChat() async {
    if (_isChatLoading) return;
    setState(() => _isChatLoading = true);
    try {
      // getOrCreateDirectRoom — no connection required (guard removed in Phase 2)
      final room = await ref.read(chatRepoProvider).getOrCreateDirectRoom(widget.userId);
      if (mounted) context.push('/chat/${room.id}');
    } catch (e) {
      if (mounted) AppSnackbar.show(context, message: 'Could not open chat', type: SnackbarType.error);
    } finally {
      if (mounted) setState(() => _isChatLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) return Scaffold(body: Center(child: Text(_error!)));

    final profile = _profile!;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Cover + avatar + info ──
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover image
                Stack(
                  children: [
                    Container(
                      height: 180.h,
                      width: double.infinity,
                      color: AppTheme.featureBackgroundColor,
                      child: profile.coverImageURL.isNotEmpty
                          ? CachedNetworkImage(imageUrl: profile.coverImageURL, fit: BoxFit.cover)
                          : null,
                    ),
                    Positioned(
                      top: 40.h,
                      left: 8.w,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                        onPressed: () => context.pop(),
                      ),
                    ),
                  ],
                ),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar + action buttons row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Transform.translate(
                            offset: Offset(0, -28.h),
                            child: CircleAvatar(
                              radius: 44.r,
                              backgroundColor: AppTheme.borderColor,
                              backgroundImage: profile.photoURL.isNotEmpty
                                  ? CachedNetworkImageProvider(profile.photoURL)
                                  : null,
                              child: profile.photoURL.isEmpty
                                  ? Text(profile.displayName.isNotEmpty ? profile.displayName[0].toUpperCase() : '?',
                                      style: TextStyle(fontSize: 28.sp, color: Colors.white))
                                  : null,
                            ),
                          ),
                          const Spacer(),
                          // Chat button — always shown
                          OutlinedButton.icon(
                            onPressed: _openChat,
                            icon: _isChatLoading
                                ? SizedBox(width: 14.r, height: 14.r, child: const CircularProgressIndicator(strokeWidth: 2))
                                : Icon(Icons.chat_bubble_outline_rounded, size: 16.r),
                            label: const Text('Chat'),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppTheme.borderColor),
                              foregroundColor: AppTheme.textDarkColor,
                              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          // Follow/Unfollow button
                          ElevatedButton(
                            onPressed: _isFollowLoading ? null : _toggleFollow,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: profile.isFollowedByMe ? AppTheme.featureBackgroundColor : AppTheme.primaryColor,
                              foregroundColor: profile.isFollowedByMe ? AppTheme.textDarkColor : Colors.white,
                              side: profile.isFollowedByMe ? BorderSide(color: AppTheme.borderColor) : BorderSide.none,
                              padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 8.h),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                              elevation: 0,
                            ),
                            child: _isFollowLoading
                                ? SizedBox(width: 14.r, height: 14.r, child: const CircularProgressIndicator(strokeWidth: 2))
                                : Text(profile.isFollowedByMe ? 'Following' : 'Follow',
                                    style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),

                      Transform.translate(
                        offset: Offset(0, -16.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name + editor badge
                            Row(
                              children: [
                                Text(profile.displayName,
                                    style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700, color: AppTheme.textDarkColor)),
                                if (profile.isEditor) ...[
                                  SizedBox(width: 6.w),
                                  Icon(Icons.verified_rounded, size: 18.r, color: AppTheme.primaryColor),
                                ],
                              ],
                            ),
                            Text('@${profile.username}',
                                style: TextStyle(fontSize: 14.sp, color: AppTheme.textLightColor)),
                            if (profile.bio.isNotEmpty) ...[
                              SizedBox(height: 8.h),
                              Text(profile.bio,
                                  style: TextStyle(fontSize: 14.sp, color: AppTheme.textMediumColor, height: 1.4)),
                            ],
                            if (profile.externalLink.isNotEmpty) ...[
                              SizedBox(height: 4.h),
                              Row(children: [
                                Icon(Icons.link_rounded, size: 14.r, color: AppTheme.primaryColor),
                                SizedBox(width: 4.w),
                                Text(profile.externalLink,
                                    style: TextStyle(fontSize: 13.sp, color: AppTheme.primaryColor)),
                              ]),
                            ],
                            SizedBox(height: 12.h),
                            // Stats row
                            Row(
                              children: [
                                _StatItem(label: 'Poems', value: profile.postsCount),
                                SizedBox(width: 20.w),
                                GestureDetector(
                                  onTap: () => context.push('/profile/${widget.userId}/followers'),
                                  child: _StatItem(label: 'Followers', value: profile.followersCount),
                                ),
                                SizedBox(width: 20.w),
                                GestureDetector(
                                  onTap: () => context.push('/profile/${widget.userId}/following'),
                                  child: _StatItem(label: 'Following', value: profile.followingCount),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Poems list ──
          _isLoadingPoems
              ? const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()))
              : _poems.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40.h),
                        child: Center(
                          child: Text('No poems yet', style: TextStyle(fontSize: 15.sp, color: AppTheme.textMediumColor)),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => PoemCard(poem: _poems[i]),
                        childCount: _poems.length,
                      ),
                    ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final int value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: AppTheme.textDarkColor)),
        Text(label, style: TextStyle(fontSize: 12.sp, color: AppTheme.textLightColor)),
      ],
    );
  }
}
```

---

## Part 13 — Router Updates

### File: `lib/core/routes/app_router.dart`

Add these routes:

```dart
GoRoute(
  path: '/poem/:id',
  builder: (context, state) {
    final poem = state.extra as PoemModel;
    return PoemDetailScreen(poem: poem);
  },
),
GoRoute(
  path: '/profile/:id',
  builder: (context, state) {
    final userId = state.pathParameters['id']!;
    return OtherProfileScreen(userId: userId);
  },
),
GoRoute(
  path: '/profile/edit',
  builder: (context, state) => const ProfileEditScreen(),
),
```

---

## Part 14 — Bottom Navigation Update

### File: wherever your bottom navigation is defined

Update the bottom navigation tabs to:
1. **Home** — `HomeFeedScreen` (icon: `Icons.home_rounded`)
2. **Explore** — `ExploreScreen` (icon: `Icons.explore_rounded`)
3. **Create** — FAB or tab that pushes to `PoetryEditorScreen` (icon: `Icons.add_rounded` or pen icon)
4. **Chats** — existing chat list (icon: `Icons.chat_bubble_rounded`)
5. **Profile** — self profile screen (icon: `Icons.person_rounded`)

Remove any Connections/People tab that previously existed.

---

## Part 15 — Run Codegen

```bash
dart run build_runner build --delete-conflicting-outputs
```

New files that generate `.g.dart` files:
- `follow_repo.dart`
- `feed_repo.dart`
- `feed_controller.dart`
- `public_profile_model.dart` (if using json_serializable — otherwise no codegen needed since it uses manual fromJson)

---

## Implementation Order for Windsurf

1. Add new API endpoints to `ApiEndpoints`
2. Create `PublicProfileModel` and `UserSearchResult` models
3. Create `FollowRepo`
4. Create `FeedRepo`
5. Create `HomeFeedController` and `ExploreFeedController`
6. Create `PoemCard` widget
7. Create `PoemDetailScreen`
8. Create `HomeFeedScreen`
9. Create `ExploreScreen`
10. Create `OtherProfileScreen`
11. Create `ProfileEditScreen`
12. Update router with new routes
13. Update bottom navigation (remove connections tab, add Home + Explore)
14. Hide connections screens from navigation
15. Run `build_runner`
