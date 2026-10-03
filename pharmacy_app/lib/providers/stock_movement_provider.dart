import 'package:flutter/foundation.dart';

import '../models/stock_movement.dart';
import '../services/stock_movement_service.dart';

class StockMovementProvider extends ChangeNotifier {
  List<StockMovement> _movements = [];
  bool _isLoading = false;
  String? _error;

  List<StockMovement> get movements =>
      List.unmodifiable(_movements);

  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadMovements() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _movements =
          await StockMovementService.getStockMovements();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await loadMovements();
  }

  /// All movements for a single medicine, most recent first.
  List<StockMovement> forMedicine(int medicineId) {
    final list = _movements
        .where((m) => m.medicineId == medicineId)
        .toList();

    list.sort((a, b) => b.date.compareTo(a.date));

    return list;
  }

  /// Records a new stock in / stock out / correction and refreshes the list.
  Future<bool> recordMovement({
    required int medicineId,
    int? batchId,
    required int quantity,
    required String movementType,
    String? note,
  }) async {
    try {
      await StockMovementService.createMovement(
        medicineId: medicineId,
        batchId: batchId,
        quantity: quantity,
        movementType: movementType,
        note: note,
      );

      await loadMovements();

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();

      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}