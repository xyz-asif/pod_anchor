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
  final String? username;
  final String? externalLink;
  final String? coverImageURL;
  @JsonKey(defaultValue: false)
  final bool isProfileSetup;
  @JsonKey(defaultValue: false)
  final bool isEditor;
  @JsonKey(defaultValue: 0)
  final int postsCount;
  @JsonKey(defaultValue: 0)
  final int followersCount;
  @JsonKey(defaultValue: 0)
  final int followingCount;
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
    this.username,
    this.externalLink,
    this.coverImageURL,
    this.isProfileSetup = false,
    this.isEditor = false,
    this.postsCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
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
    String? username,
    String? externalLink,
    String? coverImageURL,
    bool? isProfileSetup,
    bool? isEditor,
    int? postsCount,
    int? followersCount,
    int? followingCount,
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
      username: username ?? this.username,
      externalLink: externalLink ?? this.externalLink,
      coverImageURL: coverImageURL ?? this.coverImageURL,
      isProfileSetup: isProfileSetup ?? this.isProfileSetup,
      isEditor: isEditor ?? this.isEditor,
      postsCount: postsCount ?? this.postsCount,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
