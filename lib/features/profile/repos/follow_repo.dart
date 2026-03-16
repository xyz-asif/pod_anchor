import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/core/constants/api_endpoints.dart';
import 'package:chatbee/core/network/api_client.dart';
import 'package:chatbee/features/profile/models/public_profile_model.dart';
import 'package:chatbee/features/profile/models/user_search_result.dart';

part 'follow_repo.g.dart';

class FollowRepo {
  final ApiClient apiClient;
  FollowRepo({required this.apiClient});

  /// Toggle follow/unfollow. 
  /// Since the backend has separate endpoints, we need to know the current state.
  /// If isFollowing is provided, we use it to decide.
  Future<bool> toggleFollow(String userId, {bool currentlyFollowing = false}) async {
    // The backend POST endpoint follows, and returns 409 if already following.
    // Unfollow should trigger a DELETE request to the same endpoint.
    if (currentlyFollowing) {
      await apiClient.delete(ApiEndpoints.userFollow(userId));
    } else {
      await apiClient.post(ApiEndpoints.userFollow(userId));
    }
    return !currentlyFollowing;
  }

  /// Get another user's public profile including isFollowedByMe.
  Future<PublicProfileModel> getPublicProfile(String userId) async {
    final response = await apiClient.get(ApiEndpoints.userProfile(userId));
    return PublicProfileModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Get followers of a user.
  Future<UserSearchPage> getFollowers(String userId,
      {int limit = 20, String? before}) async {
    final query = <String, dynamic>{'limit': limit};
    if (before != null) query['before'] = before;
    final response = await apiClient
        .get(ApiEndpoints.userFollowers(userId), queryParameters: query);
    
    // Defensive handling if backend returns List instead of Map
    if (response.data is List) {
      final list = response.data as List;
      return UserSearchPage(
        users: list.map((e) => UserSearchResult.fromJson(e as Map<String, dynamic>)).toList(),
        hasMore: false,
      );
    }
    return UserSearchPage.fromJson(response.data as Map<String, dynamic>);
  }

  /// Get users that a user follows.
  Future<UserSearchPage> getFollowing(String userId,
      {int limit = 20, String? before}) async {
    final query = <String, dynamic>{'limit': limit};
    if (before != null) query['before'] = before;
    final response = await apiClient
        .get(ApiEndpoints.userFollowing(userId), queryParameters: query);

    // Defensive handling
    if (response.data is List) {
      final list = response.data as List;
      return UserSearchPage(
        users: list.map((e) => UserSearchResult.fromJson(e as Map<String, dynamic>)).toList(),
        hasMore: false,
      );
    }
    return UserSearchPage.fromJson(response.data as Map<String, dynamic>);
  }
}

@riverpod
FollowRepo followRepo(Ref ref) {
  return FollowRepo(apiClient: ref.read(apiClientProvider));
}
