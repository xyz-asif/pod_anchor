# Auth Feature Audit v2 — ChatBee Flutter App

> **Scope**: Login flow, token management, session restore, sign-out, lifecycle
> **Files**: `auth_controller.dart`, `auth_repo.dart`, `auth_provider.dart`, `login_view.dart`, `api_client.dart`, `app.dart`, `main.dart`
> **Target IDE**: Antigravity / Windsurf / Cursor

---

## Summary

The auth flow works but has several issues that will cause real user-facing bugs: a race condition during session restore, missing error recovery on Google Sign-In cancellation, token storage in plaintext SharedPreferences, and no automatic token refresh. This audit lists 10 fixes ordered by severity. Apply them in order.

---

## Fixes

---

### 1. CRITICAL — Google Sign-In cancellation crashes the app

**File**: `features/auth/repos/auth_repo.dart`

**Problem**: When the user cancels the Google Sign-In dialog (taps outside or presses back), `_googleSignIn.authenticate()` throws a PlatformException. This propagates to the UI as a red error snackbar with a raw exception message.

**Fix**: Add a custom exception and catch cancellation in the repo:

In `core/errors/failures.dart`, add:

```dart
/// Thrown when user cancels Google Sign-In. Not a real error.
class SignInCancelledException implements Exception {
  const SignInCancelledException();
  @override
  String toString() => 'Sign-in was cancelled';
}
```

In `auth_repo.dart`, wrap the authenticate call:

```dart
Future<UserModel> signInWithGoogle() async {
    await initialize();

    try {
      final googleUser = await _googleSignIn.authenticate();
    } catch (e) {
      if (e.toString().contains('canceled') || 
          e.toString().contains('cancelled') ||
          e.toString().contains('sign_in_canceled')) {
        throw const SignInCancelledException();
      }
      rethrow;
    }

    // ... rest of the method unchanged ...
}
```

In `auth_controller.dart`, handle cancellation OUTSIDE `AsyncValue.guard` so state doesn't transition:

```dart
Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final user = await ref.read(authRepoProvider).signInWithGoogle();

      // Connect WebSocket
      final token = await ref.read(authRepoProvider).getIdToken();
      if (token != null) {
        ref.read(webSocketServiceProvider).connect(token);
      }

      ref.read(wsEventHandlerProvider);
      ref.read(authNotifierProvider).login();

      // Register FCM token
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
```

Import `SignInCancelledException` from `core/errors/failures.dart`.

---

### 2. CRITICAL — Session restore race condition can show blank/wrong screen

**File**: `main.dart`, `auth_controller.dart`, `app_router.dart`

**Problem**: On app start, `authNotifier.init()` sets `isLoggedIn = true` if a token exists. GoRouter's redirect fires immediately and reads `authControllerProvider.valueOrNull` to check `isProfileSetup` — but it's `null` because `restoreSession()` hasn't completed. This can redirect to `/profile-setup` for already-setup users, or show a blank screen.

If `restoreSession()` fails (no internet, server down), the user is stuck with no way to retry or sign out.

**Fix**: Instead of handling loading complexity in the router redirect, create a SessionGate widget that wraps the home screen. The router should only handle login/logout redirects.

**Step A** — Simplify the router redirect (remove profile-setup logic from here):

```dart
// In app_router.dart:
redirect: (context, state) {
    final isLoggedIn = authNotifier.isLoggedIn;
    final currentPath = state.matchedLocation;

    // Not logged in → login screen
    if (!isLoggedIn) {
      if (currentPath == '/login') return null;
      return '/login';
    }

    // Logged in → don't show login
    if (currentPath == '/login') return '/home';

    return null;
},
```

**Step B** — Create a `SessionGate` widget that handles loading, errors, and profile-setup checks:

