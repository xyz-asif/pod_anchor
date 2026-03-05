import 'package:chatbee/core/constants/api_endpoints.dart';
import 'package:chatbee/core/network/api_client.dart';
import 'package:chatbee/features/auth/models/user_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_repo.g.dart';

/// Handles user profile and search API calls.
/// No try-catch here — ApiClient handles all errors.
class UserRepo {
  final ApiClient apiClient;

  UserRepo({required this.apiClient});

  /// Get current user's profile.
  Future<UserModel> getMyProfile() async {
    final response = await apiClient.get(ApiEndpoints.usersMe);
    return UserModel.fromJson(response.data);
  }

  /// Update current user's profile.
  /// Only send fields you want to change.
  Future<UserModel> updateMyProfile({
    String? displayName,
    String? photoURL,
    String? bio,
  }) async {
    final data = <String, dynamic>{};
    if (displayName != null) data['displayName'] = displayName;
    if (photoURL != null) data['photoURL'] = photoURL;
    if (bio != null) data['bio'] = bio;

    final response = await apiClient.patch(ApiEndpoints.usersMe, data: data);
    return UserModel.fromJson(response.data);
  }

  /// Search users by name or email.
  Future<List<UserModel>> searchUsers({
    required String query,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await apiClient.get(
      ApiEndpoints.usersSearch,
      queryParameters: {'q': query, 'limit': limit, 'offset': offset},
    );

    final list = response.data as List;
    return list
        .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

/// Riverpod provider for UserRepo.
@riverpod
UserRepo userRepo(UserRepoRef ref) {
  return UserRepo(apiClient: ref.read(apiClientProvider));
}
