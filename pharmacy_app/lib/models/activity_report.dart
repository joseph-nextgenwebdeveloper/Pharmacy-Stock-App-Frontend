import 'package:intl/intl.dart';

import 'stock_movement.dart';

/// One line of the stock ledger inside a report.
class ReportMovement {
  final DateTime? at;
  final String medicine;
  final String sku;
  final String batch;
  final bool isIn;
  final String reasonLabel;
  final int quantity;
  final int? before;
  final int? after;
  final String reference;
  final String note;
  final String by;

  const ReportMovement({
    this.at,
    required this.medicine,
    this.sku = '',
    this.batch = '',
    required this.isIn,
    this.reasonLabel = '',
    required this.quantity,
    this.before,
    this.after,
    this.reference = '',
    this.note = '',
    this.by = '',
  });

  factory ReportMovement.fromJson(Map<String, dynamic> j) => ReportMovement(
        at: DateTime.tryParse('${j['at'] ?? ''}')?.toLocal(),
        medicine: '${j['medicine'] ?? ''}',
        sku: '${j['sku'] ?? ''}',
        batch: '${j['batch'] ?? ''}',
        isIn: '${j['movement_type'] ?? ''}'.toUpperCase() == 'IN',
        reasonLabel: '${j['reason_label'] ?? ''}',
        quantity: (j['quantity'] as num?)?.toInt() ?? 0,
        before: (j['before'] as num?)?.toInt(),
        after: (j['after'] as num?)?.toInt(),
        reference: '${j['reference'] ?? ''}',
        note: '${j['note'] ?? ''}',
        by: '${j['by'] ?? ''}',
      );
}

class ReportDay {
  final DateTime date;
  final int unitsIn;
  final int unitsOut;
  final int moves;

  const ReportDay({
    required this.date,
    required this.unitsIn,
    required this.unitsOut,
    required this.moves,
  });

  int get net => unitsIn - unitsOut;
}

class ReportMedicine {
  final String medicine;
  final String sku;
  final int unitsIn;
  final int unitsOut;
  final int moves;

  const ReportMedicine({
    required this.medicine,
    this.sku = '',
    required this.unitsIn,
    required this.unitsOut,
    required this.moves,
  });

  int get net => unitsIn - unitsOut;
  int get total => unitsIn + unitsOut;
}

class ReportReason {
  final bool isIn;
  final String label;
  final int units;
  final int moves;

  const ReportReason({
    required this.isIn,
    required this.label,
    required this.units,
    required this.moves,
  });
}

class ReportStaff {
  final String name;
  final String role;
  final int moves;
  final int unitsIn;
  final int unitsOut;

  const ReportStaff({
    required this.name,
    this.role = '',
    required this.moves,
    required this.unitsIn,
    required this.unitsOut,
  });
}

/// Non-stock activity: medicine / batch / supplier added or edited...
class ReportActivity {
  final DateTime? at;
  final String by;
  final String actionLabel;
  final String summary;

  const ReportActivity({
    this.at,
    this.by = '',
    this.actionLabel = '',
    this.summary = '',
  });
}

/// Everything that happened in a period (a day, a week, a month or any
/// custom range). Comes from /api/reports/activity/, or is built from the
/// movements saved on the phone when the server can't be reached.
class ActivityReport {
  static const day = 'day';
  static const week = 'week';
  static const month = 'month';
  static const custom = 'custom';

  final String period;
  final DateTime start;
  final DateTime end;
  final String label;

  /// false when it was built on the phone from saved data.
  final bool fromServer;

  /// "team" (everyone) or "mine" (only the signed-in person's other activity)
  final String scope;

  final int movementCount;
  final int unitsIn;
  final int unitsOut;
  final int medicinesTouched;
  final int staffActive;
  final bool truncated;

  final List<ReportDay> daily;
  final List<ReportMedicine> byMedicine;
  final List<ReportReason> byReason;
  final List<ReportStaff> byStaff;
  final List<ReportMovement> movements;
  final List<ReportActivity> activities;

  const ActivityReport({
    required this.period,
    required this.start,
    required this.end,
    required this.label,
    this.fromServer = true,
    this.scope = 'mine',
    required this.movementCount,
    required this.unitsIn,
    required this.unitsOut,
    required this.medicinesTouched,
    required this.staffActive,
    this.truncated = false,
    this.daily = const [],
    this.byMedicine = const [],
    this.byReason = const [],
    this.byStaff = const [],
    this.movements = const [],
    this.activities = const [],
  });

