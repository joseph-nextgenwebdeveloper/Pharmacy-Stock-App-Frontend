import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await AuthService.login(
        email: email,
        password: password,
      );

      if (!success) {
        _error = 'Invalid email or password.';
        return false;
      }

      final userData = await AuthService.getUser();

      if (userData != null) {
        _user = User.fromJson(userData);
      }

      return true;
    } catch (e) {
      _error = e.toString();
      _user = null;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await AuthService.logout();

    _user = null;
    _error = null;
    notifyListeners();
  }

  Future<void> loadStoredUser() async {
    try {
      final loggedIn = await AuthService.isLoggedIn();

      if (!loggedIn) {
        _user = null;
        return;
      }

      final userData = await AuthService.getUser();

      if (userData != null) {
        _user = User.fromJson(userData);
      }
    } catch (e) {
      _user = null;
    }

    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}