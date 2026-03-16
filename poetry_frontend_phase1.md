# ChatBee Poetry App — Frontend Phase 1
### Flutter + Riverpod — Extends Existing ChatBee Codebase

---

## Overview

This document covers exactly two flows:
1. Post-auth profile setup (profile details screen + username screen)
2. Poem CRUD — create, read, update, delete, list — including the publish bottom sheet with hashtags, copyright, and audio

Everything here extends the existing ChatBee codebase. The existing `ApiClient`, `CloudinaryService`, `AuthController`, `GoRouter`, and `AppTheme` are all reused. Do not rebuild anything that already exists.

---

## Part 1 — Update User Model

### File: `lib/features/auth/models/user_model.dart`

Add the following fields to the existing `UserModel`. Do not remove or rename any existing fields. Run `build_runner` after making this change.

```dart
// Add these fields to the existing UserModel class

final String? username;
final String? bio;
final String? externalLink;
final String? coverImageURL;
final bool isProfileSetup;
final bool isEditor;
final int postsCount;
final int followersCount;
final int followingCount;
```

Add to the constructor:
```dart
this.username,
this.bio,
this.externalLink,
this.coverImageURL,
this.isProfileSetup = false,
this.isEditor = false,
this.postsCount = 0,
this.followersCount = 0,
this.followingCount = 0,
```

Add to `fromJson`:
```dart
username: json['username'] as String?,
bio: json['bio'] as String?,
externalLink: json['externalLink'] as String?,
coverImageURL: json['coverImageURL'] as String?,
isProfileSetup: json['isProfileSetup'] as bool? ?? false,
isEditor: json['isEditor'] as bool? ?? false,
postsCount: json['postsCount'] as int? ?? 0,
followersCount: json['followersCount'] as int? ?? 0,
followingCount: json['followingCount'] as int? ?? 0,
```

Add to `copyWith`:
```dart
String? username,
String? bio,
String? externalLink,
String? coverImageURL,
bool? isProfileSetup,
bool? isEditor,
int? postsCount,
int? followersCount,
int? followingCount,
// in return:
username: username ?? this.username,
bio: bio ?? this.bio,
externalLink: externalLink ?? this.externalLink,
coverImageURL: coverImageURL ?? this.coverImageURL,
isProfileSetup: isProfileSetup ?? this.isProfileSetup,
isEditor: isEditor ?? this.isEditor,
postsCount: postsCount ?? this.postsCount,
followersCount: followersCount ?? this.followersCount,
followingCount: followingCount ?? this.followingCount,
```

---

## Part 2 — New API Endpoints in Existing ApiEndpoints

### File: `lib/core/constants/api_endpoints.dart`

Add the following to the existing `ApiEndpoints` class:

```dart
// Profile setup
static const String userSetup = '/users/setup';
static const String usernameCheck = '/users/username/check';
static const String usernameSet = '/users/username';

// Poems
static const String poems = '/poems';
static String poem(String id) => '/poems/$id';
static const String myPoems = '/poems/me';
static String userPoems(String userId) => '/poems/user/$userId';
```

---

## Part 3 — Profile Repo

### File: `lib/features/profile/repos/profile_repo.dart`

Create this file. This is a new file — not an edit to an existing file.

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/core/constants/api_endpoints.dart';
import 'package:chatbee/core/network/api_client.dart';
import 'package:chatbee/features/auth/models/user_model.dart';

part 'profile_repo.g.dart';

class CheckUsernameResult {
  final String username;
  final bool available;
  final String? reason; // "taken" | "invalid_format" | "reserved" | null

  const CheckUsernameResult({
    required this.username,
    required this.available,
    this.reason,
  });

  factory CheckUsernameResult.fromJson(Map<String, dynamic> json) {
    return CheckUsernameResult(
      username: json['username'] as String? ?? '',
      available: json['available'] as bool? ?? false,
      reason: json['reason'] as String?,
    );
  }
}

class ProfileRepo {
  final ApiClient apiClient;

  ProfileRepo({required this.apiClient});

