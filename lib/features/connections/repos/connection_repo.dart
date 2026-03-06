import 'package:chatbee/core/constants/api_endpoints.dart';
import 'package:chatbee/core/network/api_client.dart';
import 'package:chatbee/features/connections/models/connection_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connection_repo.g.dart';

/// Handles all friend-request / connection API calls.
/// No try-catch — ApiClient handles errors.
class ConnectionRepo {
  final ApiClient apiClient;

  ConnectionRepo({required this.apiClient});

  /// Send a friend request to a user.
  Future<ConnectionModel> sendRequest(String receiverId) async {
    final response = await apiClient.post(
      ApiEndpoints.connectionRequest,
      data: {'receiverId': receiverId},
    );
    return ConnectionModel.fromJson(response.data);
  }

  /// Accept a pending friend request.
  Future<void> acceptRequest(String connectionId) async {
    await apiClient.post(
      ApiEndpoints.connectionAccept(connectionId),
    );
  }

  /// Reject a pending friend request.
  Future<void> rejectRequest(String connectionId) async {
    await apiClient.post(
      ApiEndpoints.connectionReject(connectionId),
    );
  }

  /// List pending requests received by the current user.
  Future<List<ConnectionModel>> getPendingRequests() async {
    final response = await apiClient.get(ApiEndpoints.connectionsPending);
    final list = response.data as List;
    return list
        .map((e) => ConnectionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// List all accepted friends.
  Future<List<ConnectionModel>> getFriends() async {
    final response = await apiClient.get(ApiEndpoints.connectionsFriends);
    final list = response.data as List;
    return list
        .map((e) => ConnectionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

/// Riverpod provider for ConnectionRepo.
@riverpod
ConnectionRepo connectionRepo(ConnectionRepoRef ref) {
  return ConnectionRepo(apiClient: ref.read(apiClientProvider));
}
