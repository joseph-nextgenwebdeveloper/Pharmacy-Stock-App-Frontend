/// Result of decoding whatever a scanner (or the manual box) produced.
class ParsedCode {
  /// Exactly what was scanned / typed.
  final String raw;

  /// Product identifier, digits only, when the code carries one
  /// (EAN-13, UPC-A, GTIN-14, or AI (01) inside a GS1 DataMatrix).
  final String? gtin;

  /// Batch / lot number (GS1 AI 10), if the code carries one.
  final String? batch;

  /// Expiry date (GS1 AI 17), if the code carries one.
  final DateTime? expiry;

  /// Serial number (GS1 AI 21), if present.
  final String? serial;

  /// True when the value was a GS1 element string (DataMatrix / GS1-128).
  final bool isGs1;

  const ParsedCode({
    required this.raw,
    this.gtin,
    this.batch,
    this.expiry,
    this.serial,
    this.isGs1 = false,
  });

  bool get hasBatchInfo => batch != null && batch!.isNotEmpty;
}

class BarcodeParser {
  static const String _gs = '\u001d';

  // GS1 application identifiers with a FIXED data length.
  static const Map<String, int> _fixed = {
    '00': 18,
    '01': 14,
    '02': 14,
    '11': 6,
    '12': 6,
    '13': 6,
    '15': 6,
    '16': 6,
    '17': 6,
    '20': 2,
  };

  static bool _isVariable(String ai) {
    // 2-digit variable-length AIs we may meet on medicine packs.
    const two = {'10', '21', '22', '30', '37', '90'};
    if (two.contains(ai)) return true;
    final n = int.tryParse(ai);
    if (n != null && n >= 91 && n <= 99) return true;
    return false;
  }

  static bool _isVariable3(String ai) {
    final n = int.tryParse(ai);
    if (n == null) return false;
    return (n >= 240 && n <= 243) || (n >= 250 && n <= 255);
  }

  static ParsedCode parse(String input) {
    var s = input.trim();

    // Symbology identifier some scanners prepend, e.g. "]d2" (DataMatrix),
    // "]C1" (GS1-128), "]Q3" (QR).
    s = s.replaceFirst(RegExp(r'^\][A-Za-z][0-9A-Za-z]'), '');

    // Human-readable form: (01)04901234567890(17)280815(10)ABC123
    if (RegExp(r'^\(\d{2,4}\)').hasMatch(s)) {
      final fields = <String, String>{};
      for (final m in RegExp(r'\((\d{2,4})\)([^(]*)').allMatches(s)) {
        fields[m.group(1)!] = m.group(2)!.replaceAll(_gs, '').trim();
      }
      return _fromFields(input, fields);
    }

    // Raw GS1 element string: starts with an AI, e.g. 0104901234567890...
    if (s.startsWith('01') && s.length >= 16) {
      final fields = _parseElementString(s);
      if (fields.containsKey('01')) {
        return _fromFields(input, fields);
      }
    }

    // Plain retail barcode (EAN-8 / UPC-A / EAN-13 / GTIN-14).
    final digits = s.replaceAll(RegExp(r'\s'), '');
    if (RegExp(r'^\d{8}$|^\d{12,14}$').hasMatch(digits)) {
      return ParsedCode(raw: input, gtin: digits);
    }

    // Anything else (internal SKU, free text...).
    return ParsedCode(raw: input);
  }

  static Map<String, String> _parseElementString(String s) {
    final out = <String, String>{};
    var i = 0;

    while (i < s.length) {
      if (s[i] == _gs) {
        i++;
        continue;
      }

      String? ai;
      if (i + 2 <= s.length && _fixed.containsKey(s.substring(i, i + 2))) {
        ai = s.substring(i, i + 2);
        final len = _fixed[ai]!;
        if (i + 2 + len > s.length) break;
        out[ai] = s.substring(i + 2, i + 2 + len);
        i += 2 + len;
        continue;
      }

      if (i + 2 <= s.length && _isVariable(s.substring(i, i + 2))) {
        ai = s.substring(i, i + 2);
        i += 2;
      } else if (i + 3 <= s.length && _isVariable3(s.substring(i, i + 3))) {
        ai = s.substring(i, i + 3);
        i += 3;
      } else {
        break; // unknown AI — stop rather than guess
      }

      final end = s.indexOf(_gs, i);
      final stop = end == -1 ? s.length : end;
      out[ai] = s.substring(i, stop);
      i = stop;
    }

    return out;
  }

  static ParsedCode _fromFields(String raw, Map<String, String> f) {
    return ParsedCode(
      raw: raw,
      gtin: f['01'] ?? f['02'],
      batch: (f['10'] == null || f['10']!.isEmpty) ? null : f['10'],
      expiry: _parseYyMmDd(f['17']),
      serial: f['21'],
      isGs1: true,
    );
  }

  /// GS1 dates are YYMMDD; a day of "00" means "last day of the month".
  static DateTime? _parseYyMmDd(String? v) {
    if (v == null || v.length != 6) return null;
    final yy = int.tryParse(v.substring(0, 2));
    final mm = int.tryParse(v.substring(2, 4));
    final dd = int.tryParse(v.substring(4, 6));
    if (yy == null || mm == null || dd == null) return null;
    if (mm < 1 || mm > 12) return null;

    final year = 2000 + yy;
    final day = dd == 0 ? DateTime(year, mm + 1, 0).day : dd;
    return DateTime(year, mm, day);
  }

  /// Pads any GTIN length (8/12/13/14) to 14 digits so an EAN-13 stored on a
  /// medicine matches the same product scanned as a GTIN-14 and vice versa.
  static String? normalizeGtin(String? value) {
    if (value == null) return null;
    final digits = value.trim();
    if (!RegExp(r'^\d{8,14}$').hasMatch(digits)) return null;
    return digits.padLeft(14, '0');
  }

  /// True when both strings identify the same retail product.
  static bool sameProduct(String? a, String? b) {
    if (a == null || b == null) return false;
    final na = normalizeGtin(a);
    final nb = normalizeGtin(b);
    if (na != null && nb != null) return na == nb;
    return a.trim().toLowerCase() == b.trim().toLowerCase();
  }
}
