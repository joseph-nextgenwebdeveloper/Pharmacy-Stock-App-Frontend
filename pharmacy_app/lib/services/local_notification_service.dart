import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const int _dailyReminderId = 1001;

  /// Set from main.dart: called with the tapped notification's payload
  /// (e.g. "alerts") so the app can open the right screen.
  static void Function(String? payload)? onTap;

  static const String stockChannelId = 'stock_alerts';

  static const NotificationDetails stockDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      stockChannelId,
      'Stock alerts',
      channelDescription:
          'Out-of-stock alerts, repeated every 2 hours until restocked.',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    ),
  );

  static Future<void> initialize() async {
    if (kIsWeb) {
      return;
    }

    tz.initializeTimeZones();
    try {
      // The pharmacy runs on Nairobi time; without this the plugin would
      // schedule "08:00" in UTC (11:00 in Nairobi).
      tz.setLocalLocation(tz.getLocation('Africa/Nairobi'));
    } catch (_) {}

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );

    // `initialize` takes the settings object positionally.
    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        onTap?.call(response.payload);
      },
    );

    await _requestPermissions();
  }

  /// Shows a notification right now.
  static Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;

    await _notifications.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          stockChannelId,
          'Stock alerts',
          channelDescription:
              'Out-of-stock alerts, repeated every 2 hours until restocked.',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
      payload: payload,
    );
  }

  /// Schedules a notification for [when] (device clock).
  static Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
  }) async {
    if (kIsWeb) return;

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          stockChannelId,
          'Stock alerts',
          channelDescription:
              'Out-of-stock alerts, repeated every 2 hours until restocked.',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  static Future<void> cancel(int id) async {
    if (kIsWeb) return;
    await _notifications.cancel(id);
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
