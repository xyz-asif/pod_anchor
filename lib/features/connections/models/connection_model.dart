import 'package:json_annotation/json_annotation.dart';

part 'connection_model.g.dart';

/// Connection status for friend requests.
enum ConnectionStatus {
  pending,
  accepted,
  rejected,
  blocked;

  static ConnectionStatus fromString(String? value) {
    return ConnectionStatus.values.firstWhere(
      (e) => e.name == value?.toLowerCase(),
      orElse: () => ConnectionStatus.pending,
    );
  }
}

/// Connection (friend request) model matching the backend.
///
/// Status flow: pending → accepted/rejected/blocked
@JsonSerializable()
class ConnectionModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String status;
  final String? senderDisplayName;
  final String? senderPhotoURL;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ConnectionModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.status = 'pending',
    this.senderDisplayName,
    this.senderPhotoURL,
    this.createdAt,
    this.updatedAt,
  });

  factory ConnectionModel.fromJson(Map<String, dynamic> json) =>
      _$ConnectionModelFromJson(json);

  Map<String, dynamic> toJson() => _$ConnectionModelToJson(this);

  /// Helper to get typed status enum.
  ConnectionStatus get statusEnum => ConnectionStatus.fromString(status);

  ConnectionModel copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? status,
    String? senderDisplayName,
    String? senderPhotoURL,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ConnectionModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      status: status ?? this.status,
      senderDisplayName: senderDisplayName ?? this.senderDisplayName,
      senderPhotoURL: senderPhotoURL ?? this.senderPhotoURL,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
