import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/core/constants/api_endpoints.dart';
import 'package:chatbee/core/network/api_client.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';
import 'package:chatbee/features/profile/models/user_search_result.dart';

part 'feed_repo.g.dart';

class FeedRepo {
  final ApiClient apiClient;
  FeedRepo({required this.apiClient});

  Future<PoemsPage> getHomeFeed({int limit = 20, int offset = 0}) async {
    final query = <String, dynamic>{'limit': limit, 'offset': offset};
    final response = await apiClient.get(
      ApiEndpoints.homeFeed,
      queryParameters: query,
    );

    // Normalize backend variations for the "liked" flag so UI gets `isLikedByMe`.
    final raw = response.data as Map<String, dynamic>;
    final rawList = (raw['poems'] as List<dynamic>?) ?? [];
    final normalized = rawList.map((e) {
      if (e is Map<String, dynamic>) {
        final copy = Map<String, dynamic>.from(e);
        if (!copy.containsKey('isLikedByMe')) {
          if (copy.containsKey('liked'))
            copy['isLikedByMe'] = copy['liked'];
          else if (copy.containsKey('likedByMe'))
            copy['isLikedByMe'] = copy['likedByMe'];
          else if (copy.containsKey('liked_by_me'))
            copy['isLikedByMe'] = copy['liked_by_me'];
        }
        return copy;
      }
      return e;
    }).toList();

    final normalizedData = Map<String, dynamic>.from(raw);
    normalizedData['poems'] = normalized;

    return PoemsPage.fromJson(normalizedData);
  }

  Future<PoemsPage> getExploreFeed({
    int limit = 20,
    int offset = 0,
    String? hashtag,
  }) async {
    final query = <String, dynamic>{'limit': limit, 'offset': offset};
    if (hashtag != null && hashtag.isNotEmpty) query['hashtag'] = hashtag;
    final response = await apiClient.get(
      ApiEndpoints.exploreFeed,
      queryParameters: query,
    );

    // Normalize backend variations for the "liked" flag so UI gets `isLikedByMe`.
    final raw = response.data as Map<String, dynamic>;
    final rawList = (raw['poems'] as List<dynamic>?) ?? [];
    final normalized = rawList.map((e) {
      if (e is Map<String, dynamic>) {
        final copy = Map<String, dynamic>.from(e);
        if (!copy.containsKey('isLikedByMe')) {
          if (copy.containsKey('liked'))
            copy['isLikedByMe'] = copy['liked'];
          else if (copy.containsKey('likedByMe'))
            copy['isLikedByMe'] = copy['likedByMe'];
          else if (copy.containsKey('liked_by_me'))
            copy['isLikedByMe'] = copy['liked_by_me'];
        }
        return copy;
      }
      return e;
    }).toList();

    final normalizedData = Map<String, dynamic>.from(raw);
    normalizedData['poems'] = normalized;

    return PoemsPage.fromJson(normalizedData);
  }

  Future<PoemsPage> getAudioFeed({
    int limit = 20,
    int offset = 0,
    String? hashtag,
  }) async {
    final query = <String, dynamic>{'limit': limit, 'offset': offset};
    if (hashtag != null && hashtag.isNotEmpty) query['hashtag'] = hashtag;
    final response = await apiClient.get(
      ApiEndpoints.audioFeed,
      queryParameters: query,
    );

    // Normalize backend variations for the "liked" flag so UI gets `isLikedByMe`.
    final raw = response.data as Map<String, dynamic>;
    final rawList = (raw['poems'] as List<dynamic>?) ?? [];
    final normalized = rawList.map((e) {
      if (e is Map<String, dynamic>) {
        final copy = Map<String, dynamic>.from(e);
        if (!copy.containsKey('isLikedByMe')) {
          if (copy.containsKey('liked'))
            copy['isLikedByMe'] = copy['liked'];
          else if (copy.containsKey('likedByMe'))
            copy['isLikedByMe'] = copy['likedByMe'];
          else if (copy.containsKey('liked_by_me'))
            copy['isLikedByMe'] = copy['liked_by_me'];
        }
        return copy;
      }
      return e;
    }).toList();

    final normalizedData = Map<String, dynamic>.from(raw);
    normalizedData['poems'] = normalized;

    return PoemsPage.fromJson(normalizedData);
  }

  Future<PoemsPage> searchPoems(
    String q, {
    int limit = 20,
    int offset = 0,
  }) async {
    final query = <String, dynamic>{'q': q, 'limit': limit, 'offset': offset};
    final response = await apiClient.get(
      ApiEndpoints.searchPoems,
      queryParameters: query,
    );

    // Normalize backend variations for the "liked" flag so UI gets `isLikedByMe`.
    final raw = response.data as Map<String, dynamic>;
    final rawList = (raw['poems'] as List<dynamic>?) ?? [];
    final normalized = rawList.map((e) {
      if (e is Map<String, dynamic>) {
        final copy = Map<String, dynamic>.from(e);
        if (!copy.containsKey('isLikedByMe')) {
          if (copy.containsKey('liked'))
            copy['isLikedByMe'] = copy['liked'];
          else if (copy.containsKey('likedByMe'))
            copy['isLikedByMe'] = copy['likedByMe'];
          else if (copy.containsKey('liked_by_me'))
            copy['isLikedByMe'] = copy['liked_by_me'];
        }
        return copy;
      }
      return e;
    }).toList();

    final normalizedData = Map<String, dynamic>.from(raw);
    normalizedData['poems'] = normalized;

    return PoemsPage.fromJson(normalizedData);
  }

  Future<UserSearchPage> searchUsers(
    String q, {
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await apiClient.get(
      ApiEndpoints.searchUsers,
      queryParameters: {'q': q, 'limit': limit, 'offset': offset},
    );
    return UserSearchPage.fromJson(response.data as Map<String, dynamic>);
  }
}

@riverpod
FeedRepo feedRepo(Ref ref) {
  return FeedRepo(apiClient: ref.read(apiClientProvider));
}
