import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';
import 'package:chatbee/features/poems/widgets/poem_card.dart';
import 'package:chatbee/features/poems/repos/poem_repo.dart';

/// Minimal scaffold for deep links and notifications
/// Shows a single poem in a full-screen card
class PoemStandaloneScreen extends ConsumerStatefulWidget {
  final String poemId;
  final PoemModel? poem; // If passed via extra, show immediately

  const PoemStandaloneScreen({
    super.key,
    required this.poemId,
    this.poem,
  });

  @override
  ConsumerState<PoemStandaloneScreen> createState() => _PoemStandaloneScreenState();
}

class _PoemStandaloneScreenState extends ConsumerState<PoemStandaloneScreen> {
  PoemModel? _poem;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _poem = widget.poem;
    if (_poem == null) {
      _fetchPoem();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _fetchPoem() async {
    try {
      final poem = await ref.read(poemRepoProvider).getPoem(widget.poemId);
      if (mounted) {
        setState(() {
          _poem = poem;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load poem';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null || _poem == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _error ?? 'Poem not found',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchPoem,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: PoemCard(
        poem: _poem!,
      ),
    );
  }
}
