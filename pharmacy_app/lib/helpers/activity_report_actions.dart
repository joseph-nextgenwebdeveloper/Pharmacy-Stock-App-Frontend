import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/activity_report.dart';
import '../models/stock_movement.dart';
import '../providers/inventory_provider.dart';
import '../providers/stock_movement_provider.dart';
import '../services/report_printer.dart';
import '../services/report_service.dart';
import 'print_helpers.dart';

enum ReportOutput { download, print }

/// Loads the movement & activity report for a period from the server (or,
/// when offline, builds it from the movements saved on the phone).
Future<ActivityReport> loadActivityReport(
  BuildContext context, {
  required String period,
  DateTime? date,
  DateTime? start,
  DateTime? end,
}) async {
  final movements = context.read<StockMovementProvider>().movements;
  final medicines = context.read<InventoryProvider>().medicines;

  try {
    return await ReportService.getActivityReport(
      period: period,
      date: date,
      start: start,
      end: end,
    );
  } catch (_) {
    final (first, last) = ActivityReport.rangeFor(
      period,
      date ?? DateTime.now(),
      customStart: start,
      customEnd: end,
    );

    String nameOf(StockMovement m) {
      if (m.medicineName.isNotEmpty) return m.medicineName;
      for (final med in medicines) {
        if (med.id == m.medicineId) return med.name;
      }
      return 'Medicine #${m.medicineId}';
    }

    String skuOf(StockMovement m) {
      for (final med in medicines) {
        if (med.id == m.medicineId) return med.sku;
      }
      return '';
    }

    return ActivityReport.local(
      period: period,
      start: first,
      end: last,
      all: movements,
      nameOf: nameOf,
      skuOf: skuOf,
    );
  }
}

/// One tap: fetch the report, build the PDF, then open the share sheet
/// ("download") or the print dialog.
Future<void> downloadActivityReport(
  BuildContext context, {
  required String period,
  DateTime? date,
  DateTime? start,
  DateTime? end,
  ReportOutput output = ReportOutput.download,
  ActivityReport? ready,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  final prepared = preparedByName(context);

  var dialogOpen = true;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator()),
    ),
  ).whenComplete(() => dialogOpen = false);

  void closeDialog() {
    if (dialogOpen) navigator.pop();
  }

  try {
    final report = ready ??
        await loadActivityReport(
          context,
          period: period,
          date: date,
          start: start,
          end: end,
        );

    closeDialog();

    if (output == ReportOutput.print) {
      await ReportPrinter.printActivityReport(report, preparedBy: prepared);
    } else {
      await ReportPrinter.shareActivityReport(report, preparedBy: prepared);
    }
  } catch (e) {
    closeDialog();
    messenger.showSnackBar(
      SnackBar(content: Text('Could not create the PDF: $e')),
    );
  }
}

/// Asks for two dates and returns them (or null if cancelled).
Future<DateTimeRange?> pickReportRange(
  BuildContext context, {
  DateTimeRange? initial,
}) {
  final now = DateTime.now();

  return showDateRangePicker(
    context: context,
    firstDate: DateTime(2020),
    lastDate: DateTime(now.year + 1, 12, 31),
    initialDateRange: initial,
    helpText: 'Report period',
    saveText: 'Use these dates',
  );
}
