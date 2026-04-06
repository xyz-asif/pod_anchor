import 'dart:developer';
import 'package:chatbee/core/errors/failures.dart';
import 'package:chatbee/core/network/api_client.dart';
import 'package:chatbee/core/utils/hive_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    try {
      final user = await ref.read(authRepoProvider).signInWithGoogle();

      // Connect WebSocket using the JWT access token stored during exchange
      final token = HiveStorage.getToken();
      if (token != null) {
        ref.read(webSocketServiceProvider).connect(token);
      }

      // Start WS event handler so incoming events are processed immediately
      ref.read(wsEventHandlerProvider);

      // Update auth state so the router redirects to /home
      await ref.read(authNotifierProvider).login();

      // Register FCM token with backend (requires auth)
      final notifService = ref.read(notificationServiceProvider);
      final notifRepo = ref.read(notificationRepoProvider);
      notifService.registerTokenWithBackend(notifRepo);

      state = AsyncValue.data(user);
    } on SignInCancelledException {
      // User cancelled — reset to idle, no error shown
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
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
    ref.read(notificationServiceProvider).cleanup();
    await ref.read(authRepoProvider).signOut();
    state = const AsyncValue.data(null);

    // Update auth state so the router redirects to /login
    ref.read(authNotifierProvider).logout();

    // Cascade-clear all user-scoped providers in one line
    ref.read(userSessionProvider.notifier).state++;
  }

  /// Check if user is signed in and restore session.
  Future<void> restoreSession() async {
    final repo = ref.read(authRepoProvider);
    final apiClient = ref.read(apiClientProvider);

    // ── Step 0: Wait for Firebase Auth to settle ──────────────────────────
    // Skip Firebase wait if we have a JWT refresh token — it's sufficient for
    // session restore without Firebase (no network call needed).
    // Only wait for Firebase when there is no refresh token (e.g. legacy session
    // or first install before exchange).
    final hasRefreshToken = HiveStorage.getRefreshToken() != null;
    bool firebaseReady = repo.isSignedIn;
    if (!firebaseReady && !hasRefreshToken) {
      log('No refresh token — waiting for Firebase auth restore…', name: 'AUTH');
      try {
        final user = await FirebaseAuth.instance
            .authStateChanges()
            .firstWhere((user) => user != null)
            .timeout(const Duration(seconds: 10));
        firebaseReady = user != null;
        log('Firebase auth restored: uid=${user?.uid}', name: 'AUTH');
      } catch (e) {
        // Timeout or no user — Firebase genuinely has no session
        log('Firebase auth not restored (timeout or no session): $e', name: 'AUTH');
        firebaseReady = false;
      }
    }
    if (!firebaseReady && !apiClient.hasToken && !hasRefreshToken) {
      log('No Firebase user, no access token, no refresh token — truly signed out', name: 'AUTH');
      return;
    }

    if (!firebaseReady) {
      log('Proceeding without Firebase (refresh token or stored access token available)', name: 'AUTH');
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      // 1. Force-refresh the Firebase token
      await repo.refreshToken();

      // 2. Fetch profile from backend with the fresh token
      final user = await repo.getMyProfile();

      // 3. Reconnect WebSocket with the fresh JWT access token
      final token = HiveStorage.getToken();
      if (token != null) {
        ref.read(webSocketServiceProvider).connect(token);
      }

      // 4. Start WS event handler
      ref.read(wsEventHandlerProvider);

      // 5. Register FCM token
      final notifService = ref.read(notificationServiceProvider);
      final notifRepo = ref.read(notificationRepoProvider);
      notifService.registerTokenWithBackend(notifRepo);

      return user;
    });

    if (state.hasValue && state.value != null) {
      // ── Success: ensure router knows we're logged in ──────────────────
      log('Session restored successfully', name: 'AUTH');
      ref.read(authNotifierProvider).login();
    } else if (state.hasError) {
      // ── Failure: only logout on definitive auth errors ────────────────
      final error = state.error;
      final isAuthError = error is ServerFailure &&
          (error.message.contains('Invalid token') ||
           error.message.contains('INVALID_ID_TOKEN') ||
           error.message.contains('USER_NOT_FOUND'));

      if (isAuthError) {
        log('Definitive auth failure during restore, forcing logout', name: 'AUTH');
        await apiClient.clearToken();
        ref.read(authNotifierProvider).logout();
        state = const AsyncValue.data(null);
      } else {
        // Network error, timeout, etc. — keep error state so SessionGate
        // shows Retry button. Do NOT logout — user can retry when network
        // is back, or lifecycle handler will retry automatically.
        log('Recoverable error during restore (keeping session): $error', name: 'AUTH');
      }
    }
  }

  /// Returns a valid JWT access token, refreshing via the backend if needed.
  /// Call this from the lifecycle resume handler before reconnecting WebSocket.
  Future<String?> getAndRefreshToken() async {
    try {
      await ref.read(authRepoProvider).refreshToken(); // uses backend refresh token
      return HiveStorage.getToken();
    } catch (e) {
      log('getAndRefreshToken failed: $e', name: 'AUTH');
      return HiveStorage.getToken(); // return whatever we have; WS will retry on failure
    }
  }

  /// Update the user object in state after profile setup or username set.
  /// Called by profile setup flow to keep state fresh without a full re-fetch.
  void updateUser(UserModel updatedUser) {
    state = AsyncValue.data(updatedUser);
  }

  /// Update the logged-in user's following count locally by an offset (+1 or -1).
  void updateFollowingCount(int offset) {
    state.whenData((user) {
      if (user != null) {
        state = AsyncValue.data(user.copyWith(
          followingCount: (user.followingCount + offset).clamp(0, 999999),
        ));
      }
    });
  }
}
