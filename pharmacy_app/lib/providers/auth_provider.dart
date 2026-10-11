import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/cache_service.dart';
import '../services/user_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  bool _isSavingProfile = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isSavingProfile => _isSavingProfile;
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
        // A different person signing in on this phone must not see the
        // previous person's saved data.
        await CacheService.ensureOwner(_user!.id);
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
    await CacheService.clearAll();

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

    if (_user != null) {
      // Pick up a new photo / name changed elsewhere. Silent if offline.
      refreshProfile();
    }
  }

  /// Re-reads the profile from the server (quietly keeps the old one when
  /// the phone is offline).
  Future<void> refreshProfile() async {
    try {
      final fresh = await UserService.getProfile();
      _user = fresh;
      await AuthService.saveUser(fresh.toJson());
      notifyListeners();
    } catch (_) {/* keep what we have */}
  }

  /// Saves name / phone and optionally a new photo (or removes it).
  Future<bool> updateProfile({
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? avatarPath,
    bool removeAvatar = false,
  }) async {
    _isSavingProfile = true;
    _error = null;
    notifyListeners();

    try {
      final updated = await UserService.updateProfile(
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
        avatarPath: avatarPath,
        removeAvatar: removeAvatar,
      );

      _user = updated;
      await AuthService.saveUser(updated.toJson());
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isSavingProfile = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
