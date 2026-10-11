import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/medicine.dart';
import 'local_notification_service.dart';

/// Phone notifications for medicines that have run out.
///
/// * The moment a medicine is seen at 0 units, a notification fires.
/// * While anything is still out of stock, the phone repeats a reminder
///   every 2 hours (scheduled on the phone, so it keeps coming even when the
///   app is closed).
/// * As soon as the app sees the stock is back, the reminders are cancelled.
///
/// "Seeing" the stock happens whenever the app refreshes the medicines list:
/// on opening, on returning to the app, every few minutes while it is open,
/// and after every stock change. (Reminders stop on THIS phone as soon as it
/// next syncs after someone restocks; the server's own alert feed also
/// repeats every 2 hours — see the backend notes.)
class StockAlertService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _kPref = 'pref_stock_alerts';
  static const String _kIds = 'alert_out_ids';
  static const String _kAnchor = 'alert_anchor';
  static const String _kScheduledUntil = 'alert_scheduled_until';

  static const Duration interval = Duration(hours: 2);

  // Notification ids: one block for the repeating reminders, one for the
  // "just ran out" alerts.
  static const int _chainFirstId = 3000;
  static const int _chainLength = 48; // 48 x 2h = 4 days ahead
  static const int _instantBaseId = 2000;
  static const int _summaryId = 2999;

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
    if (!value) await _cancelChain();
  }

  /// Call with the freshly loaded medicines. Never throws.
  static Future<void> sync(List<Medicine> medicines) async {
    if (kIsWeb || _running) return;
    _running = true;

    try {
      final enabled = await isEnabled();
      final out = medicines.where((m) => m.quantity <= 0).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      final nowIds = out.map((m) => m.id).toSet();

      if (!enabled || out.isEmpty) {
        await _cancelChain();
        await _clearState();
        return;
      }

      final previous = await _readIds();
      final added = out.where((m) => !previous.contains(m.id)).toList();

      // 1) Tell the person straight away about anything that just ran out.
      if (added.length <= 3) {
        for (final m in added) {
          await LocalNotificationService.showNow(
            id: _instantBaseId + (m.id % 900),
            title: 'Out of stock: ${m.name}',
            body: '${m.name} has run out. Add stock to clear this alert — '
                "you'll be reminded every 2 hours until it's restocked.",
            payload: payload,
          );
        }
      } else {
        await LocalNotificationService.showNow(
          id: _summaryId,
          title: '${added.length} medicines ran out of stock',
          body: '${_names(added)}. Add stock to clear these alerts.',
          payload: payload,
        );
      }

      // 2) Keep reminding every 2 hours until it is fixed.
      final signature = nowIds.toList()..sort();
      final anchor = (await _readAnchor()) ?? DateTime.now();
      final until = await _readScheduledUntil();
      final stillScheduled = until != null &&
          until.isAfter(DateTime.now().add(const Duration(hours: 12)));

      final unchanged = previous.length == nowIds.length &&
          previous.containsAll(nowIds) &&
          stillScheduled;

      if (!unchanged) {
        await _scheduleChain(out, anchor);
      }

      await _writeState(signature, anchor);
    } catch (e, st) {
      debugPrint('StockAlertService.sync failed: $e\n$st');
    } finally {
      _running = false;
    }
  }

  /// Sign-out: stop every reminder and forget the state.
  static Future<void> clear() async {
    try {
      await _cancelChain();
      await _clearState();
    } catch (_) {}
  }

  // ------------------------------------------------------------ internals

  static String _names(List<Medicine> list) {
    final names = list.map((m) => m.name).toList();
    if (names.length <= 3) return names.join(', ');
    return '${names.take(3).join(', ')} and ${names.length - 3} more';
  }

  static Future<void> _scheduleChainTick(
    int index,
    DateTime when,
    List<Medicine> out,
  ) async {
    final single = out.length == 1;
    await LocalNotificationService.scheduleAt(
      id: _chainFirstId + index,
      title: single
          ? 'Still out of stock: ${out.first.name}'
          : '${out.length} medicines still out of stock',
      body: single
          ? '${out.first.name} has not been restocked yet. Add stock to stop these reminders.'
          : '${_names(out)} — not restocked yet. Add stock to stop these reminders.',
      when: when,
      payload: payload,
    );
  }

  static Future<void> _scheduleChain(List<Medicine> out, DateTime anchor) async {
    await _cancelChain();

    final now = DateTime.now();
    var tick = anchor.add(interval);
    // Skip ticks already in the past (the app was closed for a while).
    while (tick.isBefore(now.add(const Duration(minutes: 1)))) {
      tick = tick.add(interval);
    }

    DateTime? last;
    for (var i = 0; i < _chainLength; i++) {
      final when = tick.add(interval * i);
      await _scheduleChainTick(i, when, out);
      last = when;
    }

    if (last != null) {
      await _storage.write(key: _kScheduledUntil, value: last.toIso8601String());
    }
  }

  static Future<void> _cancelChain() async {
    for (var i = 0; i < _chainLength; i++) {
      await LocalNotificationService.cancel(_chainFirstId + i);
    }
    try {
      await _storage.delete(key: _kScheduledUntil);
    } catch (_) {}
  }

  static Future<Set<int>> _readIds() async {
    try {
      final raw = await _storage.read(key: _kIds);
      if (raw == null || raw.isEmpty) return <int>{};
      return (jsonDecode(raw) as List).map((e) => e as int).toSet();
    } catch (_) {
      return <int>{};
    }
  }

  static Future<DateTime?> _readAnchor() async {
    try {
      return DateTime.tryParse(await _storage.read(key: _kAnchor) ?? '');
    } catch (_) {
      return null;
    }
  }

  static Future<DateTime?> _readScheduledUntil() async {
    try {
      return DateTime.tryParse(await _storage.read(key: _kScheduledUntil) ?? '');
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeState(List<int> ids, DateTime anchor) async {
    try {
      await _storage.write(key: _kIds, value: jsonEncode(ids));
      await _storage.write(key: _kAnchor, value: anchor.toIso8601String());
    } catch (_) {}
  }

  static Future<void> _clearState() async {
    try {
      await _storage.delete(key: _kIds);
      await _storage.delete(key: _kAnchor);
      await _storage.delete(key: _kScheduledUntil);
    } catch (_) {}
  }
}
