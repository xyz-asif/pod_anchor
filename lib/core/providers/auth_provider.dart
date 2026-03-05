import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final authStateProvider = FutureProvider<bool>((ref) async {
  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'auth_token');
  return token != null;
});
