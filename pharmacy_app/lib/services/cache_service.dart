import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// What was last downloaded, kept on the phone so screens are never empty
/// when the connection drops. Stored in the same encrypted storage that
/// holds the sign-in tokens (pharmacy data stays private to the device).
///
/// Every call is wrapped in try/catch: if storage ever misbehaves the app
/// simply behaves as if there were no cache.
class CacheService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _prefix = 'cache_';
  static const String _ownerKey = 'cache_owner';

  /// Newest "saved at" time seen this session — drives the offline banner's
  /// "showing data from ..." text.
  static DateTime? newestSavedAt;

  static void _touch(DateTime t) {
    if (newestSavedAt == null || t.isAfter(newestSavedAt!)) newestSavedAt = t;
  }

  static Future<void> write(String key, Object data) async {
    try {
      final now = DateTime.now();
      await _storage.write(
        key: '$_prefix$key',
        value: jsonEncode({'t': now.toIso8601String(), 'd': data}),
      );
      _touch(now);
    } catch (_) {/* cache is best-effort */}
  }

  static Future<CachedData?> read(String key) async {
    try {
      final raw = await _storage.read(key: '$_prefix$key');
      if (raw == null || raw.isEmpty) return null;

      final map = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.tryParse(map['t']?.toString() ?? '');
      if (savedAt != null) _touch(savedAt);

      return CachedData(savedAt ?? DateTime.now(), map['d']);
    } catch (_) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> readList(String key) async {
    final cached = await read(key);
    final data = cached?.data;
    if (data is! List) return const [];

    return data
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  static Future<Map<String, dynamic>?> readMap(String key) async {
    final data = (await read(key))?.data;
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  /// Wipes everything cached (called on sign-out).
  static Future<void> clearAll() async {
    try {
      final all = await _storage.readAll();
      for (final key in all.keys) {
        if (key.startsWith(_prefix)) await _storage.delete(key: key);
      }
    } catch (_) {}
    newestSavedAt = null;
  }

  /// Cache belongs to one account. If a different person signs in on this
  /// phone, the previous person's cached data is dropped first.
  static Future<void> ensureOwner(int userId) async {
    try {
      final current = await _storage.read(key: _ownerKey);
      if (current != '$userId') {
        await clearAll();
        await _storage.write(key: _ownerKey, value: '$userId');
      }
    } catch (_) {}
  }
}

class CachedData {
  final DateTime savedAt;
  final dynamic data;

  const CachedData(this.savedAt, this.data);
}
