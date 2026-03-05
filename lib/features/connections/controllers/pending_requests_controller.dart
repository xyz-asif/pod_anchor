import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/features/connections/models/connection_model.dart';
import 'package:chatbee/features/connections/repos/connection_repo.dart';

part 'pending_requests_controller.g.dart';

/// Manages pending friend requests received by the current user.
@riverpod
class PendingRequestsController extends _$PendingRequestsController {
  @override
  FutureOr<List<ConnectionModel>> build() async {
    return ref.read(connectionRepoProvider).getPendingRequests();
  }

  /// Refresh pending requests from server.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(connectionRepoProvider).getPendingRequests(),
    );
  }

  /// Accept a request and remove it from the pending list.
  Future<void> accept(String connectionId) async {
    await ref.read(connectionRepoProvider).acceptRequest(connectionId);
    // Remove from local list
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
      current.where((c) => c.id != connectionId).toList(),
    );
    // Refresh friends list
    ref.invalidate(friendsControllerProvider);
  }

  /// Reject a request and remove it from the pending list.
  Future<void> reject(String connectionId) async {
    await ref.read(connectionRepoProvider).rejectRequest(connectionId);
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
      current.where((c) => c.id != connectionId).toList(),
    );
  }
}
