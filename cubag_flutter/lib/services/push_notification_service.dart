import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import '../core/router.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

class PushNotificationService {
  FirebaseMessaging get _firebaseMessaging => FirebaseMessaging.instance;

  Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint("Firebase Messaging is skipped on Web.");
      return;
    }
    try {
      await Firebase.initializeApp();

      // Request permissions for iOS
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted permission');
      } else {
        debugPrint('User declined or has not accepted permission');
      }

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');

        if (message.notification != null) {
          debugPrint('Message also contained a notification: ${message.notification}');
        }
      });

      // ── Deep link: app opened from notification tap (background → foreground) ──
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('Notification tapped (background): ${message.data}');
        _handleDeepLink(message.data);
      });

      // ── Deep link: app opened from terminated state via notification ──
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('App launched from notification (terminated): ${initialMessage.data}');
        // Small delay to let the app initialize before routing
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleDeepLink(initialMessage.data);
        });
      }

      // Get the token for this device to send it to the Flask backend
      try {
        String? token = await _firebaseMessaging.getToken();
        debugPrint("FCM Token: $token");
        if (token != null) {
          final apiService = ApiService();
          // Fire and forget to register the device token
          apiService.postData('/auth/update-fcm-token', {'token': token}).catchError((e) {
            debugPrint('Failed to save FCM token: $e');
          });
        }
      } catch (e) {
        debugPrint('Error getting FCM token: $e');
      }
    } catch (e) {
      debugPrint('Firebase messaging initialization skipped or failed: $e');
    }
  }

  /// Navigate to the correct page based on notification payload.
  /// Expects data like: { "type": "announcement", "id": "123", "route": "/announcements" }
  void _handleDeepLink(Map<String, dynamic> data) {
    final route = data['route']?.toString();
    final type = data['type']?.toString();

    if (route != null && route.isNotEmpty) {
      // Explicit route from backend
      appRouter.go(route);
      return;
    }

    // Infer route from type
    switch (type) {
      case 'announcement':
        appRouter.go('/announcements');
        break;
      case 'task':
        appRouter.go('/tasks');
        break;
      case 'payment':
        appRouter.go('/payments');
        break;
      case 'schedule':
        appRouter.go('/vanning-schedules');
        break;
      case 'ticket':
        appRouter.go('/engagement');
        break;
      case 'message':
        appRouter.go('/messaging');
        break;
      case 'license':
        appRouter.go('/license-renewal');
        break;
      default:
        appRouter.go('/notifications');
    }
  }
}
