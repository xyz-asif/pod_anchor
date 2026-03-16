import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';
import 'package:chatbee/features/poems/repos/poem_repo.dart';

part 'poem_controller.g.dart';

/// My poems list — keepAlive so it persists across navigation
@Riverpod(keepAlive: true)
class MyPoemsController extends _$MyPoemsController {
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  FutureOr<List<PoemModel>> build() async {
    final page = await ref.read(poemRepoProvider).getMyPoems(limit: 20);
    _hasMore = page.hasMore;
    return page.poems;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final page = await ref.read(poemRepoProvider).getMyPoems(limit: 20);
      _hasMore = page.hasMore;
      return page.poems;
    });
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore) return;
    final current = state.valueOrNull;
    if (current == null || current.isEmpty) return;

    _isLoadingMore = true;
    try {
      final page = await ref.read(poemRepoProvider).getMyPoems(
        limit: 20,
        before: current.last.id,
      );
      _hasMore = page.hasMore;
      state = AsyncValue.data([...current, ...page.poems]);
    } finally {
      _isLoadingMore = false;
    }
  }

  /// Add a new poem to the top of the list after creation
  void prependPoem(PoemModel poem) {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([poem, ...current]);
  }

  /// Replace a poem after editing
  void updatePoem(PoemModel updatedPoem) {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
      current.map((p) => p.id == updatedPoem.id ? updatedPoem : p).toList(),
    );
  }

  /// Remove a poem after deletion
  void removePoem(String poemId) {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(current.where((p) => p.id != poemId).toList());
  }

  bool get hasMore => _hasMore;
}
