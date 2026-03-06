import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/features/connections/models/connection_model.dart';
import 'package:chatbee/features/connections/models/friend_with_info.dart';
import 'package:chatbee/features/connections/repos/connection_repo.dart';
import 'package:chatbee/features/chat/controllers/chat_list_controller.dart';
import 'package:chatbee/features/auth/controllers/auth_controller.dart';

part 'friends_controller.g.dart';

/// Manages the accepted friends list, enriched with user display info.
///
/// Cross-references friend connections with chat room participant data
/// to get names, photos, online status, and last messages.
@riverpod
class FriendsController extends _$FriendsController {
  @override
  FutureOr<List<FriendWithInfo>> build() async {
    final connections = await ref.read(connectionRepoProvider).getFriends();
    return _enrichConnections(connections);
  }

  /// Enrich connections with user info from chat rooms.
  List<FriendWithInfo> _enrichConnections(List<ConnectionModel> connections) {
    final currentUserId = ref.read(authControllerProvider).valueOrNull?.id;
    // VERY IMPORTANT: Use ref.watch here so that when chat rooms finish loading
    // from the server, this provider rebuilds and updates raw IDs to actual names.
    final rooms = ref.watch(chatListControllerProvider).valueOrNull ?? [];

    return connections.map((connection) {
      final friendUserId = connection.senderId == currentUserId
          ? connection.receiverId
          : connection.senderId;

      // Try to find this friend in chat room participants
      String displayName = friendUserId;
      String? photoURL;
      String? lastMessage;
      bool isOnline = false;

      for (final room in rooms) {
        final participant = room.participants
            .where((p) => p.id == friendUserId)
            .firstOrNull;

        if (participant != null) {
          displayName =
              participant.displayName ?? participant.email ?? friendUserId;
          photoURL = participant.photoURL;
          isOnline = participant.isOnline;
          lastMessage = room.lastMessage;
          break;
        }
      }

      return FriendWithInfo(
        connection: connection,
        displayName: displayName,
        photoURL: photoURL,
        lastMessage: lastMessage,
        isOnline: isOnline,
      );
    }).toList();
  }

  /// Refresh friends list from server.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final connections = await ref.read(connectionRepoProvider).getFriends();
      return _enrichConnections(connections);
    });
  }
}