Create a new file `features/auth/widgets/session_gate.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/features/auth/controllers/auth_controller.dart';

/// Wraps the home screen. Handles:
/// - Loading state during session restore (shows spinner)
/// - Error state (shows retry + sign-out)
/// - Profile setup redirect (if profile not completed)
class SessionGate extends ConsumerWidget {
  final Widget child;
  const SessionGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return authState.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off_rounded, size: 64.r, color: AppTheme.textLightColor),
                SizedBox(height: 16.h),
                Text(
                  'Could not restore session',
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8.h),
                Text(
                  e.toString(),
                  style: TextStyle(fontSize: 13.sp, color: AppTheme.textMediumColor),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24.h),
                ElevatedButton(
                  onPressed: () => ref.read(authControllerProvider.notifier).restoreSession(),
                  child: const Text('Retry'),
                ),
                SizedBox(height: 8.h),
                TextButton(
                  onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
                  child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (user) {
        if (user == null) {
          // Still loading or signed out — show spinner briefly
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // Check profile setup
        if (!user.isProfileSetup) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/profile-setup');
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // Check username setup
        if (user.username == null || user.username!.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/username-setup');
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        return child;
      },
    );
  }
}
```

**Step C** — Wrap the home route with SessionGate:

```dart
// In app_router.dart:
GoRoute(
    path: '/home',
    builder: (context, state) => const SessionGate(child: HomeScreen()),
),
```

---

### 3. HIGH — Token stored in SharedPreferences (not secure)

**File**: `core/network/api_client.dart`, `core/providers/auth_provider.dart`

**Problem**: Firebase ID tokens are stored in `SharedPreferences` — plain text on Android, readable with root access or backup extraction.

**Fix**: Replace with `flutter_secure_storage`.

In `api_client.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
    final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
    static const String _tokenKey = 'auth_token';

    // Replace all _prefs!.getString/_prefs!.setString/_prefs!.remove with:
    
    Future<void> initialize() async {
      final token = await _secureStorage.read(key: _tokenKey);
      if (token != null) {
        _dio.options.headers['Authorization'] = 'Bearer $token';
      }
    }

    Future<void> setToken(String token) async {
      _dio.options.headers['Authorization'] = 'Bearer $token';
      await _secureStorage.write(key: _tokenKey, value: token);
    }

    Future<void> clearToken() async {
      _dio.options.headers.remove('Authorization');
      await _secureStorage.delete(key: _tokenKey);
    }
}
```

Remove the `SharedPreferences? _prefs` field and all `_prefs ??= await SharedPreferences.getInstance()` calls.

In `auth_provider.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

Future<void> init() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'auth_token');
    _isLoggedIn = token != null;
    notifyListeners();
}
```

Add to `pubspec.yaml`:
```yaml
dependencies:
  flutter_secure_storage: ^9.0.0
```

---

### 4. HIGH — 401 auto-retry interceptor with infinite loop protection

**File**: `core/network/api_client.dart`

**Problem**: Firebase tokens expire after 1 hour. If the app is open but idle, the next API call fails with 401. There's no automatic retry.

**Fix**: Add a Dio interceptor that catches 401, refreshes the token, and retries — but only once (to prevent infinite loops):

```dart
// In api_client.dart constructor, add this interceptor BEFORE LogInterceptor:

_dio.interceptors.add(
  InterceptorsWrapper(
    onError: (error, handler) async {
      if (error.response?.statusCode == 401) {
        // Prevent infinite retry loop: only retry once per request
        if (error.requestOptions.extra['_retried'] == true) {
          return handler.next(error);
        }
        error.requestOptions.extra['_retried'] = true;

        try {
          final firebaseUser = FirebaseAuth.instance.currentUser;
          if (firebaseUser != null) {
            final newToken = await firebaseUser.getIdToken(true); // force refresh
            if (newToken != null) {
              await setToken(newToken);
              // Retry the failed request with new token
              error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
              final response = await _dio.fetch(error.requestOptions);
              return handler.resolve(response);
            }
          }
        } catch (_) {
          // Refresh failed — let the 401 propagate normally
        }
      }
      return handler.next(error);
    },
  ),
);
```

