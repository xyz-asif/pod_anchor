// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'poem_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PoemAuthor _$PoemAuthorFromJson(Map<String, dynamic> json) => PoemAuthor(
  id: json['id'] as String,
  displayName: json['displayName'] as String,
  username: json['username'] as String,
  photoURL: json['photoURL'] as String,
  isEditor: json['isEditor'] as bool? ?? false,
);

Map<String, dynamic> _$PoemAuthorToJson(PoemAuthor instance) =>
    <String, dynamic>{
      'id': instance.id,
      'displayName': instance.displayName,
      'username': instance.username,
      'photoURL': instance.photoURL,
      'isEditor': instance.isEditor,
    };

MentionedUser _$MentionedUserFromJson(Map<String, dynamic> json) =>
    MentionedUser(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['displayName'] as String,
      photoURL: json['photoURL'] as String,
    );

Map<String, dynamic> _$MentionedUserToJson(MentionedUser instance) =>
    <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'displayName': instance.displayName,
      'photoURL': instance.photoURL,
    };

PoemModel _$PoemModelFromJson(Map<String, dynamic> json) => PoemModel(
  id: json['id'] as String,
  author: PoemAuthor.fromJson(json['author'] as Map<String, dynamic>),
  title: json['title'] as String,
  contentJson: json['contentJson'] as String,
  plainText: json['plainText'] as String,
  hashtags:
      (json['hashtags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  mood: json['mood'] as String? ?? '',
  isOriginal: json['isOriginal'] as bool? ?? false,
  visibility: json['visibility'] as String? ?? 'public',
  audioUrl: json['audioUrl'] as String? ?? '',
  audioDuration: (json['audioDuration'] as num?)?.toInt() ?? 0,
  coverColor: json['coverColor'] as String? ?? '',
  description: json['description'] as String? ?? '',
  textAlign: json['textAlign'] as String? ?? 'left',
  mentions:
      (json['mentions'] as List<dynamic>?)
          ?.map((e) => MentionedUser.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  likesCount: (json['likesCount'] as num?)?.toInt() ?? 0,
  commentsCount: (json['commentsCount'] as num?)?.toInt() ?? 0,
  repostsCount: (json['repostsCount'] as num?)?.toInt() ?? 0,
  isLikedByMe: json['isLikedByMe'] as bool? ?? false,
  isRepostedByMe: json['isRepostedByMe'] as bool? ?? false,
  isRepost: json['isRepost'] as bool? ?? false,
  originalPoem: json['originalPoem'] == null
      ? null
      : PoemModel.fromJson(json['originalPoem'] as Map<String, dynamic>),
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$PoemModelToJson(PoemModel instance) => <String, dynamic>{
  'id': instance.id,
  'author': instance.author,
  'title': instance.title,
  'contentJson': instance.contentJson,
  'plainText': instance.plainText,
  'hashtags': instance.hashtags,
  'mood': instance.mood,
  'isOriginal': instance.isOriginal,
  'visibility': instance.visibility,
  'audioUrl': instance.audioUrl,
  'audioDuration': instance.audioDuration,
  'coverColor': instance.coverColor,
  'description': instance.description,
  'textAlign': instance.textAlign,
  'mentions': instance.mentions,
  'likesCount': instance.likesCount,
  'commentsCount': instance.commentsCount,
  'repostsCount': instance.repostsCount,
  'isLikedByMe': instance.isLikedByMe,
  'isRepostedByMe': instance.isRepostedByMe,
  'isRepost': instance.isRepost,
  'originalPoem': instance.originalPoem,
  'createdAt': instance.createdAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
};
