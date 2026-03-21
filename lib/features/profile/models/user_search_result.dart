class UserSearchResult {
  final String id;
  final String displayName;
  final String username;
  final String photoURL;
  final bool isEditor;
  final bool isFollowing;

  const UserSearchResult({
    required this.id,
    this.displayName = '',
    this.username = '',
    this.photoURL = '',
    this.isEditor = false,
    this.isFollowing = false,
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
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
    final usersList = json['users'] as List? ??
        json['followers'] as List? ??
        json['following'] as List? ??
        [];
    return UserSearchPage(
      users: usersList
          .map((e) => UserSearchResult.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}