  int get net => unitsIn - unitsOut;
  bool get isEmpty => movementCount == 0 && activities.isEmpty;

  // ------------------------------------------------------------------
  // Period maths (Monday-first weeks, same as the backend)
  // ------------------------------------------------------------------

  static DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Inclusive first / last day of [period] around [anchor].
  static (DateTime, DateTime) rangeFor(
    String period,
    DateTime anchor, {
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final a = dayOnly(anchor);

    switch (period) {
      case week:
        final first = a.subtract(Duration(days: a.weekday - 1));
        return (first, first.add(const Duration(days: 6)));
      case month:
        return (
          DateTime(a.year, a.month, 1),
          DateTime(a.year, a.month + 1, 0),
        );
      case custom:
        var s = dayOnly(customStart ?? a);
        var e = dayOnly(customEnd ?? s);
        if (e.isBefore(s)) {
          final t = s;
          s = e;
          e = t;
        }
        return (s, e);
      default:
        return (a, a);
    }
  }

  static String labelFor(String period, DateTime start, DateTime end) {
    if (period == day || start == end) {
      return DateFormat('EEEE, d MMMM y').format(start);
    }
    if (period == month) return DateFormat('MMMM y').format(start);
    if (start.year == end.year) {
      return '${DateFormat('d MMM').format(start)} - '
          '${DateFormat('d MMM y').format(end)}';
    }
    return '${DateFormat('d MMM y').format(start)} - '
        '${DateFormat('d MMM y').format(end)}';
  }

  static String ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  // ------------------------------------------------------------------
  // From the server
  // ------------------------------------------------------------------

  factory ActivityReport.fromJson(Map<String, dynamic> j) {
    final summary = (j['summary'] is Map)
        ? Map<String, dynamic>.from(j['summary'] as Map)
        : <String, dynamic>{};

    List<Map<String, dynamic>> maps(dynamic v) => v is List
        ? v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
        : <Map<String, dynamic>>[];

    int n(dynamic v) => (v as num?)?.toInt() ?? 0;

    final start = DateTime.tryParse('${j['start'] ?? ''}') ?? DateTime.now();
    final end = DateTime.tryParse('${j['end'] ?? ''}') ?? start;

    return ActivityReport(
      period: '${j['period'] ?? day}',
      start: dayOnly(start),
      end: dayOnly(end),
      label: '${j['label'] ?? ''}',
      scope: '${j['scope'] ?? 'mine'}',
      movementCount: n(summary['movements']),
      unitsIn: n(summary['units_in']),
      unitsOut: n(summary['units_out']),
      medicinesTouched: n(summary['medicines_touched']),
      staffActive: n(summary['staff_active']),
      truncated: summary['truncated'] == true,
      daily: maps(j['daily'])
          .map((d) => ReportDay(
                date: dayOnly(DateTime.tryParse('${d['date']}') ?? start),
                unitsIn: n(d['units_in']),
                unitsOut: n(d['units_out']),
                moves: n(d['moves']),
              ))
          .toList(),
      byMedicine: maps(j['by_medicine'])
          .map((d) => ReportMedicine(
                medicine: '${d['medicine'] ?? ''}',
                sku: '${d['sku'] ?? ''}',
                unitsIn: n(d['units_in']),
                unitsOut: n(d['units_out']),
                moves: n(d['moves']),
              ))
          .toList(),
      byReason: maps(j['by_reason'])
          .map((d) => ReportReason(
                isIn: '${d['movement_type']}'.toUpperCase() == 'IN',
                label: '${d['label'] ?? ''}',
                units: n(d['units']),
                moves: n(d['moves']),
              ))
          .toList(),
      byStaff: maps(j['by_staff'])
          .map((d) => ReportStaff(
                name: '${d['name'] ?? ''}',
                role: '${d['role'] ?? ''}',
                moves: n(d['moves']),
                unitsIn: n(d['units_in']),
                unitsOut: n(d['units_out']),
              ))
          .toList(),
      movements: maps(j['movements']).map(ReportMovement.fromJson).toList(),
      activities: maps(j['activities'])
          .map((d) => ReportActivity(
                at: DateTime.tryParse('${d['at'] ?? ''}')?.toLocal(),
                by: '${d['by'] ?? ''}',
                actionLabel: '${d['action_label'] ?? ''}',
                summary: '${d['summary'] ?? ''}',
              ))
          .toList(),
    );
  }

  // ------------------------------------------------------------------
  // From the movements saved on the phone (offline fallback)
  // ------------------------------------------------------------------

  factory ActivityReport.local({
    required String period,
    required DateTime start,
    required DateTime end,
    required List<StockMovement> all,
    required String Function(StockMovement) nameOf,
    String Function(StockMovement)? skuOf,
  }) {
    final first = dayOnly(start);
    final last = dayOnly(end);

    final inRange = all.where((m) {
      final d = m.day;
      return d != null && !d.isBefore(first) && !d.isAfter(last);
    }).toList()
      ..sort((a, b) {
        final wa = a.when, wb = b.when;
        if (wa == null || wb == null) return a.id.compareTo(b.id);
        return wa.compareTo(wb);
      });

    var totalIn = 0, totalOut = 0;
    final perDay = <DateTime, List<int>>{}; // [in, out, moves]
    final perMed = <int, List<dynamic>>{}; // [name, sku, in, out, moves]
    final perReason = <String, List<dynamic>>{}; // [isIn, label, units, moves]
    final perStaff = <String, List<dynamic>>{}; // [role, moves, in, out]

    for (final m in inRange) {
      final q = m.quantity;
      if (m.isIn) {
        totalIn += q;
      } else {
        totalOut += q;
      }

      final d = perDay.putIfAbsent(m.day!, () => [0, 0, 0]);
      d[2] += 1;
      if (m.isIn) {
        d[0] += q;
      } else {
        d[1] += q;
      }

      final med = perMed.putIfAbsent(
        m.medicineId,
        () => [nameOf(m), skuOf?.call(m) ?? '', 0, 0, 0],
      );
      med[4] = (med[4] as int) + 1;
      if (m.isIn) {
        med[2] = (med[2] as int) + q;
      } else {
        med[3] = (med[3] as int) + q;
      }

      final rKey = '${m.isIn ? 'IN' : 'OUT'}|${m.label}';
      final r = perReason.putIfAbsent(rKey, () => [m.isIn, m.label, 0, 0]);
      r[2] = (r[2] as int) + q;
      r[3] = (r[3] as int) + 1;

      final s = perStaff.putIfAbsent(m.who, () => [m.performedByRole, 0, 0, 0]);
      s[1] = (s[1] as int) + 1;
      if (m.isIn) {
        s[2] = (s[2] as int) + q;
      } else {
        s[3] = (s[3] as int) + q;
      }
    }

    final daily = <ReportDay>[];
    for (var d = first; !d.isAfter(last); d = DateTime(d.year, d.month, d.day + 1)) {
      final row = perDay[d] ?? const [0, 0, 0];
      daily.add(ReportDay(
        date: d,
        unitsIn: row[0],
        unitsOut: row[1],
        moves: row[2],
      ));
    }

    final meds = perMed.values
        .map((v) => ReportMedicine(
              medicine: v[0] as String,
              sku: v[1] as String,
              unitsIn: v[2] as int,
              unitsOut: v[3] as int,
              moves: v[4] as int,
            ))
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    return ActivityReport(
      period: period,
      start: first,
      end: last,
      label: labelFor(period, first, last),
      fromServer: false,
      scope: 'mine',
      movementCount: inRange.length,
      unitsIn: totalIn,
      unitsOut: totalOut,
      medicinesTouched: meds.length,
      staffActive: perStaff.length,
      daily: daily,
      byMedicine: meds,
      byReason: perReason.values
          .map((v) => ReportReason(
                isIn: v[0] as bool,
                label: v[1] as String,
                units: v[2] as int,
                moves: v[3] as int,
              ))
          .toList(),
      byStaff: perStaff.entries
          .map((e) => ReportStaff(
                name: e.key,
                role: e.value[0] as String,
                moves: e.value[1] as int,
                unitsIn: e.value[2] as int,
                unitsOut: e.value[3] as int,
              ))
          .toList()
        ..sort((a, b) => b.moves.compareTo(a.moves)),
      movements: inRange
          .map((m) => ReportMovement(
                at: m.when,
                medicine: nameOf(m),
                sku: skuOf?.call(m) ?? '',
                batch: m.batchNumber,
                isIn: m.isIn,
                reasonLabel: m.label,
                quantity: m.quantity,
                before: m.quantityBefore,
                after: m.quantityAfter,
                reference: m.reference,
                note: m.note,
                by: m.performedByName,
              ))
          .toList(),
    );
  }
}
