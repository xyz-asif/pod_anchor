// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'presence_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PresenceModel _$PresenceModelFromJson(Map<String, dynamic> json) =>
    PresenceModel(
      userId: json['userId'] as String,
      online: json['online'] as bool? ?? false,
    );

Map<String, dynamic> _$PresenceModelToJson(PresenceModel instance) =>
    <String, dynamic>{'userId': instance.userId, 'online': instance.online};
