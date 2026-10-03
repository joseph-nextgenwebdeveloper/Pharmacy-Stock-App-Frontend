import 'package:flutter/foundation.dart';

import '../models/expired_medicine_report.dart';
import '../models/fast_moving_medicine.dart';
import '../models/inventory_report.dart';
import '../models/monthly_movement_report.dart';
import '../models/slow_moving_medicine.dart';
import '../models/stock_valuation_report.dart';
import '../services/report_service.dart';

class ReportProvider extends ChangeNotifier {
  List<InventoryReport> _inventoryReport = [];
  List<StockValuationReport> _stockValuationReport = [];
  List<ExpiredMedicineReport> _expiredMedicineReport = [];
  MonthlyMovementReport? _monthlyMovementReport;
  List<FastMovingMedicine> _fastMovingMedicines = [];
  List<SlowMovingMedicine> _slowMovingMedicines = [];

  bool _isLoading = false;
  String? _error;

  List<InventoryReport> get inventoryReport =>
      List.unmodifiable(_inventoryReport);

  List<StockValuationReport> get stockValuationReport =>
      List.unmodifiable(_stockValuationReport);

  List<ExpiredMedicineReport> get expiredMedicineReport =>
      List.unmodifiable(_expiredMedicineReport);

  MonthlyMovementReport? get monthlyMovementReport =>
      _monthlyMovementReport;

  List<FastMovingMedicine> get fastMovingMedicines =>
      List.unmodifiable(_fastMovingMedicines);

  List<SlowMovingMedicine> get slowMovingMedicines =>
      List.unmodifiable(_slowMovingMedicines);

  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadInventoryReport() async {
    await _run(() async {
      _inventoryReport =
          await ReportService.getInventoryReport();
    });
  }

  Future<void> loadStockValuationReport() async {
    await _run(() async {
      _stockValuationReport =
          await ReportService.getStockValuationReport();
    });
  }

  Future<void> loadExpiredMedicineReport() async {
    await _run(() async {
      _expiredMedicineReport =
          await ReportService.getExpiredMedicineReport();
    });
  }

  Future<void> loadMonthlyMovementReport({
    required int year,
    required int month,
  }) async {
    await _run(() async {
      _monthlyMovementReport =
          await ReportService.getMonthlyMovementReport(
        year: year,
        month: month,
      );
    });
  }

  Future<void> loadFastMovingMedicines() async {
    await _run(() async {
      _fastMovingMedicines =
          await ReportService.getFastMovingMedicines();
    });
  }

  Future<void> loadSlowMovingMedicines() async {
    await _run(() async {
      _slowMovingMedicines =
          await ReportService.getSlowMovingMedicines();
    });
  }

  Future<void> _run(
    Future<void> Function() action,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await action();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}