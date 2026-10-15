import 'package:flutter/foundation.dart';

import '../models/batch.dart';
import '../services/batch_service.dart';
import '../services/stock_alert_service.dart';

class BatchProvider extends ChangeNotifier {
  List<Batch> _batches = [];
  bool _isLoading = false;
  bool _hydrated = false;
  String? _error;

  List<Batch> get batches => List.unmodifiable(_batches);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadBatches() async {
    if (!_hydrated) {
      _hydrated = true;
      final cached = await BatchService.getCachedBatches();
      if (_batches.isEmpty && cached.isNotEmpty) {
        _batches = cached;
        notifyListeners();
      }
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _batches = await BatchService.getBatches();
      // One "expired products" phone notification a day.
      StockAlertService.syncExpired(_batches);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await loadBatches();
  }

  List<Batch> forMedicine(int medicineId) {
    final list =
        _batches.where((b) => b.medicineId == medicineId).toList();

    list.sort((a, b) => b.expiryDate.compareTo(a.expiryDate));

    return list;
  }

  /// Batches of one medicine that can still be sold: in stock and not
  /// expired, earliest expiry first — i.e. FEFO (First Expiry, First Out).
  List<Batch> fefoFor(int medicineId) {
    final list = _batches
        .where((b) => b.medicineId == medicineId && b.isActive)
        .toList();

    list.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

    return list;
  }

  /// A specific lot of a medicine, e.g. from a scanned GS1 code.
  Batch? findLot(int medicineId, String batchNumber) {
    final wanted = batchNumber.trim().toLowerCase();

    for (final b in _batches) {
      if (b.medicineId == medicineId &&
          b.batchNumber.trim().toLowerCase() == wanted) {
        return b;
      }
    }
    return null;
  }

  void reset() {
    _batches = [];
    _hydrated = false;
    notifyListeners();
  }

  Batch? byId(int id) {
    for (final b in _batches) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// Creates a batch on the backend and adds it locally on success.
  Future<Batch?> createBatch(Batch batch) async {
    try {
      final created = await BatchService.createBatch(batch);

      _batches = [..._batches, created];
      notifyListeners();

      return created;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }
}
