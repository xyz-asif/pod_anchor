// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserModel _$UserModelFromJson(Map<String, dynamic> json) => UserModel(
  id: json['id'] as String,
  firebaseUid: json['firebaseUid'] as String?,
  email: json['email'] as String,
  displayName: json['displayName'] as String?,
  photoURL: json['photoURL'] as String?,
  bio: json['bio'] as String?,
  username: json['username'] as String?,
  externalLink: json['externalLink'] as String?,
  coverImageURL: json['coverImageURL'] as String?,
  isProfileSetup: json['isProfileSetup'] as bool? ?? false,
  isEditor: json['isEditor'] as bool? ?? false,
  postsCount: (json['postsCount'] as num?)?.toInt() ?? 0,
  followersCount: (json['followersCount'] as num?)?.toInt() ?? 0,
  followingCount: (json['followingCount'] as num?)?.toInt() ?? 0,
  isActive: json['isActive'] as bool? ?? true,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$UserModelToJson(UserModel instance) => <String, dynamic>{
  'id': instance.id,
  'firebaseUid': instance.firebaseUid,
  'email': instance.email,
  'displayName': instance.displayName,
  'photoURL': instance.photoURL,
  'bio': instance.bio,
  'username': instance.username,
  'externalLink': instance.externalLink,
  'coverImageURL': instance.coverImageURL,
  'isProfileSetup': instance.isProfileSetup,
  'isEditor': instance.isEditor,
  'postsCount': instance.postsCount,
  'followersCount': instance.followersCount,
  'followingCount': instance.followingCount,
  'isActive': instance.isActive,
  'createdAt': instance.createdAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
};
