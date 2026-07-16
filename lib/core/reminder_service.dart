import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:get/get.dart';
import 'storage_service.dart';
import 'reminder_messages.dart';

class ReminderService extends GetxService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static const int reminderId = 999;

  Future<ReminderService> init() async {
    // Initialize timezone database
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(settings: initSettings);

    // Request notification permissions for Android 13+ and iOS
    _requestAndroidPermissions();
    _requestIOSPermissions();

    // Automatically reschedule on init (rolls forward the 30 days daily reminder window)
    try {
      final storage = Get.find<StorageService>();
      final goal = storage.getWardGoal();
      await scheduleDailyReminder(goal.reminderHour, goal.reminderMinute);
    } catch (_) {}

    return this;
  }

  Future<void> _requestAndroidPermissions() async {
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
    }
  }

  Future<void> _requestIOSPermissions() async {
    final iosPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  /// Schedule a daily notification at a specific hour and minute for the next 30 days.
  Future<void> scheduleDailyReminder(int hour, int minute) async {
    await cancelReminder(); // Remove any previous schedules

    final storage = Get.find<StorageService>();
    final lang = storage.getAppLanguage();
    final goal = storage.getWardGoal();
    final targetSeconds = goal.targetMinutes * 60;
    
    final randomSeed = DateTime.now().millisecond;
    final now = tz.TZDateTime.now(tz.local);
    final todayScheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_ward_channel',
      'Daily Ward Reminders',
      channelDescription: 'Fired to remind the user to complete their daily Quran reading goal.',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    for (int i = 0; i < 30; i++) {
      final scheduledDate = todayScheduled.add(Duration(days: i));

      // If scheduled time for today (i == 0) has already passed, skip today
      if (i == 0 && scheduledDate.isBefore(now)) {
        continue;
      }

      // Determine category based on day and current progress
      String category;
      String title;
      List<ReminderMessage> messages;

      if (i == 0) {
        // Today's actual progress
        final active = goal.activeSecondsToday;
        if (active == 0) {
          category = 'start';
        } else if (active < targetSeconds) {
          category = 'incomplete';
        } else {
          category = 'completed';
        }
      } else {
        // Future days start with 0 progress initially
        category = 'start';
      }

      // Select random message from the category
      if (category == 'start') {
        messages = ReminderMessages.startWird;
        title = lang == 'ar' ? '📖 جاء موعد الورد اليومي' : '📖 Time for Daily Wird';
      } else if (category == 'incomplete') {
        messages = ReminderMessages.incompleteWird;
        title = lang == 'ar' ? '🌿 لم يُكمل الورد اليومي' : '🌿 Daily Wird Incomplete';
      } else {
        messages = ReminderMessages.completedWird;
        title = lang == 'ar' ? '🌸 أكمل الورد اليومي' : '🌸 Daily Wird Completed';
      }

      if (messages.isEmpty) continue;
      
      final messageIndex = (randomSeed + i) % messages.length;
      final selectedMsg = messages[messageIndex];
      final body = lang == 'ar' ? selectedMsg.textAr : selectedMsg.textEn;

      await _notificationsPlugin.zonedSchedule(
        id: reminderId + i,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  Future<void> cancelReminder() async {
    for (int i = 0; i < 30; i++) {
      await _notificationsPlugin.cancel(id: reminderId + i);
    }
  }

  /// Fire an immediate celebration notification.
  Future<void> triggerCelebrationNotification() async {
    final storage = Get.find<StorageService>();
    final lang = storage.getAppLanguage();

    final messages = ReminderMessages.completedWird;
    if (messages.isEmpty) return;

    final randomSeed = DateTime.now().millisecond;
    final selectedMsg = messages[randomSeed % messages.length];
    
    final title = lang == 'ar' ? '🌸 أكمل الورد اليومي' : '🌸 Daily Wird Completed';
    final body = lang == 'ar' ? selectedMsg.textAr : selectedMsg.textEn;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_ward_channel',
      'Daily Ward Reminders',
      channelDescription: 'Fired to remind the user to complete their daily Quran reading goal.',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id: reminderId + 100, // Celebration Notification ID
      title: title,
      body: body,
      notificationDetails: platformDetails,
    );

    // Also reschedule future reminders so that today's reminder is updated to Case 3 (Completed)
    final goal = storage.getWardGoal();
    await scheduleDailyReminder(goal.reminderHour, goal.reminderMinute);
  }

  /// Fire an immediate test notification simulating progress.
  Future<void> triggerInstantTestNotification() async {
    final storage = Get.find<StorageService>();
    final lang = storage.getAppLanguage();
    final goal = storage.getWardGoal();
    final targetSeconds = goal.targetMinutes * 60;
    final active = goal.activeSecondsToday;

    String title;
    List<ReminderMessage> messages;

    if (active == 0) {
      title = lang == 'ar' ? '📖 جاء موعد الورد اليومي' : '📖 Time for Daily Wird';
      messages = ReminderMessages.startWird;
    } else if (active < targetSeconds) {
      title = lang == 'ar' ? '🌿 لم يُكمل الورد اليومي' : '🌿 Daily Wird Incomplete';
      messages = ReminderMessages.incompleteWird;
    } else {
      title = lang == 'ar' ? '🌸 أكمل الورد اليومي' : '🌸 Daily Wird Completed';
      messages = ReminderMessages.completedWird;
    }

    if (messages.isEmpty) return;

    final randomSeed = DateTime.now().millisecond;
    final selectedMsg = messages[randomSeed % messages.length];
    final body = lang == 'ar' ? selectedMsg.textAr : selectedMsg.textEn;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_ward_channel',
      'Daily Ward Reminders',
      channelDescription: 'Fired to remind the user to complete their daily Quran reading goal.',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id: reminderId + 101, // Test Notification ID
      title: '$title (Test)',
      body: body,
      notificationDetails: platformDetails,
    );
  }
}

