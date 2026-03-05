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
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$ReplyToToJson(ReplyTo instance) => <String, dynamic>{
  'id': instance.id,
  'senderId': instance.senderId,
  'content': instance.content,
  'status': instance.status,
  'createdAt': instance.createdAt?.toIso8601String(),
};
