import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/features/auth/models/user_model.dart';
import 'package:chatbee/features/auth/repos/auth_repo.dart';
import 'package:chatbee/core/services/websocket_service.dart';
import 'package:chatbee/core/providers/auth_provider.dart';
import 'package:chatbee/features/chat/controllers/ws_event_handler.dart';

part 'auth_controller.g.dart';

/// AuthController handles Google Sign-In and session management.
///
/// Flow: View calls method → Controller calls Repo → state updates → View rebuilds.
/// After successful sign-in, connects WebSocket for real-time events.
@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  @override
  FutureOr<UserModel?> build() => null;

  /// Sign in with Google.
  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = await ref.read(authRepoProvider).signInWithGoogle();

      // Connect WebSocket after successful sign-in
      final token = await ref.read(authRepoProvider).getIdToken();
      if (token != null) {
        ref.read(webSocketServiceProvider).connect(token);
      }

      // Start WS event handler so incoming events are processed immediately
      ref.read(wsEventHandlerProvider);

      // Update auth state so the router redirects to /home
      ref.read(authNotifierProvider).login();

      return user;
    });
  }

  /// Refresh user profile from backend.
  Future<void> refreshProfile() async {
    state = await AsyncValue.guard(
      () => ref.read(authRepoProvider).getMyProfile(),
    );
  }

  /// Sign out and disconnect WebSocket.
  Future<void> signOut() async {
    ref.read(webSocketServiceProvider).disconnect();
    await ref.read(authRepoProvider).signOut();
    state = const AsyncValue.data(null);

    // Update auth state so the router redirects to /login
    ref.read(authNotifierProvider).logout();
  }

  /// Check if user is signed in and restore session.
  Future<void> restoreSession() async {
    final repo = ref.read(authRepoProvider);
    if (!repo.isSignedIn) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      // Refresh token and fetch profile
      await repo.refreshToken();
      final user = await repo.getMyProfile();

      // Reconnect WebSocket
      final token = await repo.getIdToken();
      if (token != null) {
        ref.read(webSocketServiceProvider).connect(token);
      }

      return user;
    });
  }
}
