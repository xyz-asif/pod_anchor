import 'package:chatbee/core/constants/api_endpoints.dart';
import 'package:chatbee/core/network/api_client.dart';
import 'package:chatbee/features/search/models/user_search_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_search_repository.g.dart';

/// Handles user search with connection status and all connection actions.
/// No try-catch — ApiClient handles errors.
class UserSearchRepository {
  final ApiClient _apiClient;

  UserSearchRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Search users with connection status
  /// GET /users/search-with-status?q=&limit=&offset=
  Future<UserSearchResponse> searchUsers({
    String query = '',
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.usersSearchWithStatus,
      queryParameters: {
        'q': query,
        'limit': limit,
        'offset': offset,
      },
    );
    return UserSearchResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Send friend request
  /// POST /connections/request
  Future<void> sendFriendRequest(String userId) async {
    await _apiClient.post(
      ApiEndpoints.connectionRequest,
      data: {'receiverId': userId},
    );
  }

  /// Accept friend request
  /// POST /connections/:id/accept
  Future<void> acceptFriendRequest(String connectionId) async {
    await _apiClient.post(ApiEndpoints.connectionAccept(connectionId));
  }

  /// Reject friend request
  /// POST /connections/:id/reject
  Future<void> rejectFriendRequest(String connectionId) async {
    await _apiClient.post(ApiEndpoints.connectionReject(connectionId));
  }

  /// Cancel sent friend request
  /// POST /connections/:id/cancel
  Future<void> cancelFriendRequest(String connectionId) async {
    await _apiClient.post(ApiEndpoints.connectionCancel(connectionId));
  }

  /// Unfriend / remove connection
  /// DELETE /connections/:id
  Future<void> removeConnection(String connectionId) async {
    await _apiClient.delete(ApiEndpoints.connectionDelete(connectionId));
  }
}

@riverpod
UserSearchRepository userSearchRepository(UserSearchRepositoryRef ref) {
  return UserSearchRepository(apiClient: ref.read(apiClientProvider));
}
