import 'package:json_annotation/json_annotation.dart';

part 'notification_model.g.dart';

@JsonSerializable()
class NotificationModel {
  final String id;
  final String type;
  final String resourceType;
  final String resourceId;
  final String title;
  final String body;
  final String actorId;
  final String? actorName;
  final String? actorPhotoUrl;
  final bool isRead;
  final DateTime? createdAt;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.resourceType,
    required this.resourceId,
    required this.title,
    required this.body,
    required this.actorId,
    this.actorName,
    this.actorPhotoUrl,
    this.isRead = false,
    this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      _$NotificationModelFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationModelToJson(this);

  NotificationModel copyWith({
    String? id,
    String? type,
    String? resourceType,
    String? resourceId,
    String? title,
    String? body,
    String? actorId,
    String? actorName,
    String? actorPhotoUrl,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      type: type ?? this.type,
      resourceType: resourceType ?? this.resourceType,
      resourceId: resourceId ?? this.resourceId,
      title: title ?? this.title,
      body: body ?? this.body,
      actorId: actorId ?? this.actorId,
      actorName: actorName ?? this.actorName,
      actorPhotoUrl: actorPhotoUrl ?? this.actorPhotoUrl,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
