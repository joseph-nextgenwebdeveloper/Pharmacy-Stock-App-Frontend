import 'package:flutter/foundation.dart';

import '../models/medicine.dart';
import '../services/inventory_service.dart';
import '../services/stock_alert_service.dart';

class InventoryProvider extends ChangeNotifier {
  List<Medicine> _medicines = [];
  bool _isLoading = false;
  bool _hydrated = false;
  String? _error;

  List<Medicine> get medicines => List.unmodifiable(_medicines);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Medicine? byId(int id) {
    for (final m in _medicines) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Fills the list from what is saved on the phone (instantly), then
  /// refreshes it from the server. If the server can't be reached the saved
  /// copy simply stays on screen.
  Future<void> loadMedicines() async {
    if (!_hydrated) {
      _hydrated = true;
      final cached = await InventoryService.getCachedMedicines();
      if (_medicines.isEmpty && cached.isNotEmpty) {
        _medicines = cached;
        notifyListeners();
      }
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _medicines = await InventoryService.getMedicines();
      // Out-of-stock phone notifications follow the real stock levels.
      StockAlertService.sync(_medicines);
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

  /// Forget everything (used on sign-out).
  void reset() {
    _medicines = [];
    _hydrated = false;
    _error = null;
    notifyListeners();
  }

  // ---- Derived stock-health stats ----

  int get totalUnits =>
      _medicines.fold(0, (sum, m) => sum + m.quantity);

  List<Medicine> get outOfStock =>
      _medicines.where((m) => m.quantity <= 0).toList();

  List<Medicine> get lowStock => _medicines
      .where((m) => m.quantity > 0 && m.quantity <= m.reorderLevel)
      .toList();

  List<Medicine> get healthyStock =>
      _medicines.where((m) => m.quantity > m.reorderLevel).toList();

  /// SKUs that are not below their reorder threshold, out of the total.
  int get wellStockedCount => healthyStock.length;
}
