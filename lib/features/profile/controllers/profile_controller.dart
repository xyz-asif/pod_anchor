import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/features/auth/models/user_model.dart';
import 'package:chatbee/features/profile/repos/user_repo.dart';

part 'profile_controller.g.dart';

/// Manages the current user's profile state.
///
/// Loads profile on build, supports update (displayName, bio, photoURL).
@riverpod
class ProfileController extends _$ProfileController {
  @override
  FutureOr<UserModel?> build() => null;

  /// Load profile from backend.
  Future<void> loadProfile() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(userRepoProvider).getMyProfile(),
    );
  }

  /// Update profile fields. Only pass the fields you want to change.
  Future<void> updateProfile({
    String? displayName,
    String? photoURL,
    String? bio,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref
          .read(userRepoProvider)
          .updateMyProfile(
            displayName: displayName,
            photoURL: photoURL,
            bio: bio,
          ),
    );
  }
}