  /// Complete profile setup after first login.
  /// Called on the first screen of the setup flow.
  Future<UserModel> setupProfile({
    required String displayName,
    required String bio,
    required String externalLink,
    required String photoURL,
    required String coverImageURL,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.userSetup,
      data: {
        'displayName': displayName,
        'bio': bio,
        'externalLink': externalLink,
        'photoURL': photoURL,
        'coverImageURL': coverImageURL,
      },
    );
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Check if a username is available.
  /// Call this debounced as the user types — do not call on every keystroke raw.
  Future<CheckUsernameResult> checkUsername(String username) async {
    final response = await apiClient.get(
      ApiEndpoints.usernameCheck,
      queryParameters: {'username': username},
    );
    return CheckUsernameResult.fromJson(response.data as Map<String, dynamic>);
  }

  /// Permanently set the username. Called once on confirm tap.
  Future<UserModel> setUsername(String username) async {
    final response = await apiClient.post(
      ApiEndpoints.usernameSet,
      data: {'username': username},
    );
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }
}

@riverpod
ProfileRepo profileRepo(Ref ref) {
  return ProfileRepo(apiClient: ref.read(apiClientProvider));
}
```

---

## Part 4 — Profile Setup Controller

### File: `lib/features/profile/controllers/profile_setup_controller.dart`

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/features/profile/repos/profile_repo.dart';
import 'package:chatbee/features/auth/controllers/auth_controller.dart';

part 'profile_setup_controller.g.dart';

// ── Username check state ──

enum UsernameCheckStatus { idle, checking, available, taken, invalidFormat, reserved, error }

class UsernameState {
  final String username;
  final UsernameCheckStatus status;

  const UsernameState({
    this.username = '',
    this.status = UsernameCheckStatus.idle,
  });

  UsernameState copyWith({String? username, UsernameCheckStatus? status}) {
    return UsernameState(
      username: username ?? this.username,
      status: status ?? this.status,
    );
  }

  /// Human-readable message to show below the username field
  String get statusMessage {
    switch (status) {
      case UsernameCheckStatus.idle:
        return '';
      case UsernameCheckStatus.checking:
        return 'Checking availability...';
      case UsernameCheckStatus.available:
        return '@$username is available ✓';
      case UsernameCheckStatus.taken:
        return 'This username is already taken';
      case UsernameCheckStatus.invalidFormat:
        return 'Use 3–30 lowercase letters, numbers, or underscores';
      case UsernameCheckStatus.reserved:
        return 'This username is reserved';
      case UsernameCheckStatus.error:
        return 'Could not check availability. Try again.';
    }
  }

  bool get isAvailable => status == UsernameCheckStatus.available;
}

@riverpod
class UsernameController extends _$UsernameController {
  @override
  UsernameState build() => const UsernameState();

  /// Called from the TextField's onChanged with a 400ms debounce applied in the UI.
  Future<void> checkUsername(String username) async {
    if (username.isEmpty) {
      state = const UsernameState();
      return;
    }

    state = state.copyWith(username: username, status: UsernameCheckStatus.checking);

    try {
      final result = await ref.read(profileRepoProvider).checkUsername(username);

      if (result.available) {
        state = state.copyWith(status: UsernameCheckStatus.available);
      } else {
        switch (result.reason) {
          case 'invalid_format':
            state = state.copyWith(status: UsernameCheckStatus.invalidFormat);
            break;
          case 'reserved':
            state = state.copyWith(status: UsernameCheckStatus.reserved);
            break;
          default:
            state = state.copyWith(status: UsernameCheckStatus.taken);
        }
      }
    } catch (_) {
      state = state.copyWith(status: UsernameCheckStatus.error);
    }
  }

  /// Called when the user taps Confirm on the username screen.
  /// Updates authController state so the router can redirect to home.
  Future<void> confirmUsername(String username) async {
    final updatedUser = await ref.read(profileRepoProvider).setUsername(username);
    // Update the auth controller state so the user object is fresh everywhere
    ref.read(authControllerProvider.notifier).updateUser(updatedUser);
  }
}
```

---

## Part 5 — Router Changes

### File: `lib/core/routes/app_router.dart`

Add the profile setup flow to the existing GoRouter. The redirect logic checks `isProfileSetup` on the user object.

Find the existing redirect function and extend it. The full logic should be:

```dart
redirect: (context, state) {
  final authState = container.read(authNotifierProvider);
  final isLoggedIn = authState.isLoggedIn;
  final currentPath = state.matchedLocation;

  // Not logged in → go to login
  if (!isLoggedIn) {
    if (currentPath == '/login') return null;
    return '/login';
  }

  // Logged in — check profile setup
  final user = container.read(authControllerProvider).valueOrNull;

  // If user is loaded and profile not set up → go to setup
  if (user != null && !user.isProfileSetup) {
    if (currentPath == '/profile-setup') return null;
    return '/profile-setup';
  }

  // If user is loaded and has no username yet → go to username screen
  // (This handles the case where setup was done but username step was interrupted)
  if (user != null && user.isProfileSetup && (user.username == null || user.username!.isEmpty)) {
    if (currentPath == '/username-setup') return null;
    return '/username-setup';
  }

  // Already logged in and set up → don't go back to login
  if (currentPath == '/login') return '/home';

  return null;
},
```

Add these routes to the GoRouter routes list:

```dart
GoRoute(
  path: '/profile-setup',
  builder: (context, state) => const ProfileSetupScreen(),
),
GoRoute(
  path: '/username-setup',
  builder: (context, state) => const UsernameSetupScreen(),
),
```

---

## Part 6 — Profile Setup Screen

### File: `lib/features/profile/screens/profile_setup_screen.dart`

This is Screen 1 of the post-auth setup flow. It pre-populates from the current user.

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

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _linkController;

