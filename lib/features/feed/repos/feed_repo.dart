import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/core/constants/api_endpoints.dart';
import 'package:chatbee/core/network/api_client.dart';
import 'package:chatbee/core/utils/poem_normalizer.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';
import 'package:chatbee/features/profile/models/user_search_result.dart';

part 'feed_repo.g.dart';

class FeedRepo {
  final ApiClient apiClient;
  FeedRepo({required this.apiClient});

  Future<PoemsPage> getHomeFeed({int limit = 20, String? before}) async {
    final query = <String, dynamic>{'limit': limit};
    if (before != null) query['before'] = before;
    final response = await apiClient.get(
      ApiEndpoints.homeFeed,
      queryParameters: query,
    );

    return normalizePoemsPage(response.data as Map<String, dynamic>);
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

    return normalizePoemsPage(response.data as Map<String, dynamic>);
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

    return normalizePoemsPage(response.data as Map<String, dynamic>);
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

    return normalizePoemsPage(response.data as Map<String, dynamic>);
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
