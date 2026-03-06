import 'package:chatbee/features/connections/models/connection_model.dart';

/// Enriched friend model combining connection data with user display info.
///
/// Used in the friends tab to show actual names, photos, and last message
/// instead of raw connection IDs.
class FriendWithInfo {
  final ConnectionModel connection;
  final String displayName;
  final String? photoURL;
  final String? lastMessage;
  final bool isOnline;

  const FriendWithInfo({
    required this.connection,
    required this.displayName,
    this.photoURL,
    this.lastMessage,
    this.isOnline = false,
  });
}
