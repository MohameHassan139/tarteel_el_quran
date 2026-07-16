import 'dart:math' as math;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:get/get.dart';
import 'storage_service.dart';

class ReminderService extends GetxService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static const int reminderId = 999;

  Future<ReminderService> init() async {
    // Initialize timezone database
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(settings: initSettings);

    // Request notification permissions for Android 13+
    _requestAndroidPermissions();
    
    // Reschedule on startup to keep rolling window updated
    try {
      await rescheduleAllReminders();
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

  /// Schedule a daily notification at a specific hour and minute.
  /// (Kept for compatibility with other files)
  Future<void> scheduleDailyReminder(int hour, int minute) async {
    await rescheduleAllReminders();
  }

  /// Reschedules 30 days of randomized reminder notifications.
  Future<void> rescheduleAllReminders() async {
    final storage = Get.find<StorageService>();
    final goal = storage.getWardGoal();
    
    // Cancel all previous scheduled notifications in the range
    for (int i = 0; i < 75; i++) {
      await _notificationsPlugin.cancel(id: reminderId + i);
    }

    final now = tz.TZDateTime.now(tz.local);
    final messages = storage.getReminderMessages();
    if (messages.isEmpty) return;

    final lang = storage.getAppLanguage();
    final isAr = lang == 'ar';
    final targetSeconds = goal.targetMinutes * 60;
    final activeSeconds = goal.activeSecondsToday;

    final rand = math.Random();

    for (int i = 0; i < 64; i++) {
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        goal.reminderHour,
        goal.reminderMinute,
      ).add(Duration(days: i));

      // For day 0 (today), if the reminder time has already passed today, skip scheduling it
      if (i == 0 && scheduledDate.isBefore(now)) {
        continue;
      }

      // Determine category for this day
      String category = 'start';
      if (i == 0) {
        if (activeSeconds >= targetSeconds) {
          category = 'completed';
        } else if (activeSeconds > 0) {
          category = 'incomplete';
        }
      }

      // Filter messages by category
      final categoryMsgs = messages.where((m) => m.category == category).toList();
      final selectedList = categoryMsgs.isNotEmpty ? categoryMsgs : messages;
      
      // Select random message
      final msg = selectedList[rand.nextInt(selectedList.length)];

      final String title = _getTitleForCategory(category, isAr);
      final String body = isAr ? msg.textAr : msg.textEn;

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'daily_ward_channel',
        'Daily Ward Reminders',
        channelDescription: 'Fired to remind the user to complete their daily Quran reading goal.',
        importance: Importance.max,
        priority: Priority.high,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

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

  String _getTitleForCategory(String category, bool isAr) {
    switch (category) {
      case 'completed':
        return isAr ? '🌸 أكملت الورد اليومي' : '🌸 Daily Wird Completed';
      case 'incomplete':
        return isAr ? '🌿 لم يُكمل الورد اليومي' : '🌿 Daily Wird Incomplete';
      case 'start':
      default:
        return isAr ? '📖 جاء موعد الورد اليومي' : '📖 Time for Daily Wird';
    }
  }

  Future<void> cancelReminder() async {
    for (int i = 0; i < 75; i++) {
      await _notificationsPlugin.cancel(id: reminderId + i);
    }
  }

  /// Fire an immediate completed/celebration notification.
  Future<void> triggerInstantTestNotification() async {
    await showCelebrationNotification();
  }

  /// Fires an immediate celebratory notification using randomized messages.
  Future<void> showCelebrationNotification() async {
    final storage = Get.find<StorageService>();
    final messages = storage.getReminderMessages();
    final lang = storage.getAppLanguage();
    final isAr = lang == 'ar';

    final categoryMsgs = messages.where((m) => m.category == 'completed').toList();
    final selectedList = categoryMsgs.isNotEmpty ? categoryMsgs : messages;
    
    if (selectedList.isEmpty) return;
    
    final rand = math.Random();
    final msg = selectedList[rand.nextInt(selectedList.length)];

    final String title = isAr ? '🌸 أكملت الورد اليومي' : '🌸 Daily Wird Completed';
    final String body = isAr ? msg.textAr : msg.textEn;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_ward_channel',
      'Daily Ward Reminders',
      channelDescription: 'Fired to remind the user to complete their daily Quran reading goal.',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      id: reminderId + 100, // Unique ID for instant celebration
      title: title,
      body: body,
      notificationDetails: platformDetails,
    );
  }
}
