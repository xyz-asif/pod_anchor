import 'dart:convert';
import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:chatbee/features/notifications/repos/notification_repo.dart';
import 'package:chatbee/features/notifications/utils/notification_navigator.dart';

part 'notification_service.g.dart';

/// Top-level function to handle background FCM messages.
/// This must not be an anonymous function or a class method.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  log('Handling a background message: ${message.messageId}', name: 'FCM');
}

/// A service wrapper for handling Firebase Cloud Messaging and local notifications.
class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Pending notification data from app launch via terminated state.
  Map<String, dynamic>? _pendingNotificationData;

  /// Call this once after Firebase.initializeApp().
  /// Handles permissions, local notification setup, and message handlers.
  /// Does NOT register FCM token with backend (requires auth).
  Future<void> initialize() async {
    if (_isInitialized) return;

    await requestPermissions();
    await _setupLocalNotifications();
    _setupMessageHandlers();

    // Get FCM token (for logging/debugging)
    await getFCMToken();

    _isInitialized = true;
  }

  /// Call after login when API client has a valid auth token.
  /// Registers the FCM token with the backend and listens for token refresh.
  Future<void> registerTokenWithBackend(NotificationRepo repo) async {
    final token = await _fcm.getToken();
    if (token != null) {
      try {
        await repo.registerFCMToken(token);
        log('FCM token registered with backend', name: 'FCM');
      } catch (e) {
        log('Failed to register FCM token: $e', name: 'FCM');
      }
    }

    _fcm.onTokenRefresh.listen((newToken) async {
      try {
        await repo.registerFCMToken(newToken);
        log('Refreshed FCM token registered', name: 'FCM');
      } catch (_) {}
    });
  }

  /// Check and handle pending notification navigation (call after app is ready).
  void handlePendingNotification(BuildContext context) {
    if (_pendingNotificationData != null) {
      _handleNotificationNavigation(context, _pendingNotificationData!);
      _pendingNotificationData = null;
    }
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
      return token;
    } catch (e) {
      log('Failed to get FCM token: $e', name: 'FCM_ERROR');
      return null;
    }
  }

  Future<void> _setupLocalNotifications() async {
    const androidChannel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
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
        // Parse the payload back to a Map and navigate
        if (response.payload != null) {
          try {
            final data = jsonDecode(response.payload!) as Map<String, dynamic>;
            // Store for later navigation (context not available here)
            _pendingNotificationData = data;
          } catch (_) {}
        }
      },
    );

    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  void _setupMessageHandlers() {
    // 1. Foreground messages
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
      _handleNotificationTap(message.data);
    });

    // 3. Check if app was launched from a notification (terminated state)
    _fcm.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        log(
          'App launched from terminated state via notification',
          name: 'FCM',
        );
        _pendingNotificationData = message.data;
      }
    });
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    // Store the data for navigation when context is available
    _pendingNotificationData = data;
  }

  void _handleNotificationNavigation(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final resourceType = data['resourceType'] as String?;
    final resourceId = data['resourceId'] as String?;

    if (resourceType != null && resourceId != null) {
      navigateToNotification(context, resourceType, resourceId);
    }
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
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription:
                'This channel is used for important notifications.',
            icon: '@mipmap/ic_launcher',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }
}

@riverpod
NotificationService notificationService(Ref ref) {
  return NotificationService();
}
