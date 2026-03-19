import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks whether the device has any network connection.
/// Emits true/false reactively. All widgets can ref.watch this.
final connectivityProvider = StreamProvider<bool>((ref) {
  final connectivity = Connectivity();

  // Controller to merge the initial check + ongoing changes into one stream
  final controller = StreamController<bool>();

  // Check current state immediately
  connectivity.checkConnectivity().then((results) {
    final hasNetwork = results.any((r) => r != ConnectivityResult.none);
    controller.add(hasNetwork);
  });

  // Listen for changes
  final sub = connectivity.onConnectivityChanged.listen((results) {
    final hasNetwork = results.any((r) => r != ConnectivityResult.none);
    controller.add(hasNetwork);
  });

  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Simple synchronous check — use when you need a one-shot read.
/// Returns false if the provider hasn't loaded yet.
bool isOnline(WidgetRef ref) {
  return ref.read(connectivityProvider).valueOrNull ?? true;
}
