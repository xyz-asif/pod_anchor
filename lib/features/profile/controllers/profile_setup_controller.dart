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
