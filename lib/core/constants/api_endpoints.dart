/// All API endpoints in one place.
/// Usage: ApiEndpoints.usersMe
class ApiEndpoints {
  ApiEndpoints._();

  // Base URL — change per environment
  static const String baseUrl = 'http://192.168.0.82:8080/api/v1';

  // ── Users ──
  static const String usersMe = '/users/me';
  static const String usersSearch = '/users/search';

  // ── Connections (Friends) ──
  static const String connectionRequest = '/connections/request';
  static const String connectionsPending = '/connections/pending';
  static const String connectionsFriends = '/connections/friends';

  /// Use: '/connections/$id/accept'
  static String connectionAccept(String id) => '/connections/$id/accept';

  /// Use: '/connections/$id/reject'
  static String connectionReject(String id) => '/connections/$id/reject';

  // ── Chat Rooms ──
  static const String chatRooms = '/chat/rooms';

  /// Use: '/chat/rooms/direct/$userId'
  static String chatRoomDirect(String userId) => '/chat/rooms/direct/$userId';

  /// Use: '/chat/rooms/$roomId/messages'
  static String chatRoomMessages(String roomId) =>
      '/chat/rooms/$roomId/messages';

  /// Use: '/chat/rooms/$roomId/read'
  static String chatRoomRead(String roomId) => '/chat/rooms/$roomId/read';

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
  static String webSocketUrl(String token) =>
      'ws://192.168.0.82:8080/api/v1/chat/ws?token=$token';

  // ── Health ──
  static const String health = '/health';
}
