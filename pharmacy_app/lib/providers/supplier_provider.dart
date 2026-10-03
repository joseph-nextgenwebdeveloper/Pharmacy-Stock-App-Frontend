import 'package:flutter/foundation.dart';

import '../models/supplier.dart';
import '../services/supplier_service.dart';

class SupplierProvider extends ChangeNotifier {
  List<Supplier> _suppliers = [];
  bool _isLoading = false;
  String? _error;

  List<Supplier> get suppliers => List.unmodifiable(_suppliers);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadSuppliers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _suppliers = await SupplierService.getSuppliers();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await loadSuppliers();
  }

  Future<bool> createSupplier(Supplier supplier) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final createdSupplier =
          await SupplierService.createSupplier(supplier);

      _suppliers.insert(0, createdSupplier);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateSupplier(Supplier supplier) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedSupplier =
          await SupplierService.updateSupplier(supplier);

      final index = _suppliers.indexWhere(
        (item) => item.id == supplier.id,
      );

      if (index != -1) {
        _suppliers[index] = updatedSupplier;
      }

      return true;
    } catch (e) {
      _error = e.toString();
      return false;
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