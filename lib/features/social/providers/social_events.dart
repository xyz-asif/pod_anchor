import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SocialEvent {
  final String poemId;
  final bool? isLiked;
  final int? likesCount;
  final bool? isReposted;
  final int? repostsCount;
  final int? commentsCount;

  const SocialEvent({
    required this.poemId,
    this.isLiked,
    this.likesCount,
    this.isReposted,
    this.repostsCount,
    this.commentsCount,
  });
}

/// Broadcast stream for social events. Supports rapid-fire events
/// without overwriting (unlike a single StateProvider).
final socialEventStreamProvider = Provider<SocialEventBus>((ref) {
  final bus = SocialEventBus();
  ref.onDispose(() => bus.dispose());
  return bus;
});

class SocialEventBus {
  final _controller = StreamController<SocialEvent>.broadcast();
  Stream<SocialEvent> get stream => _controller.stream;

  void emit(SocialEvent event) {
    _controller.add(event);
  }

  void dispose() {
    _controller.close();
  }
}
