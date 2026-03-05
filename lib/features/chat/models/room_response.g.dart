// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RoomResponse _$RoomResponseFromJson(Map<String, dynamic> json) => RoomResponse(
  id: json['id'] as String,
  type: json['type'] as String? ?? 'direct',
  name: json['name'] as String?,
  participants:
      (json['participants'] as List<dynamic>?)
          ?.map((e) => ParticipantInfo.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  lastMessage: json['lastMessage'] as String?,
  lastMessageSenderName: json['lastMessageSenderName'] as String?,
  unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
  lastUpdated: json['lastUpdated'] == null
      ? null
      : DateTime.parse(json['lastUpdated'] as String),
);

Map<String, dynamic> _$RoomResponseToJson(RoomResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'name': instance.name,
      'participants': instance.participants,
      'lastMessage': instance.lastMessage,
      'lastMessageSenderName': instance.lastMessageSenderName,
      'unreadCount': instance.unreadCount,
      'lastUpdated': instance.lastUpdated?.toIso8601String(),
    };
