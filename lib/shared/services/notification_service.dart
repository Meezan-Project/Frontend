import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
// TODO: Uncomment the line below and ensure firebase_options.dart is generated
// import 'package:mezaan/firebase_options.dart';

// --- Part 2: Background Message Handler ---
// This must be a top-level function annotated with @pragma('vm:entry-point')
// to ensure it is not stripped away in release mode by the Dart compiler.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Firebase.initializeApp(); // Fallback if no options are used
  debugPrint("Handling a background message: ${message.messageId}");
}

class NotificationService {
  // Singleton pattern setup
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // TODO: Replace with your actual PHP backend URL
  final String _phpBackendUrl = 'https://your-domain.com/send_notification.php';

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'mezaan_high_importance_channel',
    'High Importance Notifications',
    description: 'Used for important alerts like SOS or transaction updates.',
    importance: Importance.high,
  );

  // Stream to broadcast tapped notification data for navigation
  final StreamController<Map<String, dynamic>> _notificationTapStream =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNotificationTap =>
      _notificationTapStream.stream;

  // --- Part 1 & 2: Initialization, Permissions, Foreground Handling ---
  Future<void> init() async {
    // 1. Request permissions for iOS (and some Android versions)
    final NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted notification permissions');
    } else {
      debugPrint('User declined or has not accepted notification permissions');
    }

    // 2. Set up the background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 3. Set up Local Notifications for Foreground display
    if (!kIsWeb) {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings();

      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
          );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null) {
            try {
              final data =
                  jsonDecode(response.payload!) as Map<String, dynamic>;
              _handleMessageTap(data);
            } catch (e) {
              debugPrint('Error parsing local notification payload: $e');
            }
          }
        },
      );

      // Create a high-priority Android channel to ensure heads-up popups
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);
    }

    // Configure foreground presentation options for iOS
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 4. Listen to Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Received a message while in the foreground!');

      if (message.notification != null) {
        _showLocalNotification(message);
      }
    });

    // Handle notification tap when app is in the background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notification clicked from background!');
      _handleMessageTap(message.data);
    });

    // Handle notification tap when app is terminated
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('Notification clicked from terminated state!');
      // Delay slightly to ensure listeners in the UI are attached
      Future.delayed(
        const Duration(seconds: 1),
        () => _handleMessageTap(initialMessage.data),
      );
    }

    // 5. Get initial FCM token and save to Firestore
    final String? token = await _fcm.getToken();
    if (token != null) {
      await _saveTokenToFirestore(token);
    }

    // 6. Listen for token refreshes
    _fcm.onTokenRefresh.listen((newToken) {
      _saveTokenToFirestore(newToken);
    });
  }

  void _handleMessageTap(Map<String, dynamic> data) {
    debugPrint('Notification tapped with data: $data');
    _notificationTapStream.add(data);
  }

  // Internal method to trigger the Heads-up foreground popup
  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null && android != null && !kIsWeb) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            icon: '@mipmap/ic_launcher',
            priority: Priority.high,
            importance: Importance.high,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  // --- Part 1: Save Token to Firestore ---
  Future<void> _saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'tokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to save FCM token: $e');
    }
  }

  // --- Part 4: Trigger Push Notification via PHP Backend ---
  Future<void> sendPushNotification(
    String targetUserId,
    String title,
    String body, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUserId)
          .get();
      final token = userDoc.data()?['fcmToken'];

      if (token == null || token.toString().isEmpty) return;

      await http.post(
        Uri.parse(_phpBackendUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'token': token,
          'title': title,
          'body': body,
          'data': data ?? {},
        }),
      );
    } catch (e) {
      debugPrint('Error triggering push notification: $e');
    }
  }
}
