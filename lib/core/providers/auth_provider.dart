import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chatbee/core/utils/hive_storage.dart';

/// Identity token that changes on every login/logout cycle.
/// Any provider that holds user-specific data should ref.watch this.
/// When it changes (on logout), all watchers auto-rebuild.
final userSessionProvider = StateProvider<int>((ref) => 0);

/// Notifier that tracks whether the user is logged in.
/// Uses optimistic auth: assumes session exists if flag is set,
/// then verifies in background.
class AuthNotifier extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  static const String _sessionExistsKey = 'session_exists';

  /// Quick check for startup - returns immediately without blocking.
  /// Uses session_exists flag for instant optimistic auth.
  Future<bool> quickSessionCheck() async {
    final sessionExists = HiveStorage.getSessionExists();
    final hasToken = HiveStorage.hasToken();
    final token = HiveStorage.getToken();
    
    log('quickSessionCheck: sessionExists=$sessionExists, hasToken=$hasToken, token=${token?.substring(0, token.length > 20 ? 20 : token.length)}...', name: 'AUTH');
    
    // Optimistic: if session flag or token exists, assume logged in
    if (sessionExists || hasToken) {
      _isLoggedIn = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Call once at startup after quick check.
  /// Verifies actual Firebase session with longer timeout.
  Future<void> verifySession() async {
    final token = HiveStorage.getToken();
    
    // Wait for Firebase auth to settle (10s timeout)
    User? firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      try {
        firebaseUser = await FirebaseAuth.instance
            .authStateChanges()
            .firstWhere((u) => u != null)
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        // No Firebase session found
      }
    }

    // Update state based on actual verification
    final actuallyLoggedIn = token != null || firebaseUser != null;
    log('verifySession: token=$token, firebaseUser=$firebaseUser, actuallyLoggedIn=$actuallyLoggedIn, currentState=$_isLoggedIn', name: 'AUTH');
    
    if (_isLoggedIn != actuallyLoggedIn) {
      _isLoggedIn = actuallyLoggedIn;
      notifyListeners();
    }

    // Update session flag for next startup
    await HiveStorage.setSessionExists(actuallyLoggedIn);
    log('verifySession: updated session flag to $actuallyLoggedIn', name: 'AUTH');
  }

  /// Legacy init method - combines quick check + verify.
  /// Kept for compatibility, but prefer using quickSessionCheck() first.
  Future<void> init() async {
    final didQuickLogin = await quickSessionCheck();
    if (didQuickLogin) {
      // Verify in background without blocking
      unawaited(verifySession());
    }
  }

  /// Set session exists flag when logging in
  Future<void> setSessionExists(bool exists) async {
    await HiveStorage.setSessionExists(exists);
    log('Session flag set to: $exists (Hive sync)', name: 'AUTH');
  }

  /// Login - sets logged in state and persists session flag
  Future<void> login() async {
    _isLoggedIn = true;
    notifyListeners();
    log('login() called - setting session flag', name: 'AUTH_NOTIFIER');
    // CRITICAL: await the session flag to ensure it's written before app terminates
    await setSessionExists(true);
    log('login() - session flag persisted', name: 'AUTH_NOTIFIER');
  }

  /// Logout - clears logged in state and session flag
  Future<void> logout() async {
    _isLoggedIn = false;
    notifyListeners();
    log('logout() called - clearing session flag', name: 'AUTH_NOTIFIER');
    // await the clear to ensure it's written
    await setSessionExists(false);
  }
}

/// Global provider — used by GoRouter's refreshListenable + redirect.
final authNotifierProvider = ChangeNotifierProvider<AuthNotifier>((ref) {
  return AuthNotifier();
});
