import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/core/constants/api_endpoints.dart';
import 'package:chatbee/core/network/api_client.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';

part 'poem_repo.g.dart';

class CreatePoemRequest {
  final String title;
  final String contentJson;
  final String plainText;
  final List<String> hashtags;
  final String mood;
  final bool isOriginal;
  final String visibility; // "public" | "private"
  final String audioUrl;
  final int audioDuration;
  final String coverColor;

  const CreatePoemRequest({
    required this.title,
    required this.contentJson,
    required this.plainText,
    this.hashtags = const [],
    this.mood = '',
    this.isOriginal = false,
    required this.visibility,
    this.audioUrl = '',
    this.audioDuration = 0,
    this.coverColor = '',
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'contentJson': contentJson,
    'plainText': plainText,
    'hashtags': hashtags,
    'mood': mood,
    'isOriginal': isOriginal,
    'visibility': visibility,
    'audioUrl': audioUrl,
    'audioDuration': audioDuration,
    'coverColor': coverColor,
  };
}

class PoemRepo {
  final ApiClient apiClient;

  PoemRepo({required this.apiClient});

  Future<PoemModel> createPoem(CreatePoemRequest request) async {
    final response = await apiClient.post(
      ApiEndpoints.poems,
      data: request.toJson(),
    );
    return PoemModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PoemModel> getPoem(String poemId) async {
    final response = await apiClient.get(ApiEndpoints.poem(poemId));
    return PoemModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PoemModel> updatePoem(String poemId, CreatePoemRequest request) async {
    final response = await apiClient.patch(
      ApiEndpoints.poem(poemId),
      data: request.toJson(),
    );
    return PoemModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deletePoem(String poemId) async {
    await apiClient.delete(ApiEndpoints.poem(poemId));
  }

  Future<PoemsPage> getMyPoems({int limit = 20, String? before}) async {
    final query = <String, dynamic>{'limit': limit};
    if (before != null) query['before'] = before;
    final response = await apiClient.get(
      ApiEndpoints.myPoems,
      queryParameters: query,
    );

    // Normalize backend variations for the "liked" flag so UI gets `isLikedByMe`.
    // Some backend responses may use keys like `liked`, `likedByMe`, or `liked_by_me`.
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

  Future<PoemsPage> getUserPoems(
    String userId, {
    int limit = 20,
    String? before,
  }) async {
    final query = <String, dynamic>{'limit': limit};
    if (before != null) query['before'] = before;
    final response = await apiClient.get(
      ApiEndpoints.userPoems(userId),
      queryParameters: query,
    );

    // Normalize backend variations for the "liked" flag so UI gets `isLikedByMe`.
    // Some backend responses may use keys like `liked`, `likedByMe`, or `liked_by_me`.
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
}

@riverpod
PoemRepo poemRepo(PoemRepoRef ref) {
  return PoemRepo(apiClient: ref.read(apiClientProvider));
}