Add `import 'package:firebase_auth/firebase_auth.dart';` to api_client.dart.

The `extra['_retried']` flag ensures each request is only retried once. If the refreshed token also gets 401 (e.g., account disabled), the error propagates normally.

---

### 5. HIGH — Sign-out doesn't clear all user-scoped state (use cascade pattern)

**File**: `auth_controller.dart`

**Problem**: After sign-out and re-login with a different account, providers like chat list, notifications, and feed may still hold data from the previous account.

**Fix**: Instead of manually invalidating every provider (which doesn't scale and will miss new providers), use the Riverpod cascade invalidation pattern:

**Step A** — Create a session identity provider:

In `core/providers/auth_provider.dart`, add:

```dart
/// Identity token that changes on every login/logout cycle.
/// Any provider that holds user-specific data should ref.watch this.
/// When it changes (on logout), all watchers auto-rebuild.
final userSessionProvider = StateProvider<int>((ref) => 0);
```

**Step B** — In every user-scoped keepAlive provider, watch it:

```dart
// In chat_list_controller.dart build():
@override
FutureOr<List<RoomResponse>> build() async {
    ref.watch(userSessionProvider);  // ADD THIS LINE — rebuilds on logout
    // ... rest unchanged
}

// Do the same in:
// - notification_controller.dart build()
// - unread_notification_count_provider build()
// - home_feed_controller.dart build()
// - explore_feed_controller.dart build()
// - audio_feed_controller.dart build()
// - my_poems_controller.dart build()
// - friends_controller.dart build() (already watches authControllerProvider, but add this too)
```

**Step C** — On sign-out, bump the session counter:

```dart
// In auth_controller.dart signOut():
Future<void> signOut() async {
    ref.read(webSocketServiceProvider).disconnect();
    await ref.read(authRepoProvider).signOut();
    state = const AsyncValue.data(null);
    ref.read(authNotifierProvider).logout();

    // Cascade-clear all user-scoped providers in one line
    ref.read(userSessionProvider.notifier).state++;
}
```

This automatically rebuilds (and effectively clears) every provider that watches `userSessionProvider`. No manual list to maintain.

---

### 6. HIGH — restoreSession has no error recovery

**File**: `auth_controller.dart`

**Problem**: If `restoreSession()` fails (network error, backend down), the state becomes `AsyncValue.error` but nothing in the UI recovers from it. With the SessionGate from fix #2, this is now handled — but the controller should also log the failure clearly.

**Fix**: Add logging to restoreSession (the SessionGate from fix #2 handles the UI):

```dart
Future<void> restoreSession() async {
    final repo = ref.read(authRepoProvider);
    final apiClient = ref.read(apiClientProvider);
    
    if (!repo.isSignedIn && !apiClient.hasToken) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      try {
        if (repo.isSignedIn) {
          await repo.refreshToken();
        }
        final user = await repo.getMyProfile();

        final token = repo.isSignedIn 
            ? await repo.getIdToken() 
            : apiClient.currentToken;
        if (token != null) {
          ref.read(webSocketServiceProvider).connect(token);
        }

        return user;
      } catch (e) {
        log('Session restore failed: $e', name: 'AUTH');
        rethrow;
      }
    });
}
```

Add `import 'dart:developer';` if not present.

---

### 7. MEDIUM — ApiClient singleton prevents testing

**File**: `core/network/api_client.dart`

**Problem**: `ApiClient` uses a static `_instance` singleton. The Riverpod provider wraps it but `factory ApiClient()` always returns the same instance. This makes mocking impossible in tests.

**Fix**: Remove the singleton pattern, let Riverpod manage lifecycle:

```dart
// DELETE these:
// static final ApiClient _instance = ApiClient._internal();
// ApiClient._internal() { ... }
// factory ApiClient() { return _instance; }

// REPLACE with a normal constructor:
class ApiClient {
    late final Dio _dio;
    final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
    static const String _tokenKey = 'auth_token';

    ApiClient() {
      _dio = Dio(
        BaseOptions(
          baseUrl: ApiEndpoints.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      
      // Add 401 retry interceptor (from fix #4) here
      
      _dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true),
      );
    }
    
    // ... rest of methods unchanged ...
}

// Make provider keepAlive so it acts as a singleton at runtime:
@Riverpod(keepAlive: true)
ApiClient apiClient(ApiClientRef ref) {
    return ApiClient();
}
```

In `main.dart`, the existing `container.read(apiClientProvider)` call already works correctly with this change.

---

### 8. MEDIUM — Missing haptic feedback on login button

**File**: `features/auth/views/login_view.dart`

**Problem**: The login button doesn't provide haptic feedback on tap. Other buttons in the app include `HapticFeedback.lightImpact()` for consistency.

**Fix**:

```dart
import 'package:flutter/services.dart';

// In the ElevatedButton.icon onPressed:
onPressed: isLoading
    ? null
    : () {
        HapticFeedback.mediumImpact();  // ADD THIS
        ref.read(authControllerProvider.notifier).signInWithGoogle();
      },
```

---

### 9. LOW — Replace print() with dart:developer log()

**Files**: `auth_repo.dart`, `api_client.dart`, `main.dart`

**Problem**: ~20 `print()` calls in the auth flow will appear in release builds. `dart:developer log()` is automatically stripped in release mode and supports filtering.

**Fix**: Globally search and replace in these files:

```dart
// Replace all occurrences like:
print('🔐 Starting Google Sign-In...');
// With:
log('Starting Google Sign-In', name: 'AUTH');

print('✅ Firebase sign-in successful');
// With:
log('Firebase sign-in successful', name: 'AUTH');

print('💾 Saving token to API client...');
// With:
log('Saving token to API client', name: 'AUTH');
```

Add `import 'dart:developer';` to each file.

Do this for ALL print() statements in: `auth_repo.dart`, `api_client.dart`, `main.dart`, `auth_controller.dart`.

---

### 10. LOW — Login screen no-internet error is not user-friendly

**File**: `features/auth/repos/auth_repo.dart`

**Problem**: With no internet, the user sees a raw `SocketException` message in the error snackbar.

**Fix**: Catch network errors and throw a friendly message:

```dart
import 'dart:io' show SocketException;
import 'dart:async' show TimeoutException;

Future<UserModel> signInWithGoogle() async {
    await initialize();

    try {
      final googleUser = await _googleSignIn.authenticate();
      // ... rest of the method ...
    } on SignInCancelledException {
      rethrow;
    } on SocketException {
      throw const NetworkFailure('No internet connection. Please check your network and try again.');
    } on TimeoutException {
      throw const NetworkFailure('Connection timed out. Please try again.');
    } catch (e) {
      // Check for other cancel patterns
      if (e.toString().contains('canceled') || e.toString().contains('cancelled')) {
        throw const SignInCancelledException();
      }
      rethrow;
    }
}
```

---

## Verification Checklist

After applying all fixes:

- [ ] Tap Sign In → cancel Google dialog → no error shown, button re-enables
- [ ] Sign in → kill app → reopen → session restores (shows spinner then home)
- [ ] Sign in → kill app → reopen with no internet → shows retry + sign-out screen
- [ ] Sign in → wait 65 minutes idle → make API call → auto-refreshes token, no error
- [ ] Sign in → sign out → sign in with different account → chat list, feed, notifications all fresh (no stale data)
- [ ] Turn off WiFi → tap Sign In → shows "No internet connection" (not raw exception)
- [ ] Check release build → no print statements in console output
- [ ] Profile-setup redirect works correctly after fresh Google sign-in