  String? _photoURL;          // current photo URL (from Google or newly uploaded)
  String? _coverImageURL;     // cover image URL
  File? _localPhoto;          // local file selected but not yet uploaded
  File? _localCoverImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).valueOrNull;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _bioController = TextEditingController();
    _linkController = TextEditingController();
    _photoURL = user?.photoURL;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 800, imageQuality: 85);
    if (picked != null) {
      setState(() => _localPhoto = File(picked.path));
    }
  }

  Future<void> _pickCoverImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (picked != null) {
      setState(() => _localCoverImage = File(picked.path));
    }
  }

  Future<void> _onNext() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final cloudinary = ref.read(cloudinaryServiceProvider);

      // Upload new photo if user changed it
      String finalPhotoURL = _photoURL ?? '';
      if (_localPhoto != null) {
        final result = await cloudinary.upload(filePath: _localPhoto!.path);
        finalPhotoURL = result.secureUrl;
      }

      // Upload cover image if selected
      String finalCoverURL = '';
      if (_localCoverImage != null) {
        final result = await cloudinary.upload(filePath: _localCoverImage!.path);
        finalCoverURL = result.secureUrl;
      }

      // Call setup API
      final updatedUser = await ref.read(profileRepoProvider).setupProfile(
        displayName: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        externalLink: _linkController.text.trim(),
        photoURL: finalPhotoURL,
        coverImageURL: finalCoverURL,
      );

      // Update auth state
      ref.read(authControllerProvider.notifier).updateUser(updatedUser);

      if (mounted) {
        context.go('/username-setup');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, message: e.toString(), type: SnackbarType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Set up your profile', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600)),
        centerTitle: true,
        automaticallyImplyLeading: false, // No back button — setup is mandatory
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Cover Image ──
              GestureDetector(
                onTap: _pickCoverImage,
                child: Container(
                  height: 120.h,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.featureBackgroundColor,
                    borderRadius: BorderRadius.circular(12.r),
                    image: _localCoverImage != null
                        ? DecorationImage(image: FileImage(_localCoverImage!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _localCoverImage == null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined, size: 32.r, color: AppTheme.textLightColor),
                              SizedBox(height: 4.h),
                              Text('Add cover image', style: TextStyle(fontSize: 13.sp, color: AppTheme.textLightColor)),
                            ],
                          ),
                        )
                      : null,
                ),
              ),

              SizedBox(height: 16.h),

              // ── Profile Photo ──
              Center(
                child: GestureDetector(
                  onTap: () => _pickPhoto(ImageSource.gallery),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 44.r,
                        backgroundColor: AppTheme.borderColor,
                        backgroundImage: _localPhoto != null
                            ? FileImage(_localPhoto!) as ImageProvider
                            : (_photoURL != null ? NetworkImage(_photoURL!) : null),
                        child: (_localPhoto == null && _photoURL == null)
                            ? Icon(Icons.person, size: 40.r, color: Colors.white)
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: EdgeInsets.all(6.r),
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.camera_alt, size: 16.r, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 24.h),

              // ── Display Name ──
              Text('Name', style: TextStyle(fontSize: 13.sp, color: AppTheme.textMediumColor, fontWeight: FontWeight.w500)),
              SizedBox(height: 6.h),
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration('Your name'),
                maxLength: 50,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),

              SizedBox(height: 16.h),

              // ── Bio ──
              Text('Bio', style: TextStyle(fontSize: 13.sp, color: AppTheme.textMediumColor, fontWeight: FontWeight.w500)),
              SizedBox(height: 6.h),
              TextFormField(
                controller: _bioController,
                decoration: _inputDecoration('A few words about yourself...'),
                maxLines: 3,
                maxLength: 200,
              ),

              SizedBox(height: 16.h),

              // ── External Link ──
              Text('Link', style: TextStyle(fontSize: 13.sp, color: AppTheme.textMediumColor, fontWeight: FontWeight.w500)),
              SizedBox(height: 6.h),
              TextFormField(
                controller: _linkController,
                decoration: _inputDecoration('https://yoursite.com'),
                keyboardType: TextInputType.url,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null; // optional
                  if (!v.startsWith('http://') && !v.startsWith('https://')) {
                    return 'Link must start with http:// or https://';
                  }
                  return null;
                },
              ),

              SizedBox(height: 32.h),

              // ── Next Button ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                  child: _isLoading
                      ? SizedBox(width: 20.r, height: 20.r, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Next', style: TextStyle(fontSize: 16.sp, color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppTheme.textLightColor),
      filled: true,
      fillColor: AppTheme.featureBackgroundColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: BorderSide(color: AppTheme.borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: BorderSide(color: AppTheme.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: const BorderSide(color: AppTheme.primaryColor),
      ),
      counterText: '',
    );
  }
}
```

---

## Part 7 — Username Setup Screen

### File: `lib/features/profile/screens/username_setup_screen.dart`

This is Screen 2. Debounce is applied here in the UI layer.

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/features/profile/controllers/profile_setup_controller.dart';
import 'package:chatbee/shared/widgets/app_snackbar.dart';

class UsernameSetupScreen extends ConsumerStatefulWidget {
  const UsernameSetupScreen({super.key});

  @override
  ConsumerState<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends ConsumerState<UsernameSetupScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  bool _isConfirming = false;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _debounce?.cancel();
    if (value.isEmpty) {
      ref.read(usernameControllerProvider.notifier).checkUsername('');
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(usernameControllerProvider.notifier).checkUsername(value.toLowerCase().trim());
    });
  }

  Future<void> _onConfirm() async {
    final usernameState = ref.read(usernameControllerProvider);
    if (!usernameState.isAvailable) return;

    setState(() => _isConfirming = true);
    try {
      await ref.read(usernameControllerProvider.notifier).confirmUsername(usernameState.username);
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, message: e.toString(), type: SnackbarType.error);
      }
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usernameState = ref.watch(usernameControllerProvider);

    // Status color for the feedback text below the field
    Color statusColor = AppTheme.textMediumColor;
    if (usernameState.status == UsernameCheckStatus.available) {
      statusColor = Colors.green;
    } else if (usernameState.status == UsernameCheckStatus.taken ||
        usernameState.status == UsernameCheckStatus.invalidFormat ||
        usernameState.status == UsernameCheckStatus.reserved) {
      statusColor = Colors.red;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Choose a username', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600)),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your username is how other poets find you. You can only set this once.',
              style: TextStyle(fontSize: 14.sp, color: AppTheme.textMediumColor),
            ),

            SizedBox(height: 28.h),

            // ── Username Field ──
            TextField(
              controller: _controller,
              onChanged: _onUsernameChanged,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              style: TextStyle(fontSize: 16.sp, color: AppTheme.textDarkColor),
              decoration: InputDecoration(
                prefixText: '@',
                prefixStyle: TextStyle(fontSize: 16.sp, color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
                hintText: 'yourname',
                hintStyle: TextStyle(color: AppTheme.textLightColor),
                filled: true,
                fillColor: AppTheme.featureBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: BorderSide(color: AppTheme.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: BorderSide(color: AppTheme.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: BorderSide(
                    color: usernameState.status == UsernameCheckStatus.available
                        ? Colors.green
                        : AppTheme.primaryColor,
                  ),
                ),
                // Show check or X icon on the right based on status
                suffixIcon: _buildSuffixIcon(usernameState.status),
              ),
            ),

            SizedBox(height: 8.h),

            // ── Status message ──
            if (usernameState.statusMessage.isNotEmpty)
              Text(
                usernameState.statusMessage,
                style: TextStyle(fontSize: 13.sp, color: statusColor),
              ),

            SizedBox(height: 8.h),

            Text(
              '3–30 characters. Letters, numbers, and underscores only.',
              style: TextStyle(fontSize: 12.sp, color: AppTheme.textLightColor),
            ),

            const Spacer(),

            // ── Confirm Button ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (usernameState.isAvailable && !_isConfirming) ? _onConfirm : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  disabledBackgroundColor: AppTheme.borderColor,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
                child: _isConfirming
                    ? SizedBox(width: 20.r, height: 20.r, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Confirm username', style: TextStyle(fontSize: 16.sp, color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),

            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  Widget? _buildSuffixIcon(UsernameCheckStatus status) {
    switch (status) {
      case UsernameCheckStatus.checking:
        return Padding(
          padding: EdgeInsets.all(12.r),
          child: SizedBox(width: 18.r, height: 18.r, child: const CircularProgressIndicator(strokeWidth: 2)),
        );
      case UsernameCheckStatus.available:
        return Icon(Icons.check_circle_rounded, color: Colors.green, size: 22.r);
      case UsernameCheckStatus.taken:
      case UsernameCheckStatus.invalidFormat:
      case UsernameCheckStatus.reserved:
        return Icon(Icons.cancel_rounded, color: Colors.red, size: 22.r);
      default:
        return null;
    }
  }
}
```

---

## Part 8 — Update AuthController

### File: `lib/features/auth/controllers/auth_controller.dart`

Add one new method to the existing `AuthController` class. Do not change any existing methods.

```dart
/// Update the user object in state after profile setup or username set.
/// Called by profile setup flow to keep state fresh without a full re-fetch.
void updateUser(UserModel updatedUser) {
  state = AsyncValue.data(updatedUser);
}
```

---

## Part 9 — Poem Model

