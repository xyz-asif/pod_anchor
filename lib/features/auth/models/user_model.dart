import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

/// User model matching the backend API schema.
/// Run: dart run build_runner build --delete-conflicting-outputs
@JsonSerializable()
class UserModel {
  final String id;
  final String? firebaseUid;
  final String email;
  final String? displayName;
  final String? photoURL;
  final String? bio;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.id,
    this.firebaseUid,
    required this.email,
    this.displayName,
    this.photoURL,
    this.bio,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  Map<String, dynamic> toJson() => _$UserModelToJson(this);

  UserModel copyWith({
    String? id,
    String? firebaseUid,
    String? email,
    String? displayName,
    String? photoURL,
    String? bio,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      bio: bio ?? this.bio,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
