import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/batch.dart';
import '../models/medicine.dart';
import 'local_notification_service.dart';

/// Phone notifications - exactly two a day at most:
///
///  * ONE "out of stock" summary per day while anything is at 0 units;
///  * ONE "expired" summary per day while an expired batch still holds stock.
///
/// Each one lists the items (not one notification per item) and stops as
/// soon as the app sees the problem fixed. They are scheduled on the phone
/// for [reminderHour]:00 every day (so they arrive even when the app is
/// closed). If the problem is first seen after that hour and today's
/// notification has not been sent yet, it is sent right away - still only
/// once for that day.
class StockAlertService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _kPref = 'pref_stock_alerts';

  static const int reminderHour = 8;
  static const int _daysAhead = 7;

  // Notification ids: a block of 7 for each kind, plus the "right now" one.
  static const int _outFirstId = 3000;
  static const int _outNowId = 2998;
  static const int _expFirstId = 3100;
  static const int _expNowId = 2997;

  static const String payload = 'alerts';

  static bool _running = false;

  static Future<bool> isEnabled() async {
    try {
      return (await _storage.read(key: _kPref)) != '0';
    } catch (_) {
      return true;
    }
  }

  static Future<void> setEnabled(bool value) async {
    try {
      await _storage.write(key: _kPref, value: value ? '1' : '0');
    } catch (_) {}
    if (!value) await clear();
  }

  /// Out of stock. Call with the freshly loaded medicines. Never throws.
  static Future<void> sync(List<Medicine> medicines) async {
    final out = medicines.where((m) => m.quantity <= 0).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    await _syncKind(
      key: 'out',
      firstId: _outFirstId,
      nowId: _outNowId,
      items: out.map((m) => m.name).toList(),
      title: (n) => n == 1 ? 'Out of stock' : '$n medicines out of stock',
      body: (names) =>
          '${_join(names)} ${names.length == 1 ? 'has' : 'have'} run out. '
          'Add stock to stop this daily reminder.',
    );
  }

  /// Expired batches that still hold stock. Never throws.
  static Future<void> syncExpired(List<Batch> batches) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final expired = batches.where((b) {
      final e = b.expiry;
      return b.quantity > 0 && e != null && e.isBefore(today);
    }).toList()
      ..sort((a, b) => a.medicineName.compareTo(b.medicineName));

    await _syncKind(
      key: 'expired',
      firstId: _expFirstId,
      nowId: _expNowId,
      items: expired
          .map((b) => b.medicineName.isEmpty
              ? 'Batch ${b.batchNumber}'
              : '${b.medicineName} (${b.batchNumber})')
          .toList(),
      title: (n) => n == 1 ? 'Expired product' : '$n expired products',
      body: (names) =>
          '${_join(names)} ${names.length == 1 ? 'has' : 'have'} expired and '
          'still ${names.length == 1 ? 'has' : 'have'} stock. Remove it from '
          'the shelf and write it off to stop this daily reminder.',
    );
  }

  /// Sign-out: stop every reminder and forget the state.
  static Future<void> clear() async {
    try {
      await _cancelAll('out', _outFirstId, _outNowId);
      await _cancelAll('expired', _expFirstId, _expNowId);
    } catch (_) {}
  }

  // ------------------------------------------------------------ internals

  static Future<void> _syncKind({
    required String key,
    required int firstId,
    required int nowId,
    required List<String> items,
    required String Function(int count) title,
    required String Function(List<String> names) body,
  }) async {
    if (kIsWeb || _running) return;
    _running = true;

    try {
      final enabled = await isEnabled();

      if (!enabled || items.isEmpty) {
        await _cancelAll(key, firstId, nowId);
        return;
      }

      final now = DateTime.now();
      final todayKey = '${now.year}-${now.month}-${now.day}';
      final signature = jsonEncode(items);

      final lastShown = await _read('alert_${key}_shown');
      final lastSignature = await _read('alert_${key}_sig');
      final scheduledOn = await _read('alert_${key}_scheduled');

      final todayAt = DateTime(now.year, now.month, now.day, reminderHour);
      final pastTodaysHour = !now.isBefore(todayAt);

      // Today's notification, if it hasn't gone out and 08:00 has passed.
      if (pastTodaysHour && lastShown != todayKey) {
        await LocalNotificationService.showNow(
          id: nowId,
          title: title(items.length),
          body: body(items),
          payload: payload,
        );
        await _write('alert_${key}_shown', todayKey);
      }

      // The next days, at 08:00. Rebuilt whenever the list changed or the
      // schedule is from an earlier day, so the text always matches reality.
      if (signature != lastSignature || scheduledOn != todayKey) {
        for (var i = 0; i < _daysAhead; i++) {
          await LocalNotificationService.cancel(firstId + i);
        }

        // Today at 08:00 only if it hasn't happened yet.
        var scheduled = 0;
        for (var d = 0; d <= _daysAhead; d++) {
          final when = DateTime(now.year, now.month, now.day + d, reminderHour);
          if (!when.isAfter(now)) continue;
          if (scheduled >= _daysAhead) break;

          await LocalNotificationService.scheduleAt(
            id: firstId + scheduled,
            title: title(items.length),
            body: body(items),
            when: when,
            payload: payload,
          );
          scheduled++;
        }

        await _write('alert_${key}_sig', signature);
        await _write('alert_${key}_scheduled', todayKey);
      }
    } catch (e, st) {
      debugPrint('StockAlertService($key) failed: $e\n$st');
    } finally {
      _running = false;
    }
  }

  static Future<void> _cancelAll(String key, int firstId, int nowId) async {
    for (var i = 0; i < _daysAhead; i++) {
      await LocalNotificationService.cancel(firstId + i);
    }
    await LocalNotificationService.cancel(nowId);
    for (final suffix in ['shown', 'sig', 'scheduled']) {
      try {
        await _storage.delete(key: 'alert_${key}_$suffix');
      } catch (_) {}
    }
  }

  static String _join(List<String> names) {
    if (names.length <= 3) return names.join(', ');
    return '${names.take(3).join(', ')} and ${names.length - 3} more';
  }

  static Future<String?> _read(String k) async {
    try {
      return await _storage.read(key: k);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _write(String k, String v) async {
    try {
      await _storage.write(key: k, value: v);
    } catch (_) {}
  }
}
