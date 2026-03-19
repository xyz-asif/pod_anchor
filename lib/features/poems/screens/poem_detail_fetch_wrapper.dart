import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatbee/features/poems/repos/poem_repo.dart';
import 'package:chatbee/features/poems/models/poem_model.dart';
import 'package:chatbee/features/poems/screens/poem_detail_screen.dart';

class PoemDetailFetchWrapper extends ConsumerWidget {
  final String poemId;
  const PoemDetailFetchWrapper({super.key, required this.poemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<PoemModel>(
      future: ref.read(poemRepoProvider).getPoem(poemId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Poem not found')),
          );
        }
        return PoemDetailScreen(poem: snapshot.data!);
      },
    );
  }
}
