import 'package:json_annotation/json_annotation.dart';

part 'reply_to.g.dart';

/// Represents the original message being replied to.
/// Embedded within MessageResponse when `replyTo` is not null.
@JsonSerializable()
class ReplyTo {
  final String id;
  final String senderId;
  final String content;
  final String? status;
  final DateTime? createdAt;

  const ReplyTo({
    required this.id,
    required this.senderId,
    required this.content,
    this.status,
    this.createdAt,
  });

  factory ReplyTo.fromJson(Map<String, dynamic> json) =>
      _$ReplyToFromJson(json);

  Map<String, dynamic> toJson() => _$ReplyToToJson(this);
}
