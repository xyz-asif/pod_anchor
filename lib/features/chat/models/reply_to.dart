import 'package:json_annotation/json_annotation.dart';
import 'package:chatbee/features/chat/models/media_metadata.dart';
import 'package:chatbee/features/chat/models/message_type.dart';

part 'reply_to.g.dart';

/// Represents the original message being replied to.
/// Embedded within MessageResponse when `replyTo` is not null.
@JsonSerializable()
class ReplyTo {
  final String id;
  final String senderId;
  final String content;
  final String? status;
  final String? type;
  final MediaMetadata? metadata;
  final DateTime? createdAt;

  const ReplyTo({
    required this.id,
    required this.senderId,
    required this.content,
    this.status,
    this.type,
    this.metadata,
    this.createdAt,
  });

  factory ReplyTo.fromJson(Map<String, dynamic> json) =>
      _$ReplyToFromJson(json);

  Map<String, dynamic> toJson() => _$ReplyToToJson(this);

  /// Helper to get typed message type enum.
  MessageType get messageType => MessageType.fromString(type);

  /// Whether this reply is to a media message.
  bool get isMedia => messageType != MessageType.text;
}
