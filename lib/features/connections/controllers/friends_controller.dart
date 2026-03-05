import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/features/connections/models/connection_model.dart';
import 'package:chatbee/features/connections/repos/connection_repo.dart';

part 'friends_controller.g.dart';

/// Manages the accepted friends list.
@riverpod
class FriendsController extends _$FriendsController {
  @override
  FutureOr<List<ConnectionModel>> build() async {
    return ref.read(connectionRepoProvider).getFriends();
  }

  /// Refresh friends list from server.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(connectionRepoProvider).getFriends(),
    );
  }
}
