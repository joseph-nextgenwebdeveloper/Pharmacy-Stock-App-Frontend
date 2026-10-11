import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/stock_movement.dart';
import '../providers/auth_provider.dart';
import '../providers/inventory_provider.dart';
import '../services/report_printer.dart';

/// Name of whoever is signed in, for the "Prepared by" footer on printouts.
String? preparedByName(BuildContext context) {
  final user = context.read<AuthProvider>().user;
  if (user == null) return null;
  final name = user.fullName.trim();
  return name.isEmpty ? user.username : name;
}

/// Prints (or saves as PDF) everything that happened on [day].
Future<void> printDayReport(
  BuildContext context,
  DateTime day,
  List<StockMovement> moves,
) async {
  final medicines = context.read<InventoryProvider>().medicines;
  final prepared = preparedByName(context);
  final messenger = ScaffoldMessenger.of(context);

  String nameOf(StockMovement m) {
    if (m.medicineName.isNotEmpty) return m.medicineName;
    for (final med in medicines) {
      if (med.id == m.medicineId) return med.name;
    }
    return 'Medicine #${m.medicineId}';
  }

  try {
    await ReportPrinter.dailyActivity(
      day,
      moves,
      medicineName: nameOf,
      preparedBy: prepared,
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Could not open the print dialog: $e')),
    );
  }
}
