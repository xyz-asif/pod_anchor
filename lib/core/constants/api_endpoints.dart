/// All API endpoints in one place.
/// Usage: ApiEndpoints.usersMe
class ApiEndpoints {
  ApiEndpoints._();

  // Base URL — change per environment
  // Change this line in your ApiEndpoints class:

  // static const String baseUrl = 'http://asifs-macbook-air.local:8080/api/v1';
  static const String baseUrl =
      'https://glacial-filiberto-cespitosely.ngrok-free.dev/api/v1';

  // ── Users ──
  static const String usersMe = '/users/me';
  static const String usersSearch = '/users/search';
  static const String usersSearchWithStatus = '/users/search-with-status';

  // Follow
  static String userFollow(String userId) => '/users/$userId/follow';
  static String userProfile(String userId) => '/users/$userId/profile';
  static String userFollowers(String userId) => '/users/$userId/followers';
  static String userFollowing(String userId) => '/users/$userId/following';

  // Feed
  static const String homeFeed = '/feed';
  static const String exploreFeed = '/feed/explore';

  // Search
  static const String searchPoems = '/search/poems';
  static const String searchUsers = '/search/users';

  // Profile setup
  static const String userSetup = '/users/setup';
  static const String usernameCheck = '/users/username/check';
  static const String usernameSet = '/users/username';

  // Poems
  static const String poems = '/poems';
  static String poem(String id) => '/poems/$id';
  static const String myPoems = '/poems/me';
  static String userPoems(String userId) => '/poems/user/$userId';

  // ── Connections (Friends) ──
  static const String connectionRequest = '/connections/request';
  static const String connectionsPending = '/connections/pending';
  static const String connectionsFriends = '/connections/friends';

  /// Use: '/connections/$id/accept'
  static String connectionAccept(String id) => '/connections/$id/accept';

  /// Use: '/connections/$id/cancel'
  static String connectionCancel(String id) => '/connections/$id/cancel';

  /// Use: '/connections/$id/reject'
  static String connectionReject(String id) => '/connections/$id/reject';

  /// Use: '/connections/$id' (delete/unfriend)
  static String connectionDelete(String id) => '/connections/$id';

  // ── Chat Rooms ──
  static const String chatRooms = '/chat/rooms';

  /// Use: '/chat/rooms/direct/$userId'
  static String chatRoomDirect(String userId) => '/chat/rooms/direct/$userId';

  /// Use: '/chat/rooms/$roomId/messages'
  static String chatRoomMessages(String roomId) =>
      '/chat/rooms/$roomId/messages';

  /// Use: '/chat/rooms/$roomId/read'
  static String chatRoomRead(String roomId) => '/chat/rooms/$roomId/read';

  /// Use: '/chat/rooms/$roomId' (delete chat)
  static String chatRoomDelete(String roomId) => '/chat/rooms/$roomId';

  // ── Messages ──
  /// Use: '/chat/messages/$messageId/status'
  static String messageStatus(String messageId) =>
      '/chat/messages/$messageId/status';

  /// Use: '/chat/messages/$messageId/reactions'
  static String messageReactions(String messageId) =>
      '/chat/messages/$messageId/reactions';

  /// Use: '/chat/messages/$messageId' (edit)
  static String messageEdit(String messageId) => '/chat/messages/$messageId';

  /// Use: '/chat/messages/$messageId' (delete)
  static String messageDelete(String messageId) => '/chat/messages/$messageId';

  // ── Presence ──
  /// Use: '/chat/users/$userId/presence'
  static String userPresence(String userId) => '/chat/users/$userId/presence';

  // ── WebSocket ──
  static const String webSocket = '/chat/ws';
  static const String chatDisconnect = '/chat/disconnect';

  /// ⚠️ SECURITY: Token is in the URL query string. NEVER log the output of this method.
  /// Long-term: migrate to first-message auth to keep token out of URLs.
  static String webSocketUrl(String token) {
    final wsBase = baseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://');
    return '$wsBase/chat/ws?token=$token';
  }

  // ── Notifications ──
  static const String notifications = '/notifications';
  static const String notificationsUnreadCount = '/notifications/unread-count';
  static String notificationRead(String id) => '/notifications/$id/read';
  static const String notificationsReadAll = '/notifications/read-all';

  // ── FCM Token ──
  static const String registerFCMToken = '/users/me/fcm-token';

  // ── Health ──
  static const String health = '/health';

  // ── Social ──
  static String poemLike(String id) => '/poems/$id/like';
  static String poemLikes(String id) => '/poems/$id/likes';
  static String poemComments(String id) => '/poems/$id/comments';
  static String commentDelete(String id) => '/comments/$id';
  static String commentLike(String id) => '/comments/$id/like';
  static String poemRepost(String id) => '/poems/$id/repost';
  static String userReposts(String userId) => '/users/$userId/reposts';

  // ── Audio Feed ──
  static const String audioFeed = '/feed/audio';

  // ── Auth (JWT exchange / refresh / logout) ──
  static const String authExchange = '/auth/exchange';
  static const String authRefresh  = '/auth/refresh';
  static const String authLogout   = '/auth/logout';
}
