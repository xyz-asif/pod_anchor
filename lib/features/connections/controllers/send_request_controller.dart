import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/features/connections/repos/connection_repo.dart';

part 'send_request_controller.g.dart';

/// Handles sending friend requests from the search screen.
/// State holds the set of user IDs that have been sent a request
/// in this session (to disable the button after sending).
@riverpod
class SendRequestController extends _$SendRequestController {
  @override
  Set<String> build() => {};

  /// Send a friend request to a user by their ID.
  Future<void> sendRequest(String receiverId) async {
    try {
      await ref.read(connectionRepoProvider).sendRequest(receiverId);
      state = {...state, receiverId};
    } catch (_) {
      rethrow;
    }
  }

  /// Check if a request was already sent to this user in this session.
  bool wasSent(String userId) => state.contains(userId);
}
