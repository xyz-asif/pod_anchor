import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Notifier that tracks whether the user is logged in.
/// Reads the persisted token on startup; updated by AuthController on login/logout.
class AuthNotifier extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  /// Call once at startup to check if a token already exists.
  Future<void> init() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'auth_token');
    _isLoggedIn = token != null;
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
