import 'package:flutter/foundation.dart';

import '../models/batch.dart';
import '../services/batch_service.dart';

class BatchProvider extends ChangeNotifier {
  List<Batch> _batches = [];
  bool _isLoading = false;
  String? _error;

  List<Batch> get batches => List.unmodifiable(_batches);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadBatches() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _batches = await BatchService.getBatches();
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
