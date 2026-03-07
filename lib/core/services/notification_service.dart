import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notification_service.g.dart';

/// Top-level function to handle background FCM messages.
/// This must not be an anonymous function or a class method.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  log('Handling a background message: ${message.messageId}', name: 'FCM');
  // You can initialize other Firebase services or local databases here if needed
}

/// A service wrapper for handling Firebase Cloud Messaging and local notifications.
class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Call this once after Firebase.initializeApp()
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 1. Request permissions (especially useful on iOS)
    await requestPermissions();

    // 2. Setup local notifications for Android foreground alerts
    await _setupLocalNotifications();

    // 3. Listen to state changes
    _setupMessageHandlers();

    // 4. Get FCM Token
    await getFCMToken();

    _isInitialized = true;
  }

  Future<void> requestPermissions() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );
    log(
      'User granted permission: ${settings.authorizationStatus}',
      name: 'FCM',
    );
  }

  Future<String?> getFCMToken() async {
    try {
      final token = await _fcm.getToken();
      log('FCM Token: $token', name: 'FCM');
      // Typically, here you would send the token to your backend via API
      return token;
    } catch (e) {
      log('Failed to get FCM token: $e', name: 'FCM_ERROR');
      return null;
    }
  }

  Future<void> _setupLocalNotifications() async {
    const androidChannel = AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // title
      description:
          'This channel is used for important notifications.', // description
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);

    const initializationSettingsAndroid = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // For iOS configuration using latest version
    const initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        log('Local notification tapped: ${response.payload}', name: 'FCM');
        // Handle local notification tap here
      },
    );

    // Update foreground presentation options for iOS
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true, // Required to display a heads up notification
      badge: true,
      sound: true,
    );
  }

  void _setupMessageHandlers() {
    // 1. Foregound messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log('Received foreground message: ${message.messageId}', name: 'FCM');
      _showLocalNotification(message);
    });

    // 2. When the app is opened from a background state
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      log(
        'Message clicked! App opened from background: ${message.messageId}',
        name: 'FCM',
      );
      // Handle navigation logic based on message data here
    });

    // 3. (Optional) Check if app was launched directly from a notification (Terminated state)
    _fcm.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        log(
          'App launched from terminated state via notification: ${message.messageId}',
          name: 'FCM',
        );
        // Handle initial navigation or setup here
      }
    });
  }

  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null && android != null) {
      _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel', // Must match the channel created in _setupLocalNotifications
            'High Importance Notifications',
            channelDescription:
                'This channel is used for important notifications.',
            icon: '@mipmap/ic_launcher',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: message.data.toString(), // Pass custom data payload
      );
    }
  }
}

@riverpod
NotificationService notificationService(Ref ref) {
  return NotificationService();
}
