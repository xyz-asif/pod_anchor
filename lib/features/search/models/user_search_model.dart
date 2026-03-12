import 'package:json_annotation/json_annotation.dart';

part 'user_search_model.g.dart';

/// Connection status values from API:
/// - none: No connection, show "Add Friend" button
/// - pending_sent: You sent request, show "Pending" + "Cancel" button
/// - pending_received: They sent request, show "Accept" + "Reject" buttons
/// - accepted: Friends, show "Unfriend" button
/// - rejected: Previous request rejected, can resend
/// - blocked: Blocked, no action available
@JsonSerializable()
class UserSearchModel {
  final String id;
  final String displayName;
  final String email;
  final String? photoURL;
  final String? bio;
  @JsonKey(defaultValue: 'none')
  final String connectionStatus;
  final String? connectionId;
  @JsonKey(defaultValue: false)
  final bool isSender;

  UserSearchModel({
    required this.id,
    required this.displayName,
    required this.email,
    this.photoURL,
    this.bio,
    this.connectionStatus = 'none',
    this.connectionId,
    this.isSender = false,
  });

  factory UserSearchModel.fromJson(Map<String, dynamic> json) =>
      _$UserSearchModelFromJson(json);

  Map<String, dynamic> toJson() => _$UserSearchModelToJson(this);

  UserSearchModel copyWith({
    String? id,
    String? displayName,
    String? email,
    String? photoURL,
    String? bio,
    String? connectionStatus,
    String? connectionId,
    bool? isSender,
  }) {
    return UserSearchModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoURL: photoURL ?? this.photoURL,
      bio: bio ?? this.bio,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      connectionId: connectionId ?? this.connectionId,
      isSender: isSender ?? this.isSender,
    );
  }
}

@JsonSerializable()
class UserSearchResponse {
  final List<UserSearchModel> users;
  final int totalCount;
  final bool hasMore;

  UserSearchResponse({
    required this.users,
    required this.totalCount,
    required this.hasMore,
  });

  factory UserSearchResponse.fromJson(Map<String, dynamic> json) =>
      _$UserSearchResponseFromJson(json);

  Map<String, dynamic> toJson() => _$UserSearchResponseToJson(this);
}
