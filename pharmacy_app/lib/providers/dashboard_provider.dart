import 'package:flutter/foundation.dart';

import '../models/dashboard.dart';
import '../services/dashboard_service.dart';

class DashboardProvider extends ChangeNotifier {
  Dashboard? _dashboard;
  bool _isLoading = false;
  String? _error;

  Dashboard? get dashboard => _dashboard;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadDashboard() async {
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

  void clearError() {
    _error = null;
    notifyListeners();
  }
}