import 'package:flutter/foundation.dart';

import '../models/sale.dart';
import '../services/sales_service.dart';

class SalesProvider extends ChangeNotifier {
  List<Sale> _sales = [];
  bool _isLoading = false;
  String? _error;

  List<Sale> get sales => List.unmodifiable(_sales);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadSales() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _sales = await SaleService.getSales();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await loadSales();
  }

  Future<bool> createSale(Sale sale) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final createdSale = await SaleService.createSale(sale);
      _sales.insert(0, createdSale);
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
