import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/features/auth/models/user_model.dart';
import 'package:chatbee/features/auth/repos/auth_repo.dart';

part 'auth_controller.g.dart';

/// AuthController handles all auth logic using Riverpod AsyncNotifier.
///
/// Flow: View calls method → Controller calls Repo → state updates → View rebuilds.
@riverpod
class AuthController extends _$AuthController {
  @override
  FutureOr<UserModel?> build() => null;

  /// Login with email and password.
  Future<void> login({required String email, required String password}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(authRepoProvider).login(email: email, password: password),
    );
  }

  /// Register a new user.
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepoProvider)
          .register(name: name, email: email, password: password),
    );
  }
}
