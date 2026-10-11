import 'package:flutter/foundation.dart';

import '../models/dashboard.dart';
import '../services/dashboard_service.dart';

class DashboardProvider extends ChangeNotifier {
  Dashboard? _dashboard;
  bool _isLoading = false;
  bool _hydrated = false;
  String? _error;

  Dashboard? get dashboard => _dashboard;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadDashboard() async {
    if (!_hydrated) {
      _hydrated = true;
      final cached = await DashboardService.getCachedDashboard();
      if (_dashboard == null && cached != null) {
        _dashboard = cached;
        notifyListeners();
      }
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _dashboard = await DashboardService.getDashboard();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await loadDashboard();
  }

  void reset() {
    _dashboard = null;
    _hydrated = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}