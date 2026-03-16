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
    final picked = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (picked != null) setState(() => _newPhoto = File(picked.path));
  }

  Future<void> _pickCover() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (picked != null) setState(() => _newCover = File(picked.path));
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppSnackbar.show(context,
          message: 'Name cannot be empty', type: SnackbarType.error);
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
        AppSnackbar.show(context,
            message: 'Profile updated', type: SnackbarType.success);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context,
            message: e.toString(), type: SnackbarType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile',
            style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600)),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 12.w),
            child: TextButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? SizedBox(
                      width: 18.r,
                      height: 18.r,
                      child: const CircularProgressIndicator(strokeWidth: 2))
                  : Text('Save',
                      style: TextStyle(
                          fontSize: 15.sp,
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600)),
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
                          ? DecorationImage(
                              image: FileImage(_newCover!), fit: BoxFit.cover)
                          : (_currentCoverURL != null &&
                                  _currentCoverURL!.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(_currentCoverURL!),
                                  fit: BoxFit.cover)
                              : null),
                    ),
                  ),
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: const BoxDecoration(
                            color: Colors.black45, shape: BoxShape.circle),
                        child: Icon(Icons.camera_alt,
                            color: Colors.white, size: 20.r),
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
                                : (_currentPhotoURL != null
                                    ? NetworkImage(_currentPhotoURL!)
                                    : null),
                            child:
                                (_newPhoto == null && _currentPhotoURL == null)
                                    ? Icon(Icons.person,
                                        size: 40.r, color: Colors.white)
                                    : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: EdgeInsets.all(4.r),
                              decoration: const BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  shape: BoxShape.circle),
                              child: Icon(Icons.camera_alt,
                                  size: 14.r, color: Colors.white),
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
                        Text('Username',
                            style: TextStyle(
                                fontSize: 12.sp,
                                color: AppTheme.textLightColor)),
                        SizedBox(height: 4.h),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                              horizontal: 12.w, vertical: 12.h),
                          decoration: BoxDecoration(
                            color: AppTheme.featureBackgroundColor
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(
                                color: AppTheme.borderColor
                                    .withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            '@${user?.username ?? ''}',
                            style: TextStyle(
                                fontSize: 14.sp,
                                color: AppTheme.textLightColor),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'Username cannot be changed',
                          style: TextStyle(
                              fontSize: 11.sp, color: AppTheme.textLightColor),
                        ),
                      ],
                    ),
                  ),

                  // ── Editable fields ──
                  _buildField('Name', _nameController, 'Your name',
                      maxLength: 50),
                  SizedBox(height: 16.h),
                  _buildField('Bio', _bioController,
                      'A few words about yourself...',
                      maxLines: 3, maxLength: 200),
                  SizedBox(height: 16.h),
                  _buildField(
                      'Link', _linkController, 'https://yoursite.com',
                      keyboardType: TextInputType.url),
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
        Text(label,
            style: TextStyle(
                fontSize: 12.sp,
                color: AppTheme.textLightColor,
                fontWeight: FontWeight.w500)),
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
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: BorderSide(color: AppTheme.borderColor)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: BorderSide(color: AppTheme.borderColor)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: const BorderSide(color: AppTheme.primaryColor)),
          ),
        ),
      ],
    );
  }
}
