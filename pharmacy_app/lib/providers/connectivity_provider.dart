import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import '../services/cache_service.dart';

/// Tells the UI whether the phone can reach the server, and when the data
/// on screen was last refreshed. Drives the "You are offline" banner.
class ConnectivityProvider extends ChangeNotifier {
  Timer? _probe;
  bool _checking = false;

  ConnectivityProvider() {
    ApiService.online.addListener(_onChanged);
  }

  bool get isOnline => ApiService.online.value;
  bool get isChecking => _checking;

  /// When the data currently shown was last downloaded.
  DateTime? get lastSync => ApiService.lastSuccessAt ?? CacheService.newestSavedAt;

  void _onChanged() {
    if (isOnline) {
      _probe?.cancel();
      _probe = null;
    } else {
      // While offline, quietly look for the connection coming back.
      _probe ??= Timer.periodic(const Duration(seconds: 20), (_) => retry());
    }
    notifyListeners();
  }

  /// Tries to reach the server now (banner "Retry" button).
  Future<bool> retry() async {
    if (_checking) return isOnline;
    _checking = true;
    notifyListeners();

    final ok = await ApiService.checkConnection();

    _checking = false;
    notifyListeners();
    return ok;
  }

  @override
  void dispose() {
    _probe?.cancel();
    ApiService.online.removeListener(_onChanged);
    super.dispose();
  }
}
