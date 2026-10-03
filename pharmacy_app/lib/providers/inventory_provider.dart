import 'package:flutter/foundation.dart';

import '../models/medicine.dart';
import '../services/inventory_service.dart';

class InventoryProvider extends ChangeNotifier {
  List<Medicine> _medicines = [];
  bool _isLoading = false;
  String? _error;

  List<Medicine> get medicines => List.unmodifiable(_medicines);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadMedicines() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _medicines = await InventoryService.getMedicines();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await loadMedicines();
  }

  /// Creates a medicine on the backend and appends it locally on success.
  Future<Medicine?> createMedicine(Medicine medicine, {String? imagePath}) async {
    try {
      final created = await InventoryService.createMedicine(
        medicine,
        imagePath: imagePath,
      );

      _medicines = [..._medicines, created];
      notifyListeners();

      return created;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ---- Derived stock-health stats (no dedicated backend endpoint yet) ----

  int get totalUnits =>
      _medicines.fold(0, (sum, m) => sum + m.quantity);

  List<Medicine> get outOfStock =>
      _medicines.where((m) => m.quantity <= 0).toList();

  List<Medicine> get lowStock => _medicines
      .where((m) => m.quantity > 0 && m.quantity <= m.reorderLevel)
      .toList();

  List<Medicine> get healthyStock => _medicines
      .where((m) => m.quantity > m.reorderLevel)
      .toList();

  /// SKUs that are not below their reorder threshold, out of the total.
  int get wellStockedCount => healthyStock.length;
}