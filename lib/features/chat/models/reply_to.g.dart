// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reply_to.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReplyTo _$ReplyToFromJson(Map<String, dynamic> json) => ReplyTo(
  id: json['id'] as String,
  senderId: json['senderId'] as String,
  content: json['content'] as String,
  status: json['status'] as String?,
  type: json['type'] as String?,
  metadata: json['metadata'] == null
      ? null
      : MediaMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$ReplyToToJson(ReplyTo instance) => <String, dynamic>{
  'id': instance.id,
  'senderId': instance.senderId,
  'content': instance.content,
  'status': instance.status,
  'type': instance.type,
  'metadata': instance.metadata,
  'createdAt': instance.createdAt?.toIso8601String(),
};
