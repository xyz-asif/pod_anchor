import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/features/auth/models/user_model.dart';
import 'package:chatbee/features/auth/controllers/auth_controller.dart';
import 'package:chatbee/features/profile/repos/user_repo.dart';

part 'profile_controller.g.dart';

/// Manages the current user's profile state.
///
/// Loads profile on build, supports update (displayName, bio, photoURL).
/// keepAlive: true ensures state persists across navigation.
@Riverpod(keepAlive: true)
class ProfileController extends _$ProfileController {
  @override
  FutureOr<UserModel?> build() => null;

  /// Load profile from backend. Does not set loading state first so callers
  /// like pull-to-refresh don't trigger a second spinner.
  Future<void> loadProfile() async {
    state = await AsyncValue.guard(
      () => ref.read(userRepoProvider).getMyProfile(),
    );
  }

  /// Update profile fields. Only pass the fields you want to change.
  /// Also syncs to authController so ALL screens see the update.
  Future<void> updateProfile({
    String? displayName,
    String? photoURL,
    String? bio,
    String? coverImageURL,
    String? externalLink,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final updated = await ref.read(userRepoProvider).updateMyProfile(
        displayName: displayName,
        photoURL: photoURL,
        bio: bio,
        coverImageURL: coverImageURL,
        externalLink: externalLink,
      );
      // Sync to auth controller so ALL screens see the update
      ref.read(authControllerProvider.notifier).updateUser(updated);
      return updated;
    });
  }
}
