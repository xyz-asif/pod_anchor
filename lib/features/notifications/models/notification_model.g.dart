// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NotificationModel _$NotificationModelFromJson(Map<String, dynamic> json) =>
    NotificationModel(
      id: json['id'] as String,
      type: json['type'] as String,
      resourceType: json['resourceType'] as String,
      resourceId: json['resourceId'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      actorId: json['actorId'] as String,
      actorName: json['actorName'] as String?,
      actorPhotoUrl: json['actorPhotoUrl'] as String?,
      isRead: json['isRead'] as bool? ?? false,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$NotificationModelToJson(NotificationModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'resourceType': instance.resourceType,
      'resourceId': instance.resourceId,
      'title': instance.title,
      'body': instance.body,
      'actorId': instance.actorId,
      'actorName': instance.actorName,
      'actorPhotoUrl': instance.actorPhotoUrl,
      'isRead': instance.isRead,
      'createdAt': instance.createdAt?.toIso8601String(),
    };
