import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Identity token that changes on every login/logout cycle.
/// Any provider that holds user-specific data should ref.watch this.
/// When it changes (on logout), all watchers auto-rebuild.
final userSessionProvider = StateProvider<int>((ref) => 0);

/// Notifier that tracks whether the user is logged in.
/// Reads the persisted token on startup; updated by AuthController on login/logout.
class AuthNotifier extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  /// Call once at startup to check if the user has a session.
  /// Checks both secure storage (stored token) AND Firebase Auth (persisted session).
  /// If either indicates a session exists, the user is treated as logged in so that
  /// restoreSession() gets a chance to run. This prevents false logouts when
  /// Android clears secure storage but Firebase retains the session.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final hasFirebaseUser = FirebaseAuth.instance.currentUser != null;
    _isLoggedIn = token != null || hasFirebaseUser;
    notifyListeners();
  }

  void login() {
    _isLoggedIn = true;
    notifyListeners();
  }

  void logout() {
    _isLoggedIn = false;
    notifyListeners();
  }
}

/// Global provider — used by GoRouter's refreshListenable + redirect.
final authNotifierProvider = ChangeNotifierProvider<AuthNotifier>((ref) {
  return AuthNotifier();
});
