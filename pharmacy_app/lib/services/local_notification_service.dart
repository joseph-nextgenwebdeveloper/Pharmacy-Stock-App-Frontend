import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const int _dailyReminderId = 1001;

  static Future<void> initialize() async {
    if (kIsWeb) {
      return;
    }

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );

    // `initialize` takes the settings object positionally.
    await _notifications.initialize(initializationSettings);

    await _requestPermissions();
  }

  static Future<void> _requestPermissions() async {
    if (kIsWeb) {
      return;
    }

    final androidImplementation = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidImplementation?.requestNotificationsPermission();
  }

  static Future<void> scheduleDailyInventoryReminder({
    int hour = 8,
    int minute = 0,
  }) async {
    if (kIsWeb) {
      return;
    }

    // `cancel` takes the notification id positionally.
    await _notifications.cancel(_dailyReminderId);

    final now = tz.TZDateTime.now(tz.local);

    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (!scheduledDate.isAfter(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // id, title, body, scheduledDate and notificationDetails are all
    // positional; only androidScheduleMode / matchDateTimeComponents are named.
    await _notifications.zonedSchedule(
      _dailyReminderId,
      'Daily Inventory Reminder',
      'Remember to review today\'s pharmacy inventory.',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_inventory_reminder',
          'Daily Inventory Reminders',
          channelDescription:
              'Daily reminders to review pharmacy inventory.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancelDailyInventoryReminder() async {
    if (kIsWeb) {
      return;
    }

    await _notifications.cancel(_dailyReminderId);
  }
}