### File: `lib/features/poems/models/poem_model.dart`

Create this file.

```dart
import 'package:json_annotation/json_annotation.dart';

part 'poem_model.g.dart';

@JsonSerializable()
class PoemAuthor {
  final String id;
  final String displayName;
  final String username;
  final String photoURL;
  final bool isEditor;

  const PoemAuthor({
    required this.id,
    required this.displayName,
    required this.username,
    required this.photoURL,
    this.isEditor = false,
  });

  factory PoemAuthor.fromJson(Map<String, dynamic> json) => _$PoemAuthorFromJson(json);
  Map<String, dynamic> toJson() => _$PoemAuthorToJson(this);
}

@JsonSerializable()
class PoemModel {
  final String id;
  final PoemAuthor author;
  final String title;
  final String contentJson;   // Quill Delta JSON string
  final String plainText;
  final List<String> hashtags;
  @JsonKey(defaultValue: '')
  final String mood;
  final bool isOriginal;
  final String visibility;    // "public" | "private"
  @JsonKey(defaultValue: '')
  final String audioUrl;
  @JsonKey(defaultValue: 0)
  final int audioDuration;    // seconds
  @JsonKey(defaultValue: '')
  final String coverColor;
  final int likesCount;
  final int commentsCount;
  final int repostsCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PoemModel({
    required this.id,
    required this.author,
    required this.title,
    required this.contentJson,
    required this.plainText,
    this.hashtags = const [],
    this.mood = '',
    this.isOriginal = false,
    this.visibility = 'public',
    this.audioUrl = '',
    this.audioDuration = 0,
    this.coverColor = '',
    this.likesCount = 0,
    this.commentsCount = 0,
    this.repostsCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory PoemModel.fromJson(Map<String, dynamic> json) => _$PoemModelFromJson(json);
  Map<String, dynamic> toJson() => _$PoemModelToJson(this);

  bool get isDraft => visibility == 'private';
  bool get isPublic => visibility == 'public';
  bool get hasAudio => audioUrl.isNotEmpty;

  PoemModel copyWith({
    String? id,
    PoemAuthor? author,
    String? title,
    String? contentJson,
    String? plainText,
    List<String>? hashtags,
    String? mood,
    bool? isOriginal,
    String? visibility,
    String? audioUrl,
    int? audioDuration,
    String? coverColor,
    int? likesCount,
    int? commentsCount,
    int? repostsCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PoemModel(
      id: id ?? this.id,
      author: author ?? this.author,
      title: title ?? this.title,
      contentJson: contentJson ?? this.contentJson,
      plainText: plainText ?? this.plainText,
      hashtags: hashtags ?? this.hashtags,
      mood: mood ?? this.mood,
      isOriginal: isOriginal ?? this.isOriginal,
      visibility: visibility ?? this.visibility,
      audioUrl: audioUrl ?? this.audioUrl,
      audioDuration: audioDuration ?? this.audioDuration,
      coverColor: coverColor ?? this.coverColor,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      repostsCount: repostsCount ?? this.repostsCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class PoemsPage {
  final List<PoemModel> poems;
  final bool hasMore;

  const PoemsPage({required this.poems, required this.hasMore});

  factory PoemsPage.fromJson(Map<String, dynamic> json) {
    final list = json['poems'] as List? ?? [];
    return PoemsPage(
      poems: list.map((e) => PoemModel.fromJson(e as Map<String, dynamic>)).toList(),
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}
```

---

## Part 10 — Poem Repo

### File: `lib/features/poems/repos/poem_repo.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/core/constants/api_endpoints.dart';
import 'package:chatbee/core/network/api_client.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';

part 'poem_repo.g.dart';

class CreatePoemRequest {
  final String title;
  final String contentJson;
  final String plainText;
  final List<String> hashtags;
  final String mood;
  final bool isOriginal;
  final String visibility; // "public" | "private"
  final String audioUrl;
  final int audioDuration;
  final String coverColor;

  const CreatePoemRequest({
    required this.title,
    required this.contentJson,
    required this.plainText,
    this.hashtags = const [],
    this.mood = '',
    this.isOriginal = false,
    required this.visibility,
    this.audioUrl = '',
    this.audioDuration = 0,
    this.coverColor = '',
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'contentJson': contentJson,
    'plainText': plainText,
    'hashtags': hashtags,
    'mood': mood,
    'isOriginal': isOriginal,
    'visibility': visibility,
    'audioUrl': audioUrl,
    'audioDuration': audioDuration,
    'coverColor': coverColor,
  };
}

class PoemRepo {
  final ApiClient apiClient;

  PoemRepo({required this.apiClient});

