import 'package:json_annotation/json_annotation.dart';

part 'participant_info.g.dart';

/// Participant info embedded within RoomResponse.
/// Shows user's display info and online status in chat rooms.
@JsonSerializable()
class ParticipantInfo {
  final String id;
  final String? displayName;
  final String? photoURL;
  final String? email;
  final bool isOnline;

  const ParticipantInfo({
    required this.id,
    this.displayName,
    this.photoURL,
    this.email,
    this.isOnline = false,
  });

  factory ParticipantInfo.fromJson(Map<String, dynamic> json) =>
      _$ParticipantInfoFromJson(json);

  Map<String, dynamic> toJson() => _$ParticipantInfoToJson(this);

  ParticipantInfo copyWith({
    String? id,
    String? displayName,
    String? photoURL,
    String? email,
    bool? isOnline,
  }) {
    return ParticipantInfo(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      email: email ?? this.email,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}
