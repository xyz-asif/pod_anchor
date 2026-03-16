import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
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
      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Photo',
            toolbarColor: AppTheme.primaryColor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Photo',
            aspectRatioLockEnabled: true,
          ),
        ],
      );
      if (cropped != null) {
        setState(() => _localPhoto = File(cropped.path));
      }
    }
  }

  Future<void> _pickCoverImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (picked != null) {
      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Cover Image',
            toolbarColor: AppTheme.primaryColor,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Crop Cover Image',
          ),
        ],
      );
      if (cropped != null) {
        setState(() => _localCoverImage = File(cropped.path));
      }
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
