import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anchor/app.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:anchor/core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (Assuming native google-services configs exist)
  await Firebase.initializeApp();

  // Register the top-level background handler for FCM
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize Riverpod ProviderContainer to access services before runApp
  final container = ProviderContainer();

  // Initialize notification service (requests permissions, gets token)
  final notificationService = container.read(notificationServiceProvider);
  await notificationService.initialize();

  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
}
