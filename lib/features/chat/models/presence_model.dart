import 'package:json_annotation/json_annotation.dart';

part 'presence_model.g.dart';

/// User presence (online/offline status).
///
/// Usage: Check if a specific user is online.
/// For chat list, use `RoomResponse.participants[i].isOnline` instead.
@JsonSerializable()
class PresenceModel {
  final String userId;
  final bool online;

  const PresenceModel({required this.userId, this.online = false});

  factory PresenceModel.fromJson(Map<String, dynamic> json) =>
      _$PresenceModelFromJson(json);

  Map<String, dynamic> toJson() => _$PresenceModelToJson(this);
}
