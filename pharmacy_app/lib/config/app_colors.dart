import 'package:flutter/material.dart';

/// JoseKiarie Pharmacy palette — white / black / fresh green, with a dark mode.
///
/// Brand and status colours (green, red, ...) are the same in both modes and
/// stay `const`. The neutral colours (backgrounds, cards, text, borders) are
/// getters that follow [darkMode]; ThemeProvider flips it and rebuilds the app.
class AppColors {
  /// Set by ThemeProvider. Do not set from widgets.
  static bool darkMode = false;

  // ---- Brand / status (same in light and dark) ----
  static const Color primary = Color(0xFF22C55E); // green
  static const Color primaryDeep = Color(0xFF16A34A);
  static const Color secondary = Color(0xFF0B0C0B); // near-black
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFB8860B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF0DCAF0);

  // ---- Neutrals (follow light / dark mode) ----
  static Color get background =>
      darkMode ? const Color(0xFF0B0D0B) : const Color(0xFFF4F5F4);

  static Color get surface =>
      darkMode ? const Color(0xFF161916) : const Color(0xFFFFFFFF);

  /// Near-black cards, pills and the floating nav bar. In dark mode it is a
  /// touch lighter than the background so those shapes stay visible.
  static Color get dark =>
      darkMode ? const Color(0xFF232823) : const Color(0xFF0B0C0B);

  static Color get textPrimary =>
      darkMode ? const Color(0xFFF1F3F1) : const Color(0xFF0E0F0C);

  static Color get textSecondary =>
      darkMode ? const Color(0xFF9BA39B) : const Color(0xFF6B716C);

  static Color get border =>
      darkMode ? const Color(0xFF2A302A) : const Color(0xFFE7E9E6);

  static Color get successSoft =>
      darkMode ? const Color(0xFF123320) : const Color(0xFFE4F9EC);

  static Color get errorSoft =>
      darkMode ? const Color(0xFF3A1A1A) : const Color(0xFFFDEAEA);

  static Color get warningSoft =>
      darkMode ? const Color(0xFF3A3014) : const Color(0xFFFBF0D5);

  /// Stronger red tint (icon tile on a flagged row) and its border.
  static Color get errorTile =>
      darkMode ? const Color(0xFF5A2323) : const Color(0xFFFBD9D9);

  static Color get errorBorder =>
      darkMode ? const Color(0xFF6B2A2A) : const Color(0xFFF6D0D0);

  /// Text on top of [dark] surfaces (always light).
  static const Color onDark = Colors.white;
  static const Color onDarkMuted = Color(0xFFB9BEB9);
}
