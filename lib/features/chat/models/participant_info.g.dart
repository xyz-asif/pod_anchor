// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'participant_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ParticipantInfo _$ParticipantInfoFromJson(Map<String, dynamic> json) =>
    ParticipantInfo(
      id: json['id'] as String,
      displayName: json['displayName'] as String?,
      photoURL: json['photoURL'] as String?,
      email: json['email'] as String?,
      isOnline: json['isOnline'] as bool? ?? false,
    );

Map<String, dynamic> _$ParticipantInfoToJson(ParticipantInfo instance) =>
    <String, dynamic>{
      'id': instance.id,
      'displayName': instance.displayName,
      'photoURL': instance.photoURL,
      'email': instance.email,
      'isOnline': instance.isOnline,
    };
