import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:get/get.dart';
import 'storage_service.dart';
import 'reminder_messages.dart';

class ReminderService extends GetxService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static const int reminderId = 999;
  static const String teacherNoteChannelId = 'teacher_note_channel';

  Future<ReminderService> init() async {
    try {
      // Initialize timezone database and set device local timezone
      tz.initializeTimeZones();
      try {
        final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));
      } catch (tzError) {
        debugPrint('ReminderService: error setting local timezone: $tzError');
      }

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

      // Create Android notification channels explicitly
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'daily_ward_channel',
            'Daily Ward Reminders',
            description: 'Fired to remind the user to complete their daily Quran reading goal.',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            teacherNoteChannelId,
            'Teacher Notes',
            description: 'Notifies a student when their teacher sends a note.',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
      }

      // Automatically reschedule in background on init (rolls forward the 30 days daily reminder window)
      final storage = Get.find<StorageService>();
      final goal = storage.getWardGoal();
      unawaited(scheduleDailyReminder(goal.reminderHour, goal.reminderMinute));
    } catch (e) {
      // Non-fatal trace — ensure service registration never breaks app startup
      debugPrint('ReminderService: init error: $e');
    }

    return this;
  }

  /// Request runtime notification permissions for Android 13+ and iOS.
  Future<bool> requestPermissions() async {
    bool granted = true;
    try {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final res = await androidPlugin.requestNotificationsPermission();
        if (res != null) granted = res;
      }
      final iosPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        final res = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        if (res != null) granted = granted && res;
      }
    } catch (e) {
      debugPrint('ReminderService: requestPermissions error: $e');
    }
    return granted;
  }


  /// Whether exact-time alarms are currently permitted.
  Future<bool> _canScheduleExact() async {
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return false;
    try {
      return await androidPlugin.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Request exact alarm permission from Android settings if not already granted.
  Future<bool> checkAndRequestExactAlarmPermission() async {
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return true;
    try {
      final canExact = await androidPlugin.canScheduleExactNotifications() ?? false;
      if (!canExact) {
        await androidPlugin.requestExactAlarmsPermission();
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Schedule a daily notification at a specific hour and minute for the next 30 days.
  Future<bool> scheduleDailyReminder(int hour, int minute, {bool promptPermission = false}) async {
    bool hasPermission = true;
    if (promptPermission) {
      hasPermission = await requestPermissions();
    }
    await cancelReminder(); // Remove any previous schedules

    // Fall back to an inexact (but still daily, still reliable) schedule
    // instead of throwing when exact-alarm permission hasn't been granted —
    // the reminder still fires, just within a short OS-chosen window instead
    // of to-the-minute.
    final scheduleMode = await _canScheduleExact()
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

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

      try {
        await _notificationsPlugin.zonedSchedule(
          id: reminderId + i,
          title: title,
          body: body,
          scheduledDate: scheduledDate,
          notificationDetails: platformDetails,
          androidScheduleMode: scheduleMode,
        );
      } catch (e) {
        // Fall back gracefully to inexact schedule if exact alarm fails on Android 14+
        if (scheduleMode == AndroidScheduleMode.exactAllowWhileIdle) {
          try {
            await _notificationsPlugin.zonedSchedule(
              id: reminderId + i,
              title: title,
              body: body,
              scheduledDate: scheduledDate,
              notificationDetails: platformDetails,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            );
          } catch (fallbackError) {
            debugPrint('ReminderService: inexact fallback zonedSchedule error: $fallbackError');
          }
        } else {
          debugPrint('ReminderService: zonedSchedule error: $e');
        }
      }
    }
    return hasPermission;
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
    await requestPermissions();
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

  /// Logs N seconds of activity toward the daily ward goal — from ANY
  /// feature (Mushaf reading, Hifz practice, Audio Hub listening), not just
  /// Mushaf — and fires the celebration notification if this call is what
  /// pushes today's total across the target. Centralized here so all three
  /// callers share one goal-crossing check instead of duplicating it.
  Future<void> logWardProgress(int seconds) async {
    final storage = Get.find<StorageService>();
    final goalBefore = storage.getWardGoal();
    final targetSeconds = goalBefore.targetMinutes * 60;
    final beforeSeconds = goalBefore.activeSecondsToday;

    await storage.logReadingSeconds(seconds);

    final goalAfter = storage.getWardGoal();
    final afterSeconds = goalAfter.activeSecondsToday;

    if (beforeSeconds < targetSeconds && afterSeconds >= targetSeconds) {
      await triggerCelebrationNotification();
    }
  }

  /// Generic instant notification, used for things that aren't the daily
  /// ward reminder (e.g. a teacher's note arriving). Only fires while this
  /// app process is alive — there is no server component sending real push,
  /// so a fully-closed app will not receive this.
  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      teacherNoteChannelId,
      'Teacher Notes',
      channelDescription: 'Notifies a student when their teacher sends a note.',
      importance: Importance.max,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const platformDetails = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformDetails,
    );
  }
}

