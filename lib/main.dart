import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatbee/app.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:chatbee/core/services/notification_service.dart';
import 'package:chatbee/core/network/api_client.dart';
import 'package:chatbee/core/providers/auth_provider.dart';
import 'package:chatbee/features/auth/controllers/auth_controller.dart';
import 'package:chatbee/core/utils/hive_storage.dart';

//this is phase 2 - Optimistic Firebase Auth
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive FIRST for synchronous storage
  log('Initializing Hive storage...', name: 'MAIN');
  await HiveStorage.init();
  log('Hive storage initialized', name: 'MAIN');

  // Initialize Firebase
  await Firebase.initializeApp();

  // Register the top-level background handler for FCM
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize Riverpod ProviderContainer
  final container = ProviderContainer();

  // Initialize API client (loads saved token from SharedPreferences into headers)
  log('Initializing API client...', name: 'MAIN');
  final apiClient = container.read(apiClientProvider);
  await apiClient.initialize();
  log('API client initialized, hasToken=${apiClient.hasToken}', name: 'MAIN');

  // ── OPTIMISTIC AUTH: Quick session check ───────────────────────────────
  // Check session_exists flag or stored token for INSTANT detection.
  // This avoids the 5-15 second Firebase restore wait on cold start.
  final authNotifier = container.read(authNotifierProvider);
  final hasOptimisticSession = await authNotifier.quickSessionCheck();
  log('Optimistic session check: $hasOptimisticSession', name: 'MAIN');

  if (hasOptimisticSession) {
    // Show home screen immediately - verification happens in background
    log('Session flag found - showing home optimistically', name: 'MAIN');
    
    // Initialize notification service (permissions and setup)
    final notificationService = container.read(notificationServiceProvider);
    await notificationService.initialize();
    log('Notification service initialized', name: 'MAIN');

    // Run full session verification in BACKGROUND (non-blocking)
    // This will verify Firebase auth and refresh token if needed
    unawaited(_verifySessionInBackground(container));
    
    // Run app immediately - don't wait for verification
    runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
  } else {
    // No session flag — show login screen.
    log('No session flag - showing login', name: 'MAIN');

    final notificationService = container.read(notificationServiceProvider);
    await notificationService.initialize();
    log('Notification service initialized', name: 'MAIN');

    runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
  }
}

/// Background session verification with 10s timeout
/// This runs AFTER the app is already showing the home screen
Future<void> _verifySessionInBackground(ProviderContainer container) async {
  try {
    log('Starting background session verification...', name: 'MAIN');
    
    // Wait up to 10 seconds for Firebase to restore (was 5s, increased for reliability)
    await container.read(authControllerProvider.notifier).restoreSession();
    
    final authNotifier = container.read(authNotifierProvider);
    log('Background verification complete, isLoggedIn=${authNotifier.isLoggedIn}', name: 'MAIN');
    
    // Update session flag based on actual verification result
    await authNotifier.verifySession();
  } catch (e) {
    log('Background verification error: $e', name: 'MAIN');
    // Don't force logout on error - let user retry or auto-retry on resume
  }
}
