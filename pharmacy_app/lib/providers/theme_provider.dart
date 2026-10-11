import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_colors.dart';

/// Light / dark mode, remembered between launches.
///
/// The app's neutral colours are read from [AppColors] getters, so flipping
/// the mode updates `AppColors.dark mode` first and then rebuilds the whole
/// widget tree (see the `KeyedSubtree` in main.dart).
class ThemeProvider extends ChangeNotifier {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _key = 'pref_dark_mode';

  bool _isDark = false;

  bool get isDark => _isDark;
  ThemeMode get mode => _isDark ? ThemeMode.dark : ThemeMode.light;

  /// Call once before runApp so the very first frame has the right colours.
  Future<void> load() async {
    try {
      _isDark = (await _storage.read(key: _key)) == '1';
    } catch (_) {
      _isDark = false;
    }
    AppColors.darkMode = _isDark;
  }

  Future<void> setDark(bool value) async {
    if (value == _isDark) return;

    _isDark = value;
    AppColors.darkMode = value;
    notifyListeners();

    try {
      await _storage.write(key: _key, value: value ? '1' : '0');
    } catch (_) {/* preference just won't survive a restart */}
  }
}
