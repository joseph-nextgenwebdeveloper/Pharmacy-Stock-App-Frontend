import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/activity_report.dart';
import '../models/batch.dart';
import '../models/expired_medicine_report.dart';
import '../models/fast_moving_medicine.dart';
import '../models/inventory_report.dart';
import '../models/monthly_movement_report.dart';
import '../models/slow_moving_medicine.dart';
import '../models/stock_movement.dart';
import '../models/stock_valuation_report.dart';

/// Builds clean black-and-white A4 PDFs and hands them to the system print
/// dialog (which also offers "Save as PDF" / share). Text is kept to plain
/// ASCII because the built-in PDF fonts have no glyphs for symbols like "−".
class ReportPrinter {
  static const String pharmacyName = 'JoseKiarie Pharmacy';

  static final NumberFormat _money = NumberFormat('#,##0.00');
  static final NumberFormat _int = NumberFormat.decimalPattern();

  // ----------------------------------------------------------------------
  // Core
  // ----------------------------------------------------------------------

  static Future<void> printTable({
    required String title,
    String? subtitle,
    required List<String> headers,
    required List<List<String>> rows,
    List<MapEntry<String, String>> summary = const [],
    List<int> rightAlignedColumns = const [],
    bool landscape = false,
    String? preparedBy,
  }) async {
    final doc = pw.Document(title: title, author: pharmacyName);
    final generated = DateFormat('d MMM y, HH:mm').format(DateTime.now());

    final format =
        landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;

    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  pharmacyName,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Generated $generated',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Divider(thickness: 0.8, color: PdfColors.black),
            pw.SizedBox(height: 6),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              preparedBy == null ? '' : 'Prepared by: $preparedBy',
              style: const pw.TextStyle(fontSize: 8),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
        build: (context) => [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Text(subtitle, style: const pw.TextStyle(fontSize: 10)),
          ],
          pw.SizedBox(height: 12),
          if (summary.isNotEmpty) ...[
            pw.Wrap(
              spacing: 24,
              runSpacing: 6,
              children: summary
                  .map(
                    (e) => pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(e.key, style: const pw.TextStyle(fontSize: 8)),
                        pw.Text(
                          e.value,
                          style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
            pw.SizedBox(height: 14),
          ],
          if (rows.isEmpty)
            pw.Text(
              'No records to show.',
              style: const pw.TextStyle(fontSize: 10),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: rows,
              border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellPadding:
                  const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              oddRowDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey100),
              cellAlignments: {
                for (var i = 0; i < headers.length; i++)
                  i: rightAlignedColumns.contains(i)
                      ? pw.Alignment.centerRight
                      : pw.Alignment.centerLeft,
              },
              headerAlignments: {
                for (var i = 0; i < headers.length; i++)
                  i: rightAlignedColumns.contains(i)
                      ? pw.Alignment.centerRight
                      : pw.Alignment.centerLeft,
              },
            ),
        ],
      ),
    );

    final bytes = await doc.save();
    final safeName =
        title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

