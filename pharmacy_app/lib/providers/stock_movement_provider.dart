import 'package:flutter/foundation.dart';

import '../models/stock_movement.dart';
import '../services/stock_movement_service.dart';

class StockMovementProvider extends ChangeNotifier {
  List<StockMovement> _movements = [];
  bool _isLoading = false;
  bool _hydrated = false;
  String? _error;

  List<StockMovement> get movements =>
      List.unmodifiable(_movements);

  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadMovements() async {
    if (!_hydrated) {
      _hydrated = true;
      final cached = await StockMovementService.getCachedMovements();
      if (_movements.isEmpty && cached.isNotEmpty) {
        _movements = cached;
        notifyListeners();
      }
    }

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

    list.sort(_newestFirst);

    return list;
  }

  /// The full ledger of one batch, most recent first.
  List<StockMovement> forBatch(int batchId) {
    final list = _movements.where((m) => m.batchId == batchId).toList();

    list.sort(_newestFirst);

    return list;
  }

  static int _newestFirst(StockMovement a, StockMovement b) {
    final aw = a.when;
    final bw = b.when;
    if (aw != null && bw != null) return bw.compareTo(aw);
    return b.id.compareTo(a.id);
  }

  /// Records a new stock in / stock out and refreshes the list.
  Future<bool> recordMovement({
    required int medicineId,
    int? batchId,
    required int quantity,
    required String movementType,
    String? reason,
    String? note,
    String? reference,
  }) async {
    try {
      await StockMovementService.createMovement(
        medicineId: medicineId,
        batchId: batchId,
        quantity: quantity,
        movementType: movementType,
        reason: reason,
        note: note,
        reference: reference,
      );

      await loadMovements();

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();

      return false;
    }
  }

  void reset() {
    _movements = [];
    _hydrated = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
