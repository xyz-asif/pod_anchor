import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:chatbee/features/auth/controllers/auth_controller.dart';
import 'package:chatbee/features/profile/controllers/profile_controller.dart';
import 'package:chatbee/core/services/cloudinary_service.dart';
import 'package:chatbee/shared/widgets/app_snackbar.dart';
import 'package:chatbee/shared/widgets/app_button.dart';
import 'package:chatbee/shared/widgets/app_text_field.dart';
import 'package:chatbee/config/theme/app_theme.dart';

/// Profile screen — view and edit your profile.
///
/// Shows avatar, displayName, email, bio.
/// Tap edit icon to toggle edit mode.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isEditing = false;
  bool _isUploadingImage = false;
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  /// Pick image from gallery and upload to Cloudinary
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

  void _startEditing() {
    final user = ref.read(profileControllerProvider).valueOrNull;
    if (user != null) {
      _nameController.text = user.displayName ?? '';
      _bioController.text = user.bio ?? '';
    }
    setState(() => _isEditing = true);
  }

  void _cancelEditing() {
    setState(() => _isEditing = false);
  }

  void _saveProfile() {
    if (!_formKey.currentState!.validate()) return;

    ref
        .read(profileControllerProvider.notifier)
        .updateProfile(
          displayName: _nameController.text.trim(),
          bio: _bioController.text.trim(),
        );
    setState(() => _isEditing = false);
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
    // Also watch authController for user data
    final authUser = ref.watch(authControllerProvider).valueOrNull;
    final user = profileState.valueOrNull ?? authUser;
    final isLoading = profileState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: Icon(Icons.edit_rounded, size: 22.r),
              onPressed: _startEditing,
            )
          else
            IconButton(
              icon: Icon(Icons.close_rounded, size: 22.r),
              onPressed: _cancelEditing,
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
              child: Column(
                children: [
                  SizedBox(height: 16.h),

                  // Avatar with edit button
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      GestureDetector(
                        onTap: _isUploadingImage ? null : _pickAndUploadImage,
                        child: CircleAvatar(
                          radius: 50.r,
                          backgroundColor: AppTheme.primaryLight,
                          backgroundImage: user?.photoURL != null
                              ? CachedNetworkImageProvider(user!.photoURL!)
                              : null,
                          child: user?.photoURL == null
                              ? Icon(
                                  Icons.person_rounded,
                                  size: 48.r,
                                  color: AppTheme.primaryColor,
                                )
                              : null,
                        ),
                      ),
                      // Upload progress indicator
                      if (_isUploadingImage)
                        Container(
                          width: 100.r,
                          height: 100.r,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          ),
                        )
                      else
                        // Edit button overlay
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
                                size: 20.r,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  if (!_isEditing) ...[
                    // View mode
                    Text(
                      user?.displayName ?? 'No name set',
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDarkColor,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      user?.email ?? '',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppTheme.textMediumColor,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    if (user?.bio != null && user!.bio!.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16.r),
                        decoration: BoxDecoration(
                          color: AppTheme.featureBackgroundColor,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          user.bio!,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppTheme.textDarkColor,
                          ),
                        ),
                      ),
                    SizedBox(height: 32.h),

                    // Sign out button
                    AppButton(
                      text: 'Sign Out',
                      onPressed: () {
                        ref.read(authControllerProvider.notifier).signOut();
                        context.go('/login');
                      },
                    ),
                  ] else ...[
                    // Edit mode
                    SizedBox(height: 16.h),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          AppTextField(
                            label: 'Display Name',
                            controller: _nameController,
                          ),
                          SizedBox(height: 16.h),
                          AppTextField(
                            label: 'Bio',
                            controller: _bioController,
                            maxLines: 3,
                          ),
                          SizedBox(height: 24.h),
                          AppButton(
                            text: 'Save',
                            isLoading: isLoading,
                            onPressed: _saveProfile,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
