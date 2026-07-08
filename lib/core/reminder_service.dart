import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:get/get.dart';

class ReminderService extends GetxService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static const int reminderId = 999;

  Future<ReminderService> init() async {
    // Initialize timezone database
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notificationsPlugin.initialize(settings: initSettings);

    // Request notification permissions for Android 13+
    _requestAndroidPermissions();
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
  Future<void> scheduleDailyReminder(int hour, int minute) async {
    await cancelReminder(); // Remove any previous schedules

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If the scheduled time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_ward_channel',
      'Daily Ward Reminders',
      channelDescription: 'Fired to remind the user to complete their daily Quran reading goal.',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      id: reminderId,
      title: 'Tarteel Al-Quran Ward Reminder',
      body: 'Your daily reading Ward is incomplete. Spend a few minutes reading the Quran today!',
      scheduledDate: scheduledDate,
      notificationDetails: platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
    );
  }

  Future<void> cancelReminder() async {
    await _notificationsPlugin.cancel(id: reminderId);
  }

  /// Fire an immediate test notification.
  Future<void> triggerInstantTestNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_ward_channel',
      'Daily Ward Reminders',
      channelDescription: 'Fired to remind the user to complete their daily Quran reading goal.',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(
      id: reminderId + 1,
      title: 'Goal Accomplished! 🎉',
      body: 'Congratulations! You have completed your daily reading goal for today.',
      notificationDetails: platformDetails,
    );
  }
}
