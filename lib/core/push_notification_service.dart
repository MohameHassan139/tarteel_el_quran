import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import '../firebase_options.dart';
import 'reminder_service.dart';
import 'teacher_sync_service.dart';
import '../routes/app_routes.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}
  debugPrint('FCM background message received: ${message.messageId}');

  // If the message has only a data payload (no standard notification block),
  // display it via local notifications so it still appears on screen while closed.
  if (message.notification == null && message.data.isNotEmpty) {
    final title = message.data['title'] as String? ?? 'ترتيل القرآن';
    final body = message.data['body'] as String? ?? message.data['message'] as String? ?? '';
    if (body.isNotEmpty) {
      try {
        final localPlugin = FlutterLocalNotificationsPlugin();
        const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
        await localPlugin.initialize(
          settings: const InitializationSettings(android: androidSettings),
        );
        final androidImpl = localPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (androidImpl != null) {
          await androidImpl.createNotificationChannel(
            const AndroidNotificationChannel(
              'daily_ward_channel',
              'Daily Ward Reminders',
              description: 'Fired to remind the user to complete their daily Quran reading goal.',
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
            ),
          );
          await androidImpl.createNotificationChannel(
            const AndroidNotificationChannel(
              'teacher_note_channel',
              'Teacher Notes',
              description: 'Notifies a student when their teacher sends a note.',
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
            ),
          );
        }
        final channelId = message.data['type'] == 'teacher_note' ? 'teacher_note_channel' : 'daily_ward_channel';
        final channelName = channelId == 'teacher_note_channel' ? 'Teacher Notes' : 'Daily Ward Reminders';
        final androidDetails = AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        );
        final noteId = message.data['noteId'] as String?;
        final notificationId = noteId != null ? noteId.hashCode : message.hashCode;
        await localPlugin.show(
          id: notificationId,
          title: title,
          body: body,
          notificationDetails: NotificationDetails(android: androidDetails),
        );
      } catch (e) {
        debugPrint('FCM background localPlugin show error: $e');
      }
    }
  }
}

class PushNotificationService extends GetxService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final RxnString fcmToken = RxnString();

  Future<PushNotificationService> init() async {
    try {
      // Request push notification permissions (iOS & Android 13+)
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('FCM authorization status: ${settings.authorizationStatus}');

      // Configure foreground presentation options on iOS
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Subscribe to general topics so broadcast notifications sent from Firebase Console reach all devices
      try {
        await _fcm.subscribeToTopic('all');
        await _fcm.subscribeToTopic('daily_ward');
      } catch (e) {
        debugPrint('FCM subscribeToTopic error: $e');
      }

      // Fetch FCM device registration token
      try {
        final token = await _fcm.getToken();
        fcmToken.value = token;
        debugPrint('FCM Device Token: $token');
        if (Get.isRegistered<TeacherSyncService>()) {
          final sync = Get.find<TeacherSyncService>();
          final studentUid = sync.studentUid.value;
          if (studentUid != null && token != null) {
            unawaited(sync.syncFcmToken(studentUid, token));
          }
        }
      } catch (e) {
        debugPrint('FCM getToken error: $e');
      }

      // Listen for token updates
      _fcm.onTokenRefresh.listen((newToken) {
        fcmToken.value = newToken;
        debugPrint('FCM Token refreshed: $newToken');
        if (Get.isRegistered<TeacherSyncService>()) {
          final sync = Get.find<TeacherSyncService>();
          final studentUid = sync.studentUid.value;
          if (studentUid != null) {
            unawaited(sync.syncFcmToken(studentUid, newToken));
          }
        }
      });

      // Create Android notification channels explicitly
      try {
        final localPlugin = FlutterLocalNotificationsPlugin();
        final androidImpl = localPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (androidImpl != null) {
          await androidImpl.createNotificationChannel(
            const AndroidNotificationChannel(
              'daily_ward_channel',
              'Daily Ward Reminders',
              description: 'Fired to remind the user to complete their daily Quran reading goal.',
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
            ),
          );
          await androidImpl.createNotificationChannel(
            const AndroidNotificationChannel(
              'teacher_note_channel',
              'Teacher Notes',
              description: 'Notifies a student when their teacher sends a note.',
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
            ),
          );
        }
      } catch (e) {
        debugPrint('PushNotificationService createNotificationChannels error: $e');
      }

      // Handle foreground messages with heads-up banner via local notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('FCM foreground message received: ${message.notification?.title ?? message.data['title']}');
        final notification = message.notification;
        final title = notification?.title ?? message.data['title'] as String? ?? 'ترتيل القرآن';
        final body = notification?.body ?? message.data['body'] as String? ?? message.data['message'] as String? ?? '';
        final noteId = message.data['noteId'] as String?;
        final notificationId = noteId != null ? noteId.hashCode : message.hashCode;

        if (body.isNotEmpty && Get.isRegistered<ReminderService>()) {
          Get.find<ReminderService>().showInstantNotification(
            id: notificationId,
            title: title,
            body: body,
          );
        }
      });

      // Handle notification interaction when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('FCM message opened from background: ${message.data}');
        _handleNotificationClick(message.data);
      });

      // Check if app was launched directly from a terminated state via a notification click
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('FCM initial message from terminated state: ${initialMessage.data}');
        _handleNotificationClick(initialMessage.data);
      }
    } catch (e) {
      debugPrint('PushNotificationService init error: $e');
    }

    return this;
  }

  void _handleNotificationClick(Map<String, dynamic> data) {
    debugPrint('PushNotificationService notification clicked with data: $data');
    final type = data['type'] as String?;
    if (type == 'teacher_note') {
      if (Get.currentRoute != AppRoutes.NOTIFICATIONS_INBOX) {
        Get.toNamed(AppRoutes.NOTIFICATIONS_INBOX);
      }
    }
  }
}
