import 'package:json_annotation/json_annotation.dart';
import 'package:chatbee/features/chat/models/participant_info.dart';

part 'room_response.g.dart';

/// Chat room model matching the backend RoomResponse.
///
/// - `unreadCount`: for badge display
/// - `participants[i].isOnline`: for green dot on avatar
/// - `lastMessage` + `lastMessageSenderName`: for chat list preview
@JsonSerializable()
class RoomResponse {
  final String id;
  final String type;
  final String? name;
  final List<ParticipantInfo> participants;
  final String? lastMessage;
  final String? lastMessageSenderName;
  final int unreadCount;
  final DateTime? lastUpdated;

  const RoomResponse({
    required this.id,
    this.type = 'direct',
    this.name,
    this.participants = const [],
    this.lastMessage,
    this.lastMessageSenderName,
    this.unreadCount = 0,
    this.lastUpdated,
  });

  factory RoomResponse.fromJson(Map<String, dynamic> json) =>
      _$RoomResponseFromJson(json);

  Map<String, dynamic> toJson() => _$RoomResponseToJson(this);

  RoomResponse copyWith({
    String? id,
    String? type,
    String? name,
    List<ParticipantInfo>? participants,
    String? lastMessage,
    String? lastMessageSenderName,
    int? unreadCount,
    DateTime? lastUpdated,
  }) {
    return RoomResponse(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageSenderName:
          lastMessageSenderName ?? this.lastMessageSenderName,
      unreadCount: unreadCount ?? this.unreadCount,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
