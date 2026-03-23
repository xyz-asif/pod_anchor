import 'package:json_annotation/json_annotation.dart';

part 'poem_model.g.dart';

@JsonSerializable()
class PoemAuthor {
  final String id;
  final String displayName;
  final String username;
  final String photoURL;
  final bool isEditor;

  const PoemAuthor({
    required this.id,
    required this.displayName,
    required this.username,
    required this.photoURL,
    this.isEditor = false,
  });

  factory PoemAuthor.fromJson(Map<String, dynamic> json) => _$PoemAuthorFromJson(json);
  Map<String, dynamic> toJson() => _$PoemAuthorToJson(this);
}

@JsonSerializable()
class MentionedUser {
  final String id;
  final String username;
  final String displayName;
  final String photoURL;

  const MentionedUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.photoURL,
  });

  factory MentionedUser.fromJson(Map<String, dynamic> json) => _$MentionedUserFromJson(json);
  Map<String, dynamic> toJson() => _$MentionedUserToJson(this);
}

@JsonSerializable()
class PoemModel {
  final String id;
  final PoemAuthor author;
  final String title;
  final String contentJson;   // Quill Delta JSON string
  final String plainText;
  final List<String> hashtags;
  @JsonKey(defaultValue: '')
  final String mood;
  final bool isOriginal;
  final String visibility;    // "public" | "private"
  @JsonKey(defaultValue: '')
  final String audioUrl;
  @JsonKey(defaultValue: 0)
  final int audioDuration;    // seconds
  @JsonKey(defaultValue: '')
  final String coverColor;
  @JsonKey(defaultValue: '')
  final String description;
  @JsonKey(defaultValue: 'left')
  final String textAlign;
  @JsonKey(defaultValue: [])
  final List<MentionedUser> mentions;
  final int likesCount;
  final int commentsCount;
  final int repostsCount;
  @JsonKey(defaultValue: false)
  final bool isLikedByMe;
  @JsonKey(defaultValue: false)
  final bool isRepostedByMe;
  @JsonKey(defaultValue: false)
  final bool isRepost;
  final PoemModel? originalPoem;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PoemModel({
    required this.id,
    required this.author,
    required this.title,
    required this.contentJson,
    required this.plainText,
    this.hashtags = const [],
    this.mood = '',
    this.isOriginal = false,
    this.visibility = 'public',
    this.audioUrl = '',
    this.audioDuration = 0,
    this.coverColor = '',
    this.description = '',
    this.textAlign = 'left',
    this.mentions = const [],
    this.likesCount = 0,
    this.commentsCount = 0,
    this.repostsCount = 0,
    this.isLikedByMe = false,
    this.isRepostedByMe = false,
    this.isRepost = false,
    this.originalPoem,
    this.createdAt,
    this.updatedAt,
  });

  factory PoemModel.fromJson(Map<String, dynamic> json) => _$PoemModelFromJson(json);
  Map<String, dynamic> toJson() => _$PoemModelToJson(this);

  bool get isDraft => visibility == 'private';
  bool get isPublic => visibility == 'public';
  bool get hasAudio => audioUrl.isNotEmpty;

  PoemModel copyWith({
    String? id,
    PoemAuthor? author,
    String? title,
    String? contentJson,
    String? plainText,
    List<String>? hashtags,
    String? mood,
    bool? isOriginal,
    String? visibility,
    String? audioUrl,
    int? audioDuration,
    String? coverColor,
    String? description,
    String? textAlign,
    List<MentionedUser>? mentions,
    int? likesCount,
    int? commentsCount,
    int? repostsCount,
    bool? isLikedByMe,
    bool? isRepostedByMe,
    bool? isRepost,
    PoemModel? originalPoem,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PoemModel(
      id: id ?? this.id,
      author: author ?? this.author,
      title: title ?? this.title,
      contentJson: contentJson ?? this.contentJson,
      plainText: plainText ?? this.plainText,
      hashtags: hashtags ?? this.hashtags,
      mood: mood ?? this.mood,
      isOriginal: isOriginal ?? this.isOriginal,
      visibility: visibility ?? this.visibility,
      audioUrl: audioUrl ?? this.audioUrl,
      audioDuration: audioDuration ?? this.audioDuration,
      coverColor: coverColor ?? this.coverColor,
      description: description ?? this.description,
      textAlign: textAlign ?? this.textAlign,
      mentions: mentions ?? this.mentions,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      repostsCount: repostsCount ?? this.repostsCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      isRepostedByMe: isRepostedByMe ?? this.isRepostedByMe,
      isRepost: isRepost ?? this.isRepost,
      originalPoem: originalPoem ?? this.originalPoem,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class PoemsPage {
  final List<PoemModel> poems;
  final bool hasMore;

  const PoemsPage({required this.poems, required this.hasMore});

  factory PoemsPage.fromJson(Map<String, dynamic> json) {
    final list = json['poems'] as List? ?? [];
    return PoemsPage(
      poems: list.map((e) => PoemModel.fromJson(e as Map<String, dynamic>)).toList(),
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}
