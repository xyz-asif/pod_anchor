class PublicProfileModel {
  final String id;
  final String displayName;
  final String username;
  final String photoURL;
  final String coverImageURL;
  final String bio;
  final String externalLink;
  final bool isEditor;
  final int postsCount;
  final int followersCount;
  final int followingCount;
  final bool isFollowedByMe;
  final bool isMe;

  const PublicProfileModel({
    required this.id,
    required this.displayName,
    required this.username,
    required this.photoURL,
    this.coverImageURL = '',
    this.bio = '',
    this.externalLink = '',
    this.isEditor = false,
    this.postsCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.isFollowedByMe = false,
    this.isMe = false,
  });

  factory PublicProfileModel.fromJson(Map<String, dynamic> json) {
    return PublicProfileModel(
      id: json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      username: json['username'] as String? ?? '',
      photoURL: json['photoURL'] as String? ?? '',
      coverImageURL: json['coverImageURL'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      externalLink: json['externalLink'] as String? ?? '',
      isEditor: json['isEditor'] as bool? ?? false,
      postsCount: json['postsCount'] as int? ?? 0,
      followersCount: json['followersCount'] as int? ?? 0,
      followingCount: json['followingCount'] as int? ?? 0,
      isFollowedByMe: json['isFollowedByMe'] as bool? ?? false,
      isMe: json['isMe'] as bool? ?? false,
    );
  }

  PublicProfileModel copyWith({
    String? displayName,
    String? photoURL,
    String? coverImageURL,
    String? bio,
    int? postsCount,
    int? followersCount,
    int? followingCount,
    bool? isFollowedByMe,
    bool? isMe,
  }) {
    return PublicProfileModel(
      id: id,
      displayName: displayName ?? this.displayName,
      username: username,
      photoURL: photoURL ?? this.photoURL,
      coverImageURL: coverImageURL ?? this.coverImageURL,
      bio: bio ?? this.bio,
      externalLink: externalLink,
      isEditor: isEditor,
      postsCount: postsCount ?? this.postsCount,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      isFollowedByMe: isFollowedByMe ?? this.isFollowedByMe,
      isMe: isMe ?? this.isMe,
    );
  }
}
