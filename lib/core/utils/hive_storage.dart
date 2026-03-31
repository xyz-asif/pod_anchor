import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:developer';

/// Hive-based persistent storage for auth tokens and session flags.
/// Uses synchronous writes to ensure data is persisted immediately.
class HiveStorage {
  static const String _authBoxName = 'auth';
  static const String _tokenKey = 'auth_token';
  static const String _sessionExistsKey = 'session_exists';
  
  static Box? _authBox;
  
  /// Initialize Hive
  static Future<void> init() async {
    await Hive.initFlutter();
    _authBox = await Hive.openBox(_authBoxName);
    log('Hive initialized and auth box opened', name: 'HIVE');
  }
  
  /// Save auth token synchronously
  static Future<void> setToken(String token) async {
    if (_authBox == null) await init();
    await _authBox!.put(_tokenKey, token);
    log('Token saved to Hive', name: 'HIVE');
  }
  
  /// Get auth token
  static String? getToken() {
    if (_authBox == null) return null;
    return _authBox!.get(_tokenKey) as String?;
  }
  
  /// Clear token
  static Future<void> clearToken() async {
    if (_authBox == null) return;
    await _authBox!.delete(_tokenKey);
    log('Token cleared from Hive', name: 'HIVE');
  }
  
  /// Check if token exists
  static bool hasToken() {
    return getToken() != null;
  }
  
  /// Set session exists flag synchronously
  static Future<void> setSessionExists(bool exists) async {
    if (_authBox == null) await init();
    await _authBox!.put(_sessionExistsKey, exists);
    log('Session flag set to: $exists in Hive', name: 'HIVE');
  }
  
  /// Get session exists flag
  static bool getSessionExists() {
    if (_authBox == null) return false;
    return _authBox!.get(_sessionExistsKey) as bool? ?? false;
  }
  
  /// Clear all auth data (for logout)
  static Future<void> clearAll() async {
    if (_authBox == null) return;
    await _authBox!.clear();
    log('All auth data cleared from Hive', name: 'HIVE');
  }
}
