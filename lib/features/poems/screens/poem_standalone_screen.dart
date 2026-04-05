import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';
import 'package:chatbee/features/poems/widgets/poem_card.dart';
import 'package:chatbee/features/poems/repos/poem_repo.dart';

final poemFutureProvider = FutureProvider.family<PoemModel, String>((ref, id) {
  return ref.read(poemRepoProvider).getPoem(id);
});

/// Minimal scaffold for deep links and notifications.
/// Shows a single poem in a full-screen card.
class PoemStandaloneScreen extends ConsumerStatefulWidget {
  final String poemId;
  final PoemModel? poem; // If passed via extra, show immediately

  const PoemStandaloneScreen({super.key, required this.poemId, this.poem});

  @override
  ConsumerState<PoemStandaloneScreen> createState() =>
      _PoemStandaloneScreenState();
}

class _PoemStandaloneScreenState extends ConsumerState<PoemStandaloneScreen> {
  /// Holds the latest version of the poem after an in-place edit.
  /// Null until the user edits and saves; falls back to widget.poem or fetched.
  PoemModel? _localPoem;

  void _onDeleted() {
    if (mounted) Navigator.of(context).pop();
  }

  void _onUpdated(PoemModel updated) {
    setState(() => _localPoem = updated);
    // FIX #17: Don't invalidate the provider — we already have the fresh data
    // locally. Invalidating triggers a wasted network call whose result is
    // never displayed (because _localPoem takes priority).
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    // If we have a locally updated poem, show it immediately.
    if (_localPoem != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: PoemCard(
          key: ValueKey('${widget.poemId}_${_localPoem!.updatedAt}'),
          poem: _localPoem!,
          onDeleted: _onDeleted,
          onUpdated: _onUpdated,
        ),
      );
    }

    // If the poem was passed via navigation extra, show it directly.
    if (widget.poem != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: PoemCard(
          key: ValueKey(widget.poemId),
          poem: widget.poem!,
          onDeleted: _onDeleted,
          onUpdated: _onUpdated,
        ),
      );
    }

    // Otherwise fetch from network (deep link / notification).
    final asyncPoem = ref.watch(poemFutureProvider(widget.poemId));

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
              onPressed: () =>
                  ref.invalidate(poemFutureProvider(widget.poemId)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (loadedPoem) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: PoemCard(
          key: ValueKey('${widget.poemId}_${loadedPoem.updatedAt}'),
          poem: loadedPoem,
          onDeleted: _onDeleted,
          onUpdated: _onUpdated,
        ),
      ),
    );
  }
}
