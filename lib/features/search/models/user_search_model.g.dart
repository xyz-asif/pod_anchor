// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_search_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserSearchModel _$UserSearchModelFromJson(Map<String, dynamic> json) =>
    UserSearchModel(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      email: json['email'] as String,
      photoURL: json['photoURL'] as String?,
      bio: json['bio'] as String?,
      connectionStatus: json['connectionStatus'] as String? ?? 'none',
      connectionId: json['connectionId'] as String?,
      isSender: json['isSender'] as bool? ?? false,
    );

Map<String, dynamic> _$UserSearchModelToJson(UserSearchModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'displayName': instance.displayName,
      'email': instance.email,
      'photoURL': instance.photoURL,
      'bio': instance.bio,
      'connectionStatus': instance.connectionStatus,
      'connectionId': instance.connectionId,
      'isSender': instance.isSender,
    };

UserSearchResponse _$UserSearchResponseFromJson(Map<String, dynamic> json) =>
    UserSearchResponse(
      users: (json['users'] as List<dynamic>)
          .map((e) => UserSearchModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: (json['totalCount'] as num).toInt(),
      hasMore: json['hasMore'] as bool,
    );

Map<String, dynamic> _$UserSearchResponseToJson(UserSearchResponse instance) =>
    <String, dynamic>{
      'users': instance.users,
      'totalCount': instance.totalCount,
      'hasMore': instance.hasMore,
    };
