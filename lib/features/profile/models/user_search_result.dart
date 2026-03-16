class UserSearchResult {
  final String id;
  final String displayName;
  final String username;
  final String photoURL;
  final bool isEditor;
  final bool isFollowing;

  const UserSearchResult({
    required this.id,
    required this.displayName,
    required this.username,
    required this.photoURL,
    this.isEditor = false,
    this.isFollowing = false,
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      id: json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      username: json['username'] as String? ?? '',
      photoURL: json['photoURL'] as String? ?? '',
      isEditor: json['isEditor'] as bool? ?? false,
      isFollowing: json['isFollowing'] as bool? ?? false,
    );
  }
}

class UserSearchPage {
  final List<UserSearchResult> users;
  final bool hasMore;

  const UserSearchPage({required this.users, required this.hasMore});

  factory UserSearchPage.fromJson(Map<String, dynamic> json) {
    final list = json['users'] as List? ?? [];
    return UserSearchPage(
      users: list
          .map((e) => UserSearchResult.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}
