import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';
import 'package:chatbee/features/poems/widgets/poem_card.dart';
import 'package:chatbee/features/poems/repos/poem_repo.dart';

final poemFutureProvider = FutureProvider.family<PoemModel, String>((ref, id) {
  return ref.read(poemRepoProvider).getPoem(id);
});

/// Minimal scaffold for deep links and notifications
/// Shows a single poem in a full-screen card
class PoemStandaloneScreen extends ConsumerWidget {
  final String poemId;
  final PoemModel? poem; // If passed via extra, show immediately

  const PoemStandaloneScreen({
    super.key,
    required this.poemId,
    this.poem,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(context, ref),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref) {
    if (poem != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: PoemCard(poem: poem!),
      );
    }

    final asyncPoem = ref.watch(poemFutureProvider(poemId));

    return asyncPoem.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Failed to load poem',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(poemFutureProvider(poemId)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (loadedPoem) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: PoemCard(poem: loadedPoem),
      ),
    );
  }
}
