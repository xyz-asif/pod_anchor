// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_metadata.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MediaMetadata _$MediaMetadataFromJson(Map<String, dynamic> json) =>
    MediaMetadata(
      mimeType: json['mimeType'] as String?,
      fileName: json['fileName'] as String?,
      fileSize: (json['fileSize'] as num?)?.toInt(),
      thumbnailURL: json['thumbnailURL'] as String?,
      duration: (json['duration'] as num?)?.toInt(),
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
    );

Map<String, dynamic> _$MediaMetadataToJson(MediaMetadata instance) =>
    <String, dynamic>{
      'mimeType': instance.mimeType,
      'fileName': instance.fileName,
      'fileSize': instance.fileSize,
      'thumbnailURL': instance.thumbnailURL,
      'duration': instance.duration,
      'width': instance.width,
      'height': instance.height,
    };
