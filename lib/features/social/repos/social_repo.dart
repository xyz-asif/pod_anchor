import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/core/constants/api_endpoints.dart';
import 'package:chatbee/core/network/api_client.dart';
import 'package:chatbee/features/social/models/comment_model.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';

part 'social_repo.g.dart';

class LikeResult {
  final bool liked;
  final int likesCount;
  LikeResult({required this.liked, required this.likesCount});
  factory LikeResult.fromJson(Map<String, dynamic> json) => LikeResult(
    liked: json['liked'] as bool? ?? false,
    likesCount: json['likesCount'] as int? ?? 0,
  );
}

class RepostResult {
  final bool reposted;
  final int repostsCount;
  RepostResult({required this.reposted, required this.repostsCount});
  factory RepostResult.fromJson(Map<String, dynamic> json) => RepostResult(
    reposted: json['reposted'] as bool? ?? false,
    repostsCount: json['repostsCount'] as int? ?? 0,
  );
}

class SocialRepo {
  final ApiClient apiClient;
  SocialRepo({required this.apiClient});

  Future<LikeResult> togglePoemLike(String poemId) async {
    final response = await apiClient.post(ApiEndpoints.poemLike(poemId));
    return LikeResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<CommentsPage> getComments(String poemId, {int limit = 20, String? before}) async {
    final query = <String, dynamic>{'limit': limit};
    if (before != null) query['before'] = before;
    final response = await apiClient.get(ApiEndpoints.poemComments(poemId), queryParameters: query);
    return CommentsPage.fromJson(response.data as Map<String, dynamic>);
  }

  Future<CommentModel> addComment(String poemId, String content) async {
    final response = await apiClient.post(
      ApiEndpoints.poemComments(poemId),
      data: {'content': content},
    );
    return CommentModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteComment(String commentId) async {
    await apiClient.delete(ApiEndpoints.commentDelete(commentId));
  }

  Future<LikeResult> toggleCommentLike(String commentId) async {
    final response = await apiClient.post(ApiEndpoints.commentLike(commentId));
    return LikeResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<RepostResult> toggleRepost(String poemId) async {
    final response = await apiClient.post(ApiEndpoints.poemRepost(poemId));
    return RepostResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PoemsPage> getUserReposts(String userId, {int limit = 20, String? before}) async {
    final query = <String, dynamic>{'limit': limit};
    if (before != null) query['before'] = before;
    final response = await apiClient.get(ApiEndpoints.userReposts(userId), queryParameters: query);
    return PoemsPage.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<String>> searchUsersForMention(String query) async {
    final response = await apiClient.get(
      ApiEndpoints.searchUsers,
      queryParameters: {'q': query, 'limit': 5},
    );
    
    final dynamic data = response.data;
    List users = [];
    
    if (data is List) {
      users = data;
    } else if (data is Map<String, dynamic>) {
      users = data['users'] as List? ?? [];
    }

    return users
        .map((u) => (u as Map<String, dynamic>)['username'] as String? ?? '')
        .where((u) => u.isNotEmpty)
        .toList();
  }
}

@riverpod
SocialRepo socialRepo(Ref ref) {
  return SocialRepo(apiClient: ref.read(apiClientProvider));
}
