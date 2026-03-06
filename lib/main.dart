import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatbee/app.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:chatbee/core/services/notification_service.dart';
import 'package:chatbee/core/network/api_client.dart';
import 'package:chatbee/core/providers/auth_provider.dart';
import 'package:chatbee/features/auth/controllers/auth_controller.dart';
import 'package:chatbee/features/chat/controllers/ws_event_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Register the top-level background handler for FCM
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize Riverpod ProviderContainer
  final container = ProviderContainer();

  // Initialize API client (loads saved token if exists)
  print('🚀 Initializing API client...');
  final apiClient = container.read(apiClientProvider);
  await apiClient.initialize();
  print('✅ API client initialized');

  // Check if user was previously logged in (token exists in secure storage)
  final authNotifier = container.read(authNotifierProvider);
  await authNotifier.init();
  print('🔐 Auth state initialized: isLoggedIn=${authNotifier.isLoggedIn}');

  // If already logged in, restore session (fetch profile + reconnect WebSocket)
  if (authNotifier.isLoggedIn) {
    print('🔄 Restoring session...');
    await container.read(authControllerProvider.notifier).restoreSession();
    print('✅ Session restored');

    // Eagerly initialize WS event handler so chat list updates
    // even before the user opens any individual chat screen
    container.read(wsEventHandlerProvider);
    print('📡 WS event handler initialized');
  }

  // Initialize notification service
  final notificationService = container.read(notificationServiceProvider);
  await notificationService.initialize();

  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
}
