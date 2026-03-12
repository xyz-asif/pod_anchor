import 'package:chatbee/core/network/api_client.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/features/auth/models/user_model.dart';
import 'package:chatbee/features/auth/repos/auth_repo.dart';
import 'package:chatbee/core/services/websocket_service.dart';
import 'package:chatbee/core/providers/auth_provider.dart';
import 'package:chatbee/features/chat/controllers/ws_event_handler.dart';
import 'package:chatbee/core/services/notification_service.dart';
import 'package:chatbee/features/notifications/repos/notification_repo.dart';

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

      // Register FCM token with backend (requires auth)
      final notifService = ref.read(notificationServiceProvider);
      final notifRepo = ref.read(notificationRepoProvider);
      notifService.registerTokenWithBackend(notifRepo);

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
    final apiClient = ref.read(apiClientProvider);
    
    // If no Firebase user AND no token in API client, we are truly logged out
    if (!repo.isSignedIn && !apiClient.hasToken) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      // 1. Refresh token if Firebase session exists
      if (repo.isSignedIn) {
        await repo.refreshToken();
      }
      
      // 2. Fetch profile from backend (uses token currently in ApiClient)
      final user = await repo.getMyProfile();

      // 3. Reconnect WebSocket using existing token
      final token = repo.isSignedIn 
          ? await repo.getIdToken() 
          : apiClient.currentToken;
          
      if (token != null) {
        ref.read(webSocketServiceProvider).connect(token);
      }

      return user;
    });
  }

  /// Returns a freshly-refreshed Firebase ID token.
  /// Call this from lifecycle resume handler before reconnecting WebSocket.
  /// Returns null if user is not signed in.
  Future<String?> getAndRefreshToken() async {
    final repo = ref.read(authRepoProvider);
    if (!repo.isSignedIn) return null;
    try {
      await repo.refreshToken();      // forces Firebase token rotation
      return await repo.getIdToken(); // returns new token
    } catch (e) {
      // If refresh fails, existing token is returned; WS will retry on failure
      return await repo.getIdToken();
    }
  }
}
