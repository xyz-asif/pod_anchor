import 'package:chatbee/features/connections/controllers/friends_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/features/connections/models/connection_model.dart';
import 'package:chatbee/features/connections/repos/connection_repo.dart';
import 'package:chatbee/features/chat/repos/chat_repo.dart';
import 'package:chatbee/features/chat/controllers/chat_list_controller.dart';
import 'package:chatbee/features/auth/controllers/auth_controller.dart';

part 'pending_requests_controller.g.dart';

/// Manages pending friend requests received by the current user.
///
/// Uses optimistic removal: items disappear instantly on accept/reject,
/// and are restored if the API call fails.
@riverpod
class PendingRequestsController extends _$PendingRequestsController {
  /// Track which connection IDs are currently processing to prevent double-taps.
  final Set<String> _processingIds = {};

  @override
  FutureOr<List<ConnectionModel>> build() async {
    return ref.read(connectionRepoProvider).getPendingRequests();
  }

  /// Whether a specific request is currently being processed.
  bool isProcessing(String connectionId) =>
      _processingIds.contains(connectionId);

  /// Refresh pending requests from server.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(connectionRepoProvider).getPendingRequests(),
    );
  }

  /// Accept a request: optimistically remove, then call API.
  Future<void> accept(String connectionId) async {
    if (_processingIds.contains(connectionId)) return;

    final current = state.valueOrNull ?? [];
    final removedItem = current.firstWhere((c) => c.id == connectionId);

    _processingIds.add(connectionId);
    // Optimistic: remove immediately
    state = AsyncValue.data(
      current.where((c) => c.id != connectionId).toList(),
    );

    try {
      await ref.read(connectionRepoProvider).acceptRequest(connectionId);

      // Proactively create room so FriendsController enrichment finds it instantly
      final friendUserId =
          ref.read(authControllerProvider).valueOrNull?.id ==
              removedItem.senderId
          ? removedItem.receiverId
          : removedItem.senderId;

      await ref.read(chatRepoProvider).getOrCreateDirectRoom(friendUserId);

      // Refresh friends list and chat list for instant consistency
      ref.invalidate(friendsControllerProvider);
      ref.invalidate(chatListControllerProvider);
    } catch (e) {
      // Rollback: restore the item
      final restored = state.valueOrNull ?? [];
      if (!restored.any((c) => c.id == connectionId)) {
        state = AsyncValue.data([...restored, removedItem]);
      }
      rethrow;
    } finally {
      _processingIds.remove(connectionId);
    }
  }

  /// Reject a request: optimistically remove, then call API.
  Future<void> reject(String connectionId) async {
    if (_processingIds.contains(connectionId)) return;
    _processingIds.add(connectionId);

    final current = state.valueOrNull ?? [];
    final removedItem = current.firstWhere((c) => c.id == connectionId);

    // Optimistic: remove immediately
    state = AsyncValue.data(
      current.where((c) => c.id != connectionId).toList(),
    );

    try {
      await ref.read(connectionRepoProvider).rejectRequest(connectionId);
    } catch (e) {
      // Rollback: restore the item
      final restored = state.valueOrNull ?? [];
      state = AsyncValue.data([...restored, removedItem]);
      rethrow;
    } finally {
      _processingIds.remove(connectionId);
    }
  }
}
