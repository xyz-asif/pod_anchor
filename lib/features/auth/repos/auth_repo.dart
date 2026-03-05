import 'package:chatbee/core/constants/api_endpoints.dart';
import 'package:chatbee/core/network/api_client.dart';
import 'package:chatbee/features/auth/models/user_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_repo.g.dart';

/// Handles all auth-related API calls.
/// No try-catch here — ApiClient handles all errors.
/// If something fails, Failure is thrown and Controller catches it.
class AuthRepo {
  final ApiClient apiClient;

  AuthRepo({required this.apiClient});

  /// Login with email and password.
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.login,
      data: {'email': email, 'password': password},
    );

    final user = UserModel.fromJson(response.data);

    if (user.token != null) {
      apiClient.setToken(user.token!);
    }

    return user;
  }

  /// Register a new user.
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.register,
      data: {'name': name, 'email': email, 'password': password},
    );

    return UserModel.fromJson(response.data);
  }
}

/// Riverpod provider for AuthRepo.
@riverpod
AuthRepo authRepo(AuthRepoRef ref) {
  return AuthRepo(apiClient: ref.read(apiClientProvider));
}
