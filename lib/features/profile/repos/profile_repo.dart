import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/core/constants/api_endpoints.dart';
import 'package:chatbee/core/network/api_client.dart';
import 'package:chatbee/features/auth/models/user_model.dart';

part 'profile_repo.g.dart';

class CheckUsernameResult {
  final String username;
  final bool available;
  final String? reason; // "taken" | "invalid_format" | "reserved" | null

  const CheckUsernameResult({
    required this.username,
    required this.available,
    this.reason,
  });

  factory CheckUsernameResult.fromJson(Map<String, dynamic> json) {
    return CheckUsernameResult(
      username: json['username'] as String? ?? '',
      available: json['available'] as bool? ?? false,
      reason: json['reason'] as String?,
    );
  }
}

class ProfileRepo {
  final ApiClient apiClient;

  ProfileRepo({required this.apiClient});

  /// Complete profile setup after first login.
  /// Called on the first screen of the setup flow.
  Future<UserModel> setupProfile({
    required String displayName,
    required String bio,
    required String externalLink,
    required String photoURL,
    required String coverImageURL,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.userSetup,
      data: {
        'displayName': displayName,
        'bio': bio,
        'externalLink': externalLink,
        'photoURL': photoURL,
        'coverImageURL': coverImageURL,
      },
    );
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Check if a username is available.
  /// Call this debounced as the user types — do not call on every keystroke raw.
  Future<CheckUsernameResult> checkUsername(String username) async {
    final response = await apiClient.get(
      ApiEndpoints.usernameCheck,
      queryParameters: {'username': username},
    );
    return CheckUsernameResult.fromJson(response.data as Map<String, dynamic>);
  }

  /// Permanently set the username. Called once on confirm tap.
  Future<UserModel> setUsername(String username) async {
    final response = await apiClient.post(
      ApiEndpoints.usernameSet,
      data: {'username': username},
    );
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }
}

@riverpod
ProfileRepo profileRepo(ProfileRepoRef ref) {
  return ProfileRepo(apiClient: ref.read(apiClientProvider));
}