    await Printing.layoutPdf(
      name: '${safeName}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      onLayout: (_) async => bytes,
    );
  }

  static String _date(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateFormat('d MMM y').format(d);
  }

  static String _status(String s) => s.replaceAll('_', ' ');

  // ----------------------------------------------------------------------
  // Reports
  // ----------------------------------------------------------------------

  static Future<void> inventory(
    List<InventoryReport> data, {
    String? preparedBy,
  }) {
    final low = data.where((e) => e.status == 'LOW_STOCK').length;
    final out = data.where((e) => e.status == 'OUT_OF_STOCK').length;

    return printTable(
      title: 'Inventory Report',
      subtitle: 'Current stock level of every medicine',
      preparedBy: preparedBy,
      summary: [
        MapEntry('Medicines', '${data.length}'),
        MapEntry('Low stock', '$low'),
        MapEntry('Out of stock', '$out'),
        MapEntry('Total units',
            _int.format(data.fold<int>(0, (s, e) => s + e.quantity))),
      ],
      headers: const ['Medicine', 'SKU', 'Quantity', 'Reorder level', 'Status'],
      rightAlignedColumns: const [2, 3],
      rows: data
          .map((e) => [
                e.medicine,
                e.sku,
                _int.format(e.quantity),
                _int.format(e.reorderLevel),
                _status(e.status),
              ])
          .toList(),
    );
  }

  static Future<void> valuation(
    List<StockValuationReport> data, {
    String? preparedBy,
  }) {
    final total = data.fold<double>(0, (s, e) => s + e.stockValue);

    return printTable(
      title: 'Stock Valuation',
      subtitle: 'Stock on hand valued at buying price',
      preparedBy: preparedBy,
      summary: [
        MapEntry('Medicines', '${data.length}'),
        MapEntry('Total stock value', _money.format(total)),
      ],
      headers: const ['Medicine', 'SKU', 'Quantity', 'Stock value'],
      rightAlignedColumns: const [2, 3],
      rows: [
        ...data.map((e) => [
              e.medicine,
              e.sku,
              _int.format(e.quantity),
              _money.format(e.stockValue),
            ]),
        if (data.isNotEmpty)
          ['TOTAL', '', '', _money.format(total)],
      ],
    );
  }

  static Future<void> expired(
    List<ExpiredMedicineReport> data, {
    String? preparedBy,
  }) {
    return printTable(
      title: 'Expired Medicines',
      subtitle: 'Batches past their expiry date that still hold stock',
      preparedBy: preparedBy,
      summary: [
        MapEntry('Expired batches', '${data.length}'),
        MapEntry('Units to remove',
            _int.format(data.fold<int>(0, (s, e) => s + e.quantity))),
      ],
      headers: const ['Medicine', 'SKU', 'Batch', 'Expired on', 'Quantity'],
      rightAlignedColumns: const [4],
      rows: data
          .map((e) => [
                e.medicine,
                e.sku,
                e.batchNumber,
                _date(e.expiryDate),
                _int.format(e.quantity),
              ])
          .toList(),
    );
  }

  static Future<void> monthly(
    MonthlyMovementReport? r, {
    String? preparedBy,
  }) {
    final label = r == null
        ? ''
        : DateFormat('MMMM y').format(DateTime(r.year, r.month));

    return printTable(
      title: 'Monthly Movement',
      subtitle: label,
      preparedBy: preparedBy,
      headers: const ['Measure', 'Units'],
      rightAlignedColumns: const [1],
      rows: r == null
          ? const []
          : [
              ['Stock received', _int.format(r.stockReceived)],
              ['Stock dispensed', _int.format(r.stockDispensed)],
              [
                'Net change',
                _int.format(r.stockReceived - r.stockDispensed),
              ],
            ],
    );
  }

  static Future<void> fastMoving(
    List<FastMovingMedicine> data, {
    String? preparedBy,
  }) {
    return printTable(
      title: 'Fast-Moving Medicines',
      preparedBy: preparedBy,
      headers: const ['#', 'Medicine', 'SKU', 'Dispensed'],
      rightAlignedColumns: const [0, 3],
      rows: [
        for (var i = 0; i < data.length; i++)
          [
            '${i + 1}',
            data[i].medicine,
            data[i].sku,
            _int.format(data[i].quantityDispensed),
          ],
      ],
    );
  }

  static Future<void> slowMoving(
    List<SlowMovingMedicine> data, {
    String? preparedBy,
  }) {
    return printTable(
      title: 'Slow-Moving Medicines',
      preparedBy: preparedBy,
      headers: const ['#', 'Medicine', 'SKU', 'Dispensed'],
      rightAlignedColumns: const [0, 3],
      rows: [
        for (var i = 0; i < data.length; i++)
          [
            '${i + 1}',
            data[i].medicine,
            data[i].sku,
            _int.format(data[i].quantityDispensed),
          ],
      ],
    );
  }

  /// Every batch with its supplier, prices, quantities and status.
  static Future<void> batchRegister(
    List<Batch> batches, {
    required String Function(Batch) medicineName,
    String? preparedBy,
  }) {
    final sorted = [...batches]
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

    final active = sorted.where((b) => b.isActive).length;
    final expired = sorted.where((b) => b.isExpired).length;
    final depleted = sorted.where((b) => b.isDepleted).length;
    final value = sorted.fold<double>(0, (s, b) => s + b.quantity * b.buyingPrice);

    return printTable(
      title: 'Batch Register',
      subtitle: 'All batches, earliest expiry first',
      preparedBy: preparedBy,
      landscape: true,
      summary: [
        MapEntry('Batches', '${sorted.length}'),
        MapEntry('Active', '$active'),
        MapEntry('Expired', '$expired'),
        MapEntry('Depleted', '$depleted'),
        MapEntry('Value at cost', _money.format(value)),
      ],
      headers: const [
        'Medicine',
        'Batch',
        'Supplier',
        'Expiry',
        'Available',
        'Received',
        'Buying',
        'Selling',
        'Status',
      ],
      rightAlignedColumns: const [4, 5, 6, 7],
      rows: sorted
          .map((b) => [
                medicineName(b),
                b.batchNumber,
                b.supplierName.isEmpty ? '-' : b.supplierName,
                _date(b.expiryDate),
                _int.format(b.quantity),
                _int.format(b.originalQuantity),
                _money.format(b.buyingPrice),
                _money.format(b.sellingPrice),
                b.statusLabel,
              ])
          .toList(),
    );
  }

  /// Everything that happened on one day, oldest first.
  static Future<void> dailyActivity(
    DateTime day,
    List<StockMovement> moves, {
    required String Function(StockMovement) medicineName,
    String? preparedBy,
  }) {
    final sorted = [...moves]..sort((a, b) {
        final wa = a.when, wb = b.when;
        if (wa == null || wb == null) return 0;
        return wa.compareTo(wb);
      });

    final inQty = sorted.where((m) => m.isIn).fold<int>(0, (s, m) => s + m.quantity);
    final outQty = sorted.where((m) => !m.isIn).fold<int>(0, (s, m) => s + m.quantity);
    final time = DateFormat('HH:mm');

    return printTable(
      title: 'Daily Stock Activity',
      subtitle: DateFormat('EEEE, d MMMM y').format(day),
      preparedBy: preparedBy,
      landscape: true,
      summary: [
        MapEntry('Movements', '${sorted.length}'),
        MapEntry('Received', _int.format(inQty)),
        MapEntry('Dispensed', _int.format(outQty)),
        MapEntry('Net change', _int.format(inQty - outQty)),
      ],
      headers: const [
        'Time',
        'Medicine',
        'Batch',
        'Type',
        'Quantity',
        'By',
        'Note',
      ],
      rightAlignedColumns: const [4],
      rows: sorted
          .map((m) => [
                m.when == null ? '-' : time.format(m.when!),
                medicineName(m),
                m.batchNumber.isEmpty ? '-' : m.batchNumber,
                m.isIn ? 'IN' : 'OUT',
                _int.format(m.quantity),
                m.performedByName.isEmpty ? '-' : m.performedByName,
                m.note.isEmpty ? '' : m.note,
              ])
          .toList(),
    );
  }

  // ----------------------------------------------------------------------
  // Movement & activity report (day / week / month / any range)
  // ----------------------------------------------------------------------

  /// The built-in PDF fonts only have Latin-1 glyphs, so swap the common
  /// "smart" characters for plain ones instead of printing boxes.
  static String _a(String v) => v
      .replaceAll('\u00b7', '-')
      .replaceAll('\u2013', '-')
      .replaceAll('\u2014', '-')
      .replaceAll('\u2212', '-')
      .replaceAll('\u00d7', 'x')
      .replaceAll('\u2018', "'")
      .replaceAll('\u2019', "'")
      .replaceAll('\u201c', '"')
      .replaceAll('\u201d', '"')
      .replaceAll('\u2026', '...');

  static String _signed(int v) => v > 0 ? '+${_int.format(v)}' : _int.format(v);

  static String _role(String role) => role.isEmpty
      ? ''
      : role
          .split('_')
          .map((w) => w.isEmpty ? w : '${w[0]}${w.substring(1).toLowerCase()}')
          .join(' ');

  static pw.Widget _heading(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
        child: pw.Text(
          text,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
      );

  static pw.Widget _grid(
    List<String> headers,
    List<List<String>> rows, {
    List<int> right = const [],
    Map<int, pw.TableColumnWidth>? widths,
  }) {
    final align = {
      for (var i = 0; i < headers.length; i++)
        i: right.contains(i) ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
    };

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows.map((r) => r.map(_a).toList()).toList(),
      columnWidths: widths,
      border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
      headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellStyle: const pw.TextStyle(fontSize: 8.5),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      cellAlignments: align,
      headerAlignments: align,
    );
  }

  static Future<Uint8List> _activityBytes(
    ActivityReport r, {
    String? preparedBy,
  }) async {
    final doc = pw.Document(
      title: 'Stock movement and activity report',
      author: pharmacyName,
    );
    final generated = DateFormat('d MMM y, HH:mm').format(DateTime.now());
    final stamp = DateFormat('d MMM HH:mm');
    final time = DateFormat('HH:mm');
    final multiDay = r.start != r.end;

    String stampOf(DateTime? d) =>
        d == null ? '-' : (multiDay ? stamp.format(d) : time.format(d));

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(30),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  pharmacyName,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Generated $generated',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Divider(thickness: 0.8, color: PdfColors.black),
            pw.SizedBox(height: 4),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              preparedBy == null ? '' : 'Prepared by: ${_a(preparedBy)}',
              style: const pw.TextStyle(fontSize: 8),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
        build: (context) => [
          pw.Text(
            'Stock Movement & Activity Report',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 3),
          pw.Text(_a(r.label), style: const pw.TextStyle(fontSize: 11)),
          if (!r.fromServer)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Text(
                'Built from the data saved on this phone (the server could '
                'not be reached), so it may miss very recent changes.',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ),
          pw.SizedBox(height: 12),
          pw.Wrap(
            spacing: 26,
            runSpacing: 6,
            children: [
              ('Movements', _int.format(r.movementCount)),
              ('Units received', _int.format(r.unitsIn)),
              ('Units dispensed / removed', _int.format(r.unitsOut)),
              ('Net change', _signed(r.net)),
              ('Medicines touched', _int.format(r.medicinesTouched)),
              ('Staff active', _int.format(r.staffActive)),
            ]
                .map(
                  (e) => pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(e.$1, style: const pw.TextStyle(fontSize: 8)),
                      pw.Text(
                        e.$2,
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),

          if (multiDay && r.daily.isNotEmpty) ...[
            _heading('Day by day'),
            _grid(
              const ['Date', 'Movements', 'Received', 'Dispensed', 'Net'],
              r.daily
                  .map((d) => [
                        DateFormat('EEE d MMM y').format(d.date),
                        _int.format(d.moves),
                        _int.format(d.unitsIn),
                        _int.format(d.unitsOut),
                        _signed(d.net),
                      ])
                  .toList(),
              right: const [1, 2, 3, 4],
            ),
          ],

          if (r.byMedicine.isNotEmpty) ...[
            _heading('By medicine'),
            _grid(
              const ['Medicine', 'SKU', 'Movements', 'Received', 'Dispensed', 'Net'],
              r.byMedicine
                  .map((m) => [
                        m.medicine,
                        m.sku,
                        _int.format(m.moves),
                        _int.format(m.unitsIn),
                        _int.format(m.unitsOut),
                        _signed(m.net),
                      ])
                  .toList(),
              right: const [2, 3, 4, 5],
            ),
          ],

          if (r.byReason.isNotEmpty) ...[
            _heading('By reason'),
            _grid(
              const ['Direction', 'Reason', 'Movements', 'Units'],
              r.byReason
                  .map((e) => [
                        e.isIn ? 'IN' : 'OUT',
                        e.label,
                        _int.format(e.moves),
                        _int.format(e.units),
                      ])
                  .toList(),
              right: const [2, 3],
            ),
          ],

          if (r.byStaff.isNotEmpty) ...[
            _heading('By staff member'),
            _grid(
              const ['Staff', 'Role', 'Movements', 'Received', 'Dispensed'],
              r.byStaff
                  .map((s) => [
                        s.name,
                        _role(s.role),
                        _int.format(s.moves),
                        _int.format(s.unitsIn),
                        _int.format(s.unitsOut),
                      ])
                  .toList(),
              right: const [2, 3, 4],
            ),
          ],

          _heading('Stock movements'),
          if (r.movements.isEmpty)
            pw.Text(
              'No stock movements in this period.',
              style: const pw.TextStyle(fontSize: 9),
            )
          else
            _grid(
              [
                multiDay ? 'Date / time' : 'Time',
                'Medicine',
                'Batch',
                'Type',
                'Reason',
                'Qty',
                'Balance',
                'Reference / note',
                'By',
              ],
              r.movements.map((m) {
                final extra = [
                  if (m.reference.isNotEmpty) m.reference,
                  if (m.note.isNotEmpty) m.note,
                ].join(' - ');
                final balance = (m.before != null && m.after != null)
                    ? '${m.before} -> ${m.after}'
                    : '-';

                return [
                  stampOf(m.at),
                  m.medicine,
                  m.batch.isEmpty ? '-' : m.batch,
                  m.isIn ? 'IN' : 'OUT',
                  m.reasonLabel,
                  '${m.isIn ? '+' : '-'}${_int.format(m.quantity)}',
                  balance,
                  extra,
                  m.by.isEmpty ? '-' : m.by,
                ];
              }).toList(),
              right: const [5],
            ),
          if (r.truncated)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text(
                'Only the first 5,000 movements are listed; the totals above '
                'include all of them.',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ),

          if (r.activities.isNotEmpty) ...[
            _heading(
              r.scope == 'team'
                  ? 'Other activity (whole team)'
                  : 'Other activity (yours)',
            ),
            _grid(
              [multiDay ? 'Date / time' : 'Time', 'By', 'Action', 'Details'],
              r.activities
                  .map((a) => [stampOf(a.at), a.by, a.actionLabel, a.summary])
                  .toList(),
            ),
          ],
        ],
      ),
    );

    return doc.save();
  }

  static String activityFileName(ActivityReport r) {
    final tag = r.period == ActivityReport.day
        ? 'daily'
        : r.period == ActivityReport.week
            ? 'weekly'
            : r.period == ActivityReport.month
                ? 'monthly'
                : 'range';
    final a = DateFormat('yyyyMMdd').format(r.start);
    final b = DateFormat('yyyyMMdd').format(r.end);

    return 'stock_activity_${tag}_${a == b ? a : '${a}_$b'}.pdf';
  }

  /// Opens the system share sheet so the PDF can be saved to the phone
  /// (Files / Drive / Downloads), sent on WhatsApp or e-mailed.
  static Future<void> shareActivityReport(
    ActivityReport r, {
    String? preparedBy,
  }) async {
    final bytes = await _activityBytes(r, preparedBy: preparedBy);

    await Printing.sharePdf(bytes: bytes, filename: activityFileName(r));
  }

  /// Opens the print dialog (which also offers "Save as PDF").
  static Future<void> printActivityReport(
    ActivityReport r, {
    String? preparedBy,
  }) async {
    final bytes = await _activityBytes(r, preparedBy: preparedBy);

    await Printing.layoutPdf(
      name: activityFileName(r),
      onLayout: (_) async => bytes,
    );
  }
}
