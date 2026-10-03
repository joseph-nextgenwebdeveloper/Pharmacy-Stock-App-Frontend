import 'package:intl/intl.dart';

/// Small formatting helpers shared across screens.
class Formatter {
  static final NumberFormat _units = NumberFormat.decimalPattern();

  /// 1284 -> "1,284"
  static String number(num value) => _units.format(value);

  /// Turns an ISO-ish date/time string from the API into "12 Jul, 14:20".
  /// Falls back to the raw string if it can't be parsed.
  static String dateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '—';

    final parsed = DateTime.tryParse(isoString);
    if (parsed == null) return isoString;

    return DateFormat('d MMM, HH:mm').format(parsed.toLocal());
  }

  /// Turns an ISO-ish date string into "12 Jul 2026".
  static String date(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '—';

    final parsed = DateTime.tryParse(isoString);
    if (parsed == null) return isoString;

    return DateFormat('d MMM y').format(parsed.toLocal());
  }

  /// "2h ago", "3d ago", "Just now" — for activity/movement lists.
  static String timeAgo(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';

    final parsed = DateTime.tryParse(isoString);
    if (parsed == null) return '';

    final diff = DateTime.now().difference(parsed.toLocal());

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return date(isoString);
  }
}
