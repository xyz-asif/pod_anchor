import 'package:json_annotation/json_annotation.dart';

part 'media_metadata.g.dart';

/// Metadata for media messages (images, videos, audio, files).
///
/// All fields are nullable for flexibility and backward compatibility.
@JsonSerializable()
class MediaMetadata {
  final String? mimeType;
  final String? fileName;
  final int? fileSize;
  final String? thumbnailURL;
  final int? duration; // seconds, for audio/video
  final int? width;
  final int? height;

  const MediaMetadata({
    this.mimeType,
    this.fileName,
    this.fileSize,
    this.thumbnailURL,
    this.duration,
    this.width,
    this.height,
  });

  factory MediaMetadata.fromJson(Map<String, dynamic> json) =>
      _$MediaMetadataFromJson(json);

  Map<String, dynamic> toJson() => _$MediaMetadataToJson(this);

  MediaMetadata copyWith({
    String? mimeType,
    String? fileName,
    int? fileSize,
    String? thumbnailURL,
    int? duration,
    int? width,
    int? height,
  }) {
    return MediaMetadata(
      mimeType: mimeType ?? this.mimeType,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      thumbnailURL: thumbnailURL ?? this.thumbnailURL,
      duration: duration ?? this.duration,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}
