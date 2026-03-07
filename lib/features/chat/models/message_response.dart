import 'package:json_annotation/json_annotation.dart';
import 'package:chatbee/features/chat/models/reply_to.dart';
import 'package:chatbee/features/chat/models/media_metadata.dart';
import 'package:chatbee/features/chat/models/message_type.dart';

part 'message_response.g.dart';

/// Message status values for tick display.
enum MessageStatus {
  sent,
  delivered,
  read;

  static MessageStatus fromString(String? value) {
    return MessageStatus.values.firstWhere(
      (e) => e.name == value?.toLowerCase(),
      orElse: () => MessageStatus.sent,
    );
  }
}

/// Full message model matching the backend MessageResponse.
///
/// - `status`: sent → delivered → read (tick progression)
/// - `reactions`: Map of userId to emoji — empty {} means no reactions
/// - `replyTo`: null unless message is a reply
/// - `isDeleted`: true means render greyed-out italicised "This message was deleted"
/// - `type`: text, image, audio, file, gif, link, video
/// - `metadata`: optional media metadata (dimensions, file info, etc.)
@JsonSerializable()
class MessageResponse {
  final String id;
  final String roomId;
  final String senderId;
  final String content;
  final String status;
  final String type;
  final Map<String, String> reactions;
  final ReplyTo? replyTo;
  final MediaMetadata? metadata;
  final bool isEdited;
  final bool isDeleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MessageResponse({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.content,
    this.status = 'sent',
    this.type = 'text',
    this.reactions = const {},
    this.replyTo,
    this.metadata,
    this.isEdited = false,
    this.isDeleted = false,
    this.createdAt,
    this.updatedAt,
  });

  factory MessageResponse.fromJson(Map<String, dynamic> json) =>
      _$MessageResponseFromJson(json);

  Map<String, dynamic> toJson() => _$MessageResponseToJson(this);

  /// Helper to get typed status enum.
  MessageStatus get statusEnum => MessageStatus.fromString(status);

  /// Helper to get typed message type enum.
  MessageType get messageType => MessageType.fromString(type);

  /// Whether this message is a media message (not plain text).
  bool get isMedia => messageType != MessageType.text;

  MessageResponse copyWith({
    String? id,
    String? roomId,
    String? senderId,
    String? content,
    String? status,
    String? type,
    Map<String, String>? reactions,
    ReplyTo? replyTo,
    MediaMetadata? metadata,
    bool? isEdited,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MessageResponse(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      status: status ?? this.status,
      type: type ?? this.type,
      reactions: reactions ?? this.reactions,
      replyTo: replyTo ?? this.replyTo,
      metadata: metadata ?? this.metadata,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
