// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConnectionModel _$ConnectionModelFromJson(Map<String, dynamic> json) =>
    ConnectionModel(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      receiverId: json['receiverId'] as String,
      status: json['status'] as String? ?? 'pending',
      senderDisplayName: json['senderDisplayName'] as String?,
      senderPhotoURL: json['senderPhotoURL'] as String?,
      senderEmail: json['senderEmail'] as String?,
      receiverDisplayName: json['receiverDisplayName'] as String?,
      receiverPhotoURL: json['receiverPhotoURL'] as String?,
      receiverEmail: json['receiverEmail'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$ConnectionModelToJson(ConnectionModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'senderId': instance.senderId,
      'receiverId': instance.receiverId,
      'status': instance.status,
      'senderDisplayName': instance.senderDisplayName,
      'senderPhotoURL': instance.senderPhotoURL,
      'senderEmail': instance.senderEmail,
      'receiverDisplayName': instance.receiverDisplayName,
      'receiverPhotoURL': instance.receiverPhotoURL,
      'receiverEmail': instance.receiverEmail,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