  Future<PoemModel> createPoem(CreatePoemRequest request) async {
    final response = await apiClient.post(
      ApiEndpoints.poems,
      data: request.toJson(),
    );
    return PoemModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PoemModel> getPoem(String poemId) async {
    final response = await apiClient.get(ApiEndpoints.poem(poemId));
    return PoemModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PoemModel> updatePoem(String poemId, CreatePoemRequest request) async {
    final response = await apiClient.patch(
      ApiEndpoints.poem(poemId),
      data: request.toJson(),
    );
    return PoemModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deletePoem(String poemId) async {
    await apiClient.delete(ApiEndpoints.poem(poemId));
  }

  Future<PoemsPage> getMyPoems({int limit = 20, String? before}) async {
    final query = <String, dynamic>{'limit': limit};
    if (before != null) query['before'] = before;
    final response = await apiClient.get(ApiEndpoints.myPoems, queryParameters: query);
    return PoemsPage.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PoemsPage> getUserPoems(String userId, {int limit = 20, String? before}) async {
    final query = <String, dynamic>{'limit': limit};
    if (before != null) query['before'] = before;
    final response = await apiClient.get(ApiEndpoints.userPoems(userId), queryParameters: query);
    return PoemsPage.fromJson(response.data as Map<String, dynamic>);
  }
}

@riverpod
PoemRepo poemRepo(Ref ref) {
  return PoemRepo(apiClient: ref.read(apiClientProvider));
}
```

---

## Part 11 — Poem Controller

### File: `lib/features/poems/controllers/poem_controller.dart`

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';
import 'package:chatbee/features/poems/repos/poem_repo.dart';

part 'poem_controller.g.dart';

/// My poems list — keepAlive so it persists across navigation
@Riverpod(keepAlive: true)
class MyPoemsController extends _$MyPoemsController {
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  FutureOr<List<PoemModel>> build() async {
    final page = await ref.read(poemRepoProvider).getMyPoems(limit: 20);
    _hasMore = page.hasMore;
    return page.poems;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final page = await ref.read(poemRepoProvider).getMyPoems(limit: 20);
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
      final page = await ref.read(poemRepoProvider).getMyPoems(
        limit: 20,
        before: current.last.id,
      );
      _hasMore = page.hasMore;
      state = AsyncValue.data([...current, ...page.poems]);
    } finally {
      _isLoadingMore = false;
    }
  }

  /// Add a new poem to the top of the list after creation
  void prependPoem(PoemModel poem) {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([poem, ...current]);
  }

  /// Replace a poem after editing
  void updatePoem(PoemModel updatedPoem) {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
      current.map((p) => p.id == updatedPoem.id ? updatedPoem : p).toList(),
    );
  }

  /// Remove a poem after deletion
  void removePoem(String poemId) {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(current.where((p) => p.id != poemId).toList());
  }

  bool get hasMore => _hasMore;
}
```

---

## Part 12 — Publish Bottom Sheet

### File: `lib/features/poems/widgets/publish_bottom_sheet.dart`

This sheet is shown when the user taps Save on the Quill editor. It handles hashtags, mood, copyright, audio recording/upload, and draft vs publish.

```dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/core/services/cloudinary_service.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';
import 'package:chatbee/features/poems/repos/poem_repo.dart';
import 'package:chatbee/features/poems/controllers/poem_controller.dart';
import 'package:chatbee/shared/widgets/app_snackbar.dart';

// ── Static hashtag chips — the fixed set ──
const List<String> kStaticHashtags = [
  'love', 'grief', 'nature', 'nostalgia', 'hope',
  'dark', 'spiritual', 'humour', 'life', 'longing',
];

// ── Mood options — same as backend ValidMoods ──
const List<String> kMoods = [
  'love', 'grief', 'nature', 'nostalgia', 'hope',
  'dark', 'spiritual', 'humour', 'life', 'longing',
];

/// Audio state for the recording section
enum AudioState { idle, recording, recorded, uploading, uploaded }

/// Call this function to show the bottom sheet.
/// Returns a PoemModel if the poem was saved, null if dismissed.
Future<PoemModel?> showPublishBottomSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String title,
  required String contentJson,
  required String plainText,
  required String coverColor,
  String? existingPoemId, // non-null when editing an existing poem
  PoemModel? existingPoem, // pass to pre-fill fields when editing
}) {
  return showModalBottomSheet<PoemModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => PublishBottomSheet(
      ref: ref,
      title: title,
      contentJson: contentJson,
      plainText: plainText,
      coverColor: coverColor,
      existingPoemId: existingPoemId,
      existingPoem: existingPoem,
    ),
  );
}

class PublishBottomSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;
  final String title;
  final String contentJson;
  final String plainText;
  final String coverColor;
  final String? existingPoemId;
  final PoemModel? existingPoem;

  const PublishBottomSheet({
    super.key,
    required this.ref,
    required this.title,
    required this.contentJson,
    required this.plainText,
    required this.coverColor,
    this.existingPoemId,
    this.existingPoem,
  });

  @override
  ConsumerState<PublishBottomSheet> createState() => _PublishBottomSheetState();
}

class _PublishBottomSheetState extends ConsumerState<PublishBottomSheet> {
  // ── Hashtag state ──
  final Set<String> _selectedHashtags = {};
  final TextEditingController _customTagController = TextEditingController();
  final List<String> _customTags = [];

  // ── Mood state ──
  String? _selectedMood;

  // ── Copyright state ──
  bool _isOriginal = false;

  // ── Audio state ──
  AudioState _audioState = AudioState.idle;
  String? _recordingPath;   // local file path after recording
  String? _audioURL;        // Cloudinary URL after upload
  int _audioDuration = 0;   // seconds
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _previewPlayer = AudioPlayer();
  bool _isPlayingPreview = false;

  // ── Submit state ──
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill if editing
    if (widget.existingPoem != null) {
      final p = widget.existingPoem!;
      _selectedHashtags.addAll(p.hashtags.where((t) => kStaticHashtags.contains(t)));
      _customTags.addAll(p.hashtags.where((t) => !kStaticHashtags.contains(t)));
      _selectedMood = p.mood.isEmpty ? null : p.mood;
      _isOriginal = p.isOriginal;
      if (p.hasAudio) {
        _audioURL = p.audioUrl;
        _audioDuration = p.audioDuration;
        _audioState = AudioState.uploaded;
      }
    }
  }

  @override
  void dispose() {
    _customTagController.dispose();
    _recordingTimer?.cancel();
    _recorder.dispose();
    _previewPlayer.dispose();
    super.dispose();
  }

  // ── Recording ──

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) AppSnackbar.show(context, message: 'Microphone permission denied', type: SnackbarType.error);
      return;
    }

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/poem_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    setState(() {
      _audioState = AudioState.recording;
      _recordingPath = path;
      _recordingSeconds = 0;
    });

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _recordingSeconds++);
    });
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    final path = await _recorder.stop();
    setState(() {
      _audioState = AudioState.recorded;
      _recordingPath = path;
      _audioDuration = _recordingSeconds;
    });
  }

  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
    await _recorder.cancel();
    setState(() {
      _audioState = AudioState.idle;
      _recordingPath = null;
      _recordingSeconds = 0;
      _audioDuration = 0;
    });
  }

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    setState(() {
      _recordingPath = file.path;
      _audioState = AudioState.recorded;
      _audioDuration = 0; // duration unknown until uploaded
    });
  }

  Future<void> _uploadAudio() async {
    if (_recordingPath == null) return;
    setState(() => _audioState = AudioState.uploading);

    try {
      final cloudinary = ref.read(cloudinaryServiceProvider);
      final uploadResult = await cloudinary.upload(filePath: _recordingPath!);
      setState(() {
        _audioURL = uploadResult.secureUrl;
        _audioState = AudioState.uploaded;
      });
    } catch (e) {
      setState(() => _audioState = AudioState.recorded);
      if (mounted) AppSnackbar.show(context, message: 'Audio upload failed. Try again.', type: SnackbarType.error);
    }
  }

  Future<void> _togglePreviewPlayback() async {
    if (_isPlayingPreview) {
      await _previewPlayer.stop();
      setState(() => _isPlayingPreview = false);
    } else {
      final source = _audioURL != null
          ? AudioSource.uri(Uri.parse(_audioURL!))
          : AudioSource.file(_recordingPath!);
      await _previewPlayer.setAudioSource(source);
      await _previewPlayer.play();
      setState(() => _isPlayingPreview = true);
      _previewPlayer.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed) {
          if (mounted) setState(() => _isPlayingPreview = false);
        }
      });
    }
  }

  void _removeAudio() {
    setState(() {
      _audioState = AudioState.idle;
      _recordingPath = null;
      _audioURL = null;
      _audioDuration = 0;
    });
  }

  // ── Custom tag input ──

  void _addCustomTag() {
    final tag = _customTagController.text
        .trim()
        .toLowerCase()
        .replaceAll('#', '');
    if (tag.isEmpty || _customTags.contains(tag) || _selectedHashtags.contains(tag)) return;
    if (_selectedHashtags.length + _customTags.length >= 10) {
      AppSnackbar.show(context, message: 'Maximum 10 hashtags', type: SnackbarType.error);
      return;
    }
    setState(() {
      _customTags.add(tag);
      _customTagController.clear();
    });
  }

  List<String> get _allHashtags => [..._selectedHashtags, ..._customTags];

  // ── Submit ──

  Future<void> _submit(String visibility) async {
    // If audio is recorded but not uploaded yet, upload first
    if (_audioState == AudioState.recorded && _recordingPath != null) {
      await _uploadAudio();
      if (_audioState != AudioState.uploaded) return; // upload failed
    }

    setState(() => _isSubmitting = true);

    try {
      final request = CreatePoemRequest(
        title: widget.title,
        contentJson: widget.contentJson,
        plainText: widget.plainText,
        hashtags: _allHashtags,
        mood: _selectedMood ?? '',
        isOriginal: _isOriginal,
        visibility: visibility,
        audioUrl: _audioURL ?? '',
        audioDuration: _audioDuration,
        coverColor: widget.coverColor,
      );

      PoemModel poem;
      if (widget.existingPoemId != null) {
        poem = await ref.read(poemRepoProvider).updatePoem(widget.existingPoemId!, request);
        ref.read(myPoemsControllerProvider.notifier).updatePoem(poem);
      } else {
        poem = await ref.read(poemRepoProvider).createPoem(request);
        ref.read(myPoemsControllerProvider.notifier).prependPoem(poem);
      }

      if (mounted) Navigator.of(context).pop(poem);
    } catch (e) {
      if (mounted) AppSnackbar.show(context, message: e.toString(), type: SnackbarType.error);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: EdgeInsets.only(top: 12.h, bottom: 4.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),

              // Title
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                child: Row(
                  children: [
                    Text(
                      widget.existingPoemId != null ? 'Update poem' : 'Publish poem',
                      style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, color: AppTheme.textDarkColor),
                    ),
                  ],
                ),
              ),

              Divider(height: 1, color: AppTheme.borderColor),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                  children: [

                    // ── Hashtags ──
                    _SectionLabel('Hashtags'),
                    SizedBox(height: 10.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: kStaticHashtags.map((tag) {
                        final selected = _selectedHashtags.contains(tag);
                        return FilterChip(
                          label: Text('#$tag'),
                          selected: selected,
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                if (_allHashtags.length < 10) _selectedHashtags.add(tag);
                              } else {
                                _selectedHashtags.remove(tag);
                              }
                            });
                          },
                          selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                          checkmarkColor: AppTheme.primaryColor,
                          labelStyle: TextStyle(
                            fontSize: 13.sp,
                            color: selected ? AppTheme.primaryColor : AppTheme.textMediumColor,
                          ),
                          backgroundColor: AppTheme.featureBackgroundColor,
                          side: BorderSide(
                            color: selected ? AppTheme.primaryColor : AppTheme.borderColor,
                          ),
                        );
                      }).toList(),
                    ),

                    // Custom tags added by user
                    if (_customTags.isNotEmpty) ...[
                      SizedBox(height: 8.h),
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: _customTags.map((tag) {
                          return Chip(
                            label: Text('#$tag'),
                            deleteIcon: Icon(Icons.close, size: 16.r),
                            onDeleted: () => setState(() => _customTags.remove(tag)),
                            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                            labelStyle: TextStyle(fontSize: 13.sp, color: AppTheme.primaryColor),
                            side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                          );
                        }).toList(),
                      ),
                    ],

                    SizedBox(height: 10.h),

                    // Custom hashtag input
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customTagController,
                            onSubmitted: (_) => _addCustomTag(),
                            style: TextStyle(fontSize: 14.sp, color: AppTheme.textDarkColor),
                            decoration: InputDecoration(
                              hintText: 'Add your own tag...',
                              hintStyle: TextStyle(fontSize: 14.sp, color: AppTheme.textLightColor),
                              prefixText: '# ',
                              prefixStyle: TextStyle(fontSize: 14.sp, color: AppTheme.textMediumColor),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                              filled: true,
                              fillColor: AppTheme.featureBackgroundColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.r),
                                borderSide: BorderSide(color: AppTheme.borderColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.r),
                                borderSide: BorderSide(color: AppTheme.borderColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.r),
                                borderSide: const BorderSide(color: AppTheme.primaryColor),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        GestureDetector(
                          onTap: _addCustomTag,
                          child: Container(
                            padding: EdgeInsets.all(10.r),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Icon(Icons.add, color: Colors.white, size: 20.r),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 24.h),

                    // ── Audio Section ──
                    _SectionLabel('Voice / Audio (optional)'),
                    SizedBox(height: 10.h),
                    _buildAudioSection(),

                    SizedBox(height: 24.h),

                    // ── Copyright ──
                    Row(
                      children: [
                        Checkbox(
                          value: _isOriginal,
                          onChanged: (v) => setState(() => _isOriginal = v ?? false),
                          activeColor: AppTheme.primaryColor,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isOriginal = !_isOriginal),
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: '© ',
                                    style: TextStyle(fontSize: 15.sp, color: AppTheme.primaryColor, fontWeight: FontWeight.w700),
                                  ),
                                  TextSpan(
                                    text: 'This is my original work',
                                    style: TextStyle(fontSize: 14.sp, color: AppTheme.textDarkColor),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 32.h),

                    // ── Action Buttons ──
                    Row(
                      children: [
                        // Draft button
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSubmitting ? null : () => _submit('private'),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              side: BorderSide(color: AppTheme.borderColor),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                            ),
                            child: Text(
                              'Save Draft',
                              style: TextStyle(fontSize: 15.sp, color: AppTheme.textMediumColor),
                            ),
                          ),
                        ),

                        SizedBox(width: 12.w),

                        // Publish button
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : () => _submit('public'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                            ),
                            child: _isSubmitting
                                ? SizedBox(width: 20.r, height: 20.r, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(
                                    widget.existingPoemId != null ? 'Update' : 'Publish',
                                    style: TextStyle(fontSize: 15.sp, color: Colors.white, fontWeight: FontWeight.w600),
                                  ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 32.h),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAudioSection() {
    switch (_audioState) {
      case AudioState.idle:
        return Row(
          children: [
            // Record button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _startRecording,
                icon: Icon(Icons.mic_rounded, size: 18.r, color: AppTheme.primaryColor),
                label: Text('Record', style: TextStyle(fontSize: 14.sp, color: AppTheme.primaryColor)),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  side: const BorderSide(color: AppTheme.primaryColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                ),
              ),
            ),
            SizedBox(width: 10.w),
            // Upload button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickAudioFile,
                icon: Icon(Icons.upload_file_rounded, size: 18.r, color: AppTheme.textMediumColor),
                label: Text('Upload', style: TextStyle(fontSize: 14.sp, color: AppTheme.textMediumColor)),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  side: BorderSide(color: AppTheme.borderColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                ),
              ),
            ),
          ],
        );

      case AudioState.recording:
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 10.r, height: 10.r,
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              ),
              SizedBox(width: 10.w),
              Text(
                _formatDuration(_recordingSeconds),
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: Colors.red),
              ),
              const Spacer(),
              TextButton(
                onPressed: _cancelRecording,
                child: Text('Cancel', style: TextStyle(fontSize: 13.sp, color: AppTheme.textMediumColor)),
              ),
              SizedBox(width: 8.w),
              ElevatedButton(
                onPressed: _stopRecording,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                ),
                child: Text('Stop', style: TextStyle(fontSize: 13.sp, color: Colors.white)),
              ),
            ],
          ),
        );

      case AudioState.recorded:
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: AppTheme.featureBackgroundColor,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: _togglePreviewPlayback,
                icon: Icon(
                  _isPlayingPreview ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                  size: 36.r,
                  color: AppTheme.primaryColor,
                ),
                padding: EdgeInsets.zero,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Audio recorded', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500, color: AppTheme.textDarkColor)),
                    if (_audioDuration > 0)
                      Text(_formatDuration(_audioDuration), style: TextStyle(fontSize: 12.sp, color: AppTheme.textLightColor)),
                  ],
                ),
              ),
              TextButton(
                onPressed: _removeAudio,
                child: Text('Remove', style: TextStyle(fontSize: 13.sp, color: Colors.red)),
              ),
            ],
          ),
        );

      case AudioState.uploading:
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: AppTheme.featureBackgroundColor,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            children: [
              SizedBox(width: 20.r, height: 20.r, child: const CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12.w),
              Text('Uploading audio...', style: TextStyle(fontSize: 14.sp, color: AppTheme.textMediumColor)),
            ],
          ),
        );

      case AudioState.uploaded:
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: _togglePreviewPlayback,
                icon: Icon(
                  _isPlayingPreview ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                  size: 36.r,
                  color: Colors.green,
                ),
                padding: EdgeInsets.zero,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle_rounded, size: 14.r, color: Colors.green),
                        SizedBox(width: 4.w),
                        Text('Audio ready', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500, color: Colors.green)),
                      ],
                    ),
                    if (_audioDuration > 0)
                      Text(_formatDuration(_audioDuration), style: TextStyle(fontSize: 12.sp, color: AppTheme.textLightColor)),
                  ],
                ),
              ),
              TextButton(
                onPressed: _removeAudio,
                child: Text('Remove', style: TextStyle(fontSize: 13.sp, color: Colors.red)),
              ),
            ],
          ),
        );
    }
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14.sp,
        fontWeight: FontWeight.w600,
        color: AppTheme.textMediumColor,
        letterSpacing: 0.3,
      ),
    );
  }
}
```

---

## Part 13 — Connecting the Editor to the Bottom Sheet

### File: Your existing Quill editor screen

In your existing Quill editor screen, the Save button in the AppBar should trigger the publish flow. Find the Save button's `onPressed` and replace it with:

```dart
onPressed: () async {
  // 1. Get current content from Quill controller
  final controller = _quillController; // your existing QuillController variable
  final contentJson = jsonEncode(controller.document.toDelta().toJson());
  final plainText = controller.document.toPlainText().trim();
  final title = _titleController.text.trim(); // your title field controller

  if (plainText.isEmpty) {
    AppSnackbar.show(context, message: 'Write something first', type: SnackbarType.error);
    return;
  }

  // 2. Show the publish bottom sheet
  final result = await showPublishBottomSheet(
    context: context,
    ref: ref,
    title: title.isEmpty ? 'Untitled Poem' : title,
    contentJson: contentJson,
    plainText: plainText,
    coverColor: '', // pass your editor's selected background color if any
    existingPoemId: widget.poemId, // null if creating, non-null if editing
    existingPoem: widget.existingPoem, // null if creating
  );

  // 3. If successfully saved, go back
  if (result != null && mounted) {
    context.pop(); // or context.go('/my-poems')
  }
},
```

The editor screen should accept an optional `poemId` and `existingPoem` parameter in its constructor so it knows whether it's in create or edit mode:

```dart
class PoetryEditorScreen extends ConsumerStatefulWidget {
  final String? poemId;           // null = create mode
  final PoemModel? existingPoem;  // null = create mode, non-null = edit mode

  const PoetryEditorScreen({super.key, this.poemId, this.existingPoem});
}
```

In `initState`, pre-fill the editor if in edit mode:
```dart
@override
void initState() {
  super.initState();
  if (widget.existingPoem != null) {
    // Load Quill document from stored JSON
    final doc = quill.Document.fromJson(
      jsonDecode(widget.existingPoem!.contentJson) as List,
    );
    _quillController = quill.QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
    _titleController = TextEditingController(text: widget.existingPoem!.title);
  } else {
    _quillController = quill.QuillController.basic();
    _titleController = TextEditingController();
  }
}
```

---

## Part 14 — My Poems List Screen

### File: `lib/features/poems/screens/my_poems_screen.dart`

A simple paginated list of the current user's poems. Tapping a poem opens the editor in edit mode.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/features/poems/controllers/poem_controller.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';
import 'package:chatbee/shared/widgets/app_snackbar.dart';

class MyPoemsScreen extends ConsumerStatefulWidget {
  const MyPoemsScreen({super.key});

  @override
  ConsumerState<MyPoemsScreen> createState() => _MyPoemsScreenState();
}

class _MyPoemsScreenState extends ConsumerState<MyPoemsScreen> {
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
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(myPoemsControllerProvider.notifier).loadMore();
    }
  }

  Future<void> _deletePoem(PoemModel poem) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete poem?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(poemRepoProvider).deletePoem(poem.id);
      ref.read(myPoemsControllerProvider.notifier).removePoem(poem.id);
      if (mounted) AppSnackbar.show(context, message: 'Poem deleted', type: SnackbarType.success);
    } catch (e) {
      if (mounted) AppSnackbar.show(context, message: 'Failed to delete', type: SnackbarType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myPoemsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('My Poems', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600)),
        centerTitle: false,
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(e.toString(), style: TextStyle(color: Colors.red, fontSize: 14.sp)),
              TextButton(
                onPressed: () => ref.read(myPoemsControllerProvider.notifier).refresh(),
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
                  Icon(Icons.edit_note_rounded, size: 64.r, color: AppTheme.textLightColor),
                  SizedBox(height: 12.h),
                  Text('No poems yet', style: TextStyle(fontSize: 16.sp, color: AppTheme.textMediumColor)),
                  SizedBox(height: 4.h),
                  Text('Tap + to write your first poem', style: TextStyle(fontSize: 13.sp, color: AppTheme.textLightColor)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(myPoemsControllerProvider.notifier).refresh(),
            child: ListView.separated(
              controller: _scrollController,
              itemCount: poems.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: AppTheme.borderColor),
              itemBuilder: (context, index) {
                final poem = poems[index];
                return _PoemTile(
                  poem: poem,
                  onTap: () => context.push('/editor', extra: poem),
                  onDelete: () => _deletePoem(poem),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/editor'),
        backgroundColor: AppTheme.primaryColor,
        child: Icon(Icons.edit_rounded, color: Colors.white, size: 24.r),
      ),
    );
  }
}

class _PoemTile extends StatelessWidget {
  final PoemModel poem;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PoemTile({required this.poem, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      onTap: onTap,
      title: Row(
        children: [
          Expanded(
            child: Text(
              poem.title,
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: AppTheme.textDarkColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (poem.isDraft)
            Container(
              margin: EdgeInsets.only(left: 8.w),
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: AppTheme.borderColor,
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Text('Draft', style: TextStyle(fontSize: 11.sp, color: AppTheme.textMediumColor)),
            ),
          if (poem.isOriginal)
            Padding(
              padding: EdgeInsets.only(left: 4.w),
              child: Icon(Icons.copyright_rounded, size: 14.r, color: AppTheme.primaryColor),
            ),
          if (poem.hasAudio)
            Padding(
              padding: EdgeInsets.only(left: 4.w),
              child: Icon(Icons.mic_rounded, size: 14.r, color: AppTheme.textMediumColor),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 4.h),
          Text(
            poem.plainText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13.sp, color: AppTheme.textMediumColor),
          ),
          if (poem.hashtags.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Wrap(
              spacing: 4.w,
              children: poem.hashtags.take(3).map((t) => Text(
                '#$t',
                style: TextStyle(fontSize: 12.sp, color: AppTheme.primaryColor),
              )).toList(),
            ),
          ],
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'delete') onDelete();
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
        ],
        icon: Icon(Icons.more_vert_rounded, size: 20.r, color: AppTheme.textMediumColor),
      ),
    );
  }
}
```

---

## Part 15 — Run Codegen

After all files are created or modified, run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

This regenerates:
- `user_model.g.dart` (updated fields)
- `poem_model.g.dart` (new)
- `profile_repo.g.dart` (new)
- `poem_repo.g.dart` (new)
- `profile_setup_controller.g.dart` (new)
- `poem_controller.g.dart` (new)

---

## Implementation Order for Windsurf

Follow this exact order:

1. Add new fields to `UserModel` in `user_model.dart`
2. Add new API endpoints to `ApiEndpoints`
3. Add `updateUser()` to `AuthController`
4. Create `PoemModel`, `PoemAuthor`, `PoemsPage` in `poem_model.dart`
5. Create `ProfileRepo` in `profile_repo.dart`
6. Create `UsernameController` in `profile_setup_controller.dart`
7. Create `ProfileSetupScreen`
8. Create `UsernameSetupScreen`
9. Update router redirect logic and add new routes
10. Create `PoemRepo` in `poem_repo.dart`
11. Create `MyPoemsController` in `poem_controller.dart`
12. Create `PublishBottomSheet` in `publish_bottom_sheet.dart`
13. Update the existing Quill editor screen Save button and constructor
14. Create `MyPoemsScreen`
15. Run `build_runner`

---

## File Structure Summary

```
lib/
├── features/
│   ├── auth/
│   │   ├── models/
│   │   │   └── user_model.dart          ← MODIFIED (add new fields)
│   │   └── controllers/
│   │       └── auth_controller.dart     ← MODIFIED (add updateUser method)
│   ├── profile/
│   │   ├── repos/
│   │   │   └── profile_repo.dart        ← NEW
│   │   ├── controllers/
│   │   │   └── profile_setup_controller.dart  ← NEW
│   │   └── screens/
│   │       ├── profile_setup_screen.dart      ← NEW
│   │       └── username_setup_screen.dart     ← NEW
│   └── poems/
│       ├── models/
│       │   └── poem_model.dart          ← NEW
│       ├── repos/
│       │   └── poem_repo.dart           ← NEW
│       ├── controllers/
│       │   └── poem_controller.dart     ← NEW
│       ├── screens/
│       │   └── my_poems_screen.dart     ← NEW
│       └── widgets/
│           └── publish_bottom_sheet.dart ← NEW
└── core/
    ├── constants/
    │   └── api_endpoints.dart           ← MODIFIED (add new endpoints)
    └── routes/
        └── app_router.dart              ← MODIFIED (add redirect + new routes)
```
