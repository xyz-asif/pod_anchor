import 'package:json_annotation/json_annotation.dart';
import 'package:chatbee/features/chat/models/reply_to.dart';

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
/// - `reactions`: Map<userId, emoji> — empty {} means no reactions
/// - `replyTo`: null unless message is a reply
/// - `isDeleted`: true means render greyed-out italicised "This message was deleted"
@JsonSerializable()
class MessageResponse {
  final String id;
  final String roomId;
  final String senderId;
  final String content;
  final String status;
  final Map<String, String> reactions;
  final ReplyTo? replyTo;
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
    this.reactions = const {},
    this.replyTo,
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

  MessageResponse copyWith({
    String? id,
    String? roomId,
    String? senderId,
    String? content,
    String? status,
    Map<String, String>? reactions,
    ReplyTo? replyTo,
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
      reactions: reactions ?? this.reactions,
      replyTo: replyTo ?? this.replyTo,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
