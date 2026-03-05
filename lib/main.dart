import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatbee/app.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:chatbee/core/services/notification_service.dart';
import 'package:chatbee/core/network/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  // Initialize notification service
  final notificationService = container.read(notificationServiceProvider);
  await notificationService.initialize();

  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
}
