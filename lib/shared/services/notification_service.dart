import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
// TODO: Uncomment the line below and ensure firebase_options.dart is generated
import 'package:intl/intl.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
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

    // Initialize timezones for scheduled notifications
    tz.initializeTimeZones();

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
    try {
      final String? token = await _fcm.getToken();
      if (token != null) {
        await _saveTokenToFirestore(token);
      }
    } catch (e) {
      debugPrint('Error getting initial FCM token: $e');
    }

    // 6. Listen for token refreshes
    _fcm.onTokenRefresh.listen((newToken) {
      _saveTokenToFirestore(newToken);
    });

    // 7. Listen to auth state changes to save token and schedule reminders on login
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        try {
          final String? token = await _fcm.getToken();
          if (token != null) {
            await _saveTokenToFirestore(token);
          }
        } catch (_) {}
        await scheduleAllUpcomingReminders();
      }
    });

    // Run scheduled reminders scanner immediately if already logged in
    if (FirebaseAuth.instance.currentUser != null) {
      scheduleAllUpcomingReminders();
    }
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

  Future<void> showInstantLocalNotification(
    String title,
    String body,
    Map<String, dynamic> payload,
  ) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          icon: '@mipmap/ic_launcher',
          priority: Priority.high,
          importance: Importance.high,
          playSound: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(payload),
    );
  }

  // --- Part 1: Save Token to Firestore ---
  Future<void> _saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Save to users collection
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'tokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Check if lawyer doc exists and update it too
      final lawyerDoc = await FirebaseFirestore.instance.collection('lawyers').doc(user.uid).get();
      if (lawyerDoc.exists) {
        await FirebaseFirestore.instance.collection('lawyers').doc(user.uid).set({
          'fcmToken': token,
          'tokenUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
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
      // Try fetching token from users collection
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUserId)
          .get();
      String? token = userDoc.data()?['fcmToken'];

      // If not found, try lawyers collection
      if (token == null || token.isEmpty) {
        final lawyerDoc = await FirebaseFirestore.instance
            .collection('lawyers')
            .doc(targetUserId)
            .get();
        token = lawyerDoc.data()?['fcmToken'];
      }

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

  // --- Part 5: Create Firestore Record and Send Push ---
  Future<void> createAndSendNotification({
    required String targetUserId,
    required String title,
    required String body,
    required String type, // 'appointment', 'transaction', 'video_call', etc.
    required String referenceId,
  }) async {
    try {
      // 1. Save to Firestore so it appears in the Notification Widget
      await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUserId)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'type': type,
        'referenceId': referenceId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Send the Push Notification
      await sendPushNotification(
        targetUserId,
        title,
        body,
        data: {'type': type, 'referenceId': referenceId},
      );

      // 3. If target is the current user, show local heads-up notification immediately
      if (FirebaseAuth.instance.currentUser?.uid == targetUserId) {
        await showInstantLocalNotification(
          title, 
          body, 
          {'type': type, 'referenceId': referenceId}
        );
      }
    } catch (e) {
      debugPrint('Error creating and sending notification: $e');
    }
  }

  // --- Part 6: Schedule Local Notification for Meetings ---
  Future<void> scheduleOnlineMeetingReminder({
    required String meetingId,
    required String title,
    required String body,
    required DateTime meetingTime,
  }) async {
    // Calculate 30 minutes before the meeting
    final scheduledTime = meetingTime.subtract(const Duration(minutes: 30));
    
    // Only schedule if it's in the future
    if (scheduledTime.isBefore(DateTime.now())) return;

    try {
      await _localNotifications.zonedSchedule(
        meetingId.hashCode,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: jsonEncode({'type': 'video_call', 'referenceId': meetingId}),
      );
      debugPrint('Scheduled reminder for meeting $meetingId at $scheduledTime');
    } catch (e) {
      debugPrint('Failed to schedule meeting reminder: $e');
    }
  }

  // --- Part 7: Schedule reminders for all upcoming meetings ---
  Future<void> scheduleLocalReminder({
    required String reminderId,
    required String title,
    required String body,
    required DateTime eventTime,
    required Duration offset,
    required Map<String, dynamic> payload,
  }) async {
    final scheduledTime = eventTime.subtract(offset);
    if (scheduledTime.isBefore(DateTime.now())) return;

    try {
      await _localNotifications.zonedSchedule(
        reminderId.hashCode,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: jsonEncode(payload),
      );
      debugPrint('Scheduled reminder $reminderId at $scheduledTime');
    } catch (e) {
      debugPrint('Failed to schedule reminder $reminderId: $e');
    }
  }

  Future<void> scheduleAllUpcomingReminders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // --- 1. APPOINTMENTS ---
      final clientSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('userId', isEqualTo: user.uid)
          .get();
          
      final lawyerSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('lawyerId', isEqualTo: user.uid)
          .get();

      final allAppts = [...clientSnapshot.docs, ...lawyerSnapshot.docs];
      
      for (final doc in allAppts) {
        final data = doc.data();
        final status = data['status'] ?? data['bookingStatus'] ?? '';
        if (status == 'cancelled') continue;

        final type = data['consultationType'] ?? data['type'] ?? 'online';
        final dateLabel = data['day'] ?? data['dateLabel'] ?? '';
        final timeRange = data['time'] ?? data['timeRange'] ?? '';
        if (dateLabel.isEmpty || timeRange.isEmpty) continue;

        // Parse date and time
        final meetingTime = _parseDateTime(dateLabel, timeRange);
        if (meetingTime == null) continue;

        final isLawyer = data['lawyerId'] == user.uid;
        final otherName = isLawyer 
            ? (data['userName'] ?? 'Client'.translate()) 
            : (data['lawyerName'] ?? 'Lawyer'.translate());

        if (type == 'online') {
          // Schedule online meeting reminder (30 minutes before)
          await scheduleLocalReminder(
            reminderId: 'online_${doc.id}',
            title: 'Upcoming Video Consultation'.translate(),
            body: isLawyer 
                ? '${'Your meeting with client'.translate()} $otherName ${'starts in 30 minutes.'.translate()}'
                : '${'Your meeting with lawyer'.translate()} $otherName ${'starts in 30 minutes.'.translate()}',
            eventTime: meetingTime,
            offset: const Duration(minutes: 30),
            payload: {'type': 'video_call', 'referenceId': doc.id},
          );
        } else {
          // Schedule office meeting reminder (1 hour before)
          await scheduleLocalReminder(
            reminderId: 'office_${doc.id}',
            title: 'Upcoming Office Consultation'.translate(),
            body: isLawyer 
                ? '${'Your appointment with client'.translate()} $otherName ${'starts in 1 hour.'.translate()}'
                : '${'Your appointment with lawyer'.translate()} $otherName ${'starts in 1 hour.'.translate()}',
            eventTime: meetingTime,
            offset: const Duration(hours: 1),
            payload: {'type': 'appointment', 'referenceId': doc.id},
          );
        }
      }

      // --- 2. COURT SESSIONS (GALSAT) ---
      final clientCases = await FirebaseFirestore.instance
          .collection('cases')
          .where('clientId', isEqualTo: user.uid)
          .get();

      final lawyerCases = await FirebaseFirestore.instance
          .collection('cases')
          .where('lawyerId', isEqualTo: user.uid)
          .get();

      final allCases = [...clientCases.docs, ...lawyerCases.docs];

      for (final doc in allCases) {
        final caseData = doc.data();
        final caseTitle = caseData['title'] ?? 'Case'.translate();
        final sessions = caseData['sessions'] as List<dynamic>? ?? [];

        for (int i = 0; i < sessions.length; i++) {
          final session = sessions[i] as Map<String, dynamic>;
          final status = session['status'] ?? 'scheduled';
          if (status == 'cancelled') continue;

          final scheduledDate = (session['scheduledDate'] as Timestamp?)?.toDate();
          if (scheduledDate == null) continue;

          // Schedule court session reminder (2 hours before)
          await scheduleLocalReminder(
            reminderId: 'session_${doc.id}_$i',
            title: 'Upcoming Court Session'.translate(),
            body: '${'Court Session today for case'.translate()} "$caseTitle" ${'starts in 2 hours.'.translate()}',
            eventTime: scheduledDate,
            offset: const Duration(hours: 2),
            payload: {'type': 'court_session', 'referenceId': doc.id},
          );
        }
      }
    } catch (e) {
      debugPrint('Error scheduling upcoming reminders: $e');
    }
  }

  DateTime? _parseDateTime(String dateLabel, String timeRange) {
    try {
      // dateLabel is like "Tuesday, 9 Jun 2026" or "10 Nov 2026"
      String cleanDate = dateLabel;
      if (dateLabel.contains(',')) {
        cleanDate = dateLabel.split(',').last.trim(); // "9 Jun 2026"
      }
      
      DateTime? parsedDate;
      final formats = [
        'd MMM yyyy',
        'dd MMM yyyy',
        'yyyy-MM-dd',
        'dd/MM/yyyy',
      ];
      for (final format in formats) {
        try {
          parsedDate = DateFormat(format).parse(cleanDate);
          break;
        } catch (_) {}
      }
      if (parsedDate == null) return null;

      // Parse timeRange like "10:00 AM - 11:00 AM" or "10:00 AM"
      final cleanTime = timeRange.split('-')[0].trim(); // "10:00 AM"
      final parts = cleanTime.split(' '); // ["10:00", "AM"]
      final hms = parts[0].split(':'); // ["10", "00"]
      int hour = int.parse(hms[0]);
      final minute = hms.length > 1 ? int.parse(hms[1]) : 0;
      final amPm = parts.length > 1 ? parts[1].toUpperCase() : 'AM';
      
      if (amPm == 'PM' && hour < 12) {
        hour += 12;
      } else if (amPm == 'AM' && hour == 12) {
        hour = 0;
      }
      return DateTime(parsedDate.year, parsedDate.month, parsedDate.day, hour, minute);
    } catch (e) {
      debugPrint('Error parsing date time: $e');
      return null;
    }
  }
}
