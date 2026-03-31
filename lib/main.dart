import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatbee/app.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:chatbee/core/services/notification_service.dart';
import 'package:chatbee/core/network/api_client.dart';
import 'package:chatbee/core/providers/auth_provider.dart';
import 'package:chatbee/features/auth/controllers/auth_controller.dart';

//this is phase 2
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Register the top-level background handler for FCM
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize Riverpod ProviderContainer
  final container = ProviderContainer();

  // Initialize API client (loads saved token from secure storage into headers)
  log('Initializing API client...', name: 'MAIN');
  final apiClient = container.read(apiClientProvider);
  await apiClient.initialize();
  log('API client initialized, hasToken=${apiClient.hasToken}', name: 'MAIN');

  // ── Fallback: recover token if SecureStorage was wiped ──────────────────
  // FlutterSecureStorage can lose data on reinstall or OS key migration.
  // If Firebase still has a valid session, force-refresh and re-save the token.
  //
  // IMPORTANT: FirebaseAuth.instance.currentUser is null on cold start because
  // Firebase restores its auth session asynchronously via platform channels.
  // We must wait for authStateChanges() to emit before concluding there is no
  // session — otherwise the fallback always misses a valid Firebase user.
  if (!apiClient.hasToken) {
    User? firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      log('currentUser null — waiting for Firebase auth restore...', name: 'MAIN');
      try {
        firebaseUser = await FirebaseAuth.instance
            .authStateChanges()
            .firstWhere((u) => u != null)
            .timeout(const Duration(seconds: 5));
        log('Firebase auth restored: uid=${firebaseUser?.uid}', name: 'MAIN');
      } catch (_) {
        log('Firebase has no session (timeout or signed out)', name: 'MAIN');
      }
    }
    if (firebaseUser != null) {
      log('Token missing but Firebase user exists — recovering...', name: 'MAIN');
      try {
        final freshToken = await firebaseUser.getIdToken(true);
        if (freshToken != null) {
          await apiClient.setToken(freshToken);
          log('Token recovered from Firebase', name: 'MAIN');
        }
      } catch (e) {
        log('Failed to recover token from Firebase: $e', name: 'MAIN');
      }
    }
  }

  // Initialize notification service (permissions and setup)
  final notificationService = container.read(notificationServiceProvider);
  await notificationService.initialize();
  log('Notification service initialized', name: 'MAIN');

  // ── Determine if user was previously signed in ──────────────────────────
  // Use the stored token as the PRIMARY signal. Firebase currentUser may be
  // null at this point on cold start (especially release APK) because the
  // native SDK hasn't finished restoring the auth session yet.
  // restoreSession() handles the Firebase wait internally.
  final authNotifier = container.read(authNotifierProvider);
  final hasStoredToken = apiClient.hasToken;
  log('Stored token exists: $hasStoredToken', name: 'MAIN');

  if (hasStoredToken) {
    // Tell the router we're (probably) logged in — prevents flash of login screen.
    // restoreSession() will call logout() if the session is truly gone.
    authNotifier.login();
    log('Restoring session...', name: 'MAIN');

    await container.read(authControllerProvider.notifier).restoreSession();
    log('Session restore complete, isLoggedIn=${authNotifier.isLoggedIn}', name: 'MAIN');
  }

  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
}
