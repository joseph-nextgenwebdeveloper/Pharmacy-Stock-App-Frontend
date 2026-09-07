import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_service.dart';

class AuthService {
  static const FlutterSecureStorage _storage =
      FlutterSecureStorage();

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userKey = 'user';

  static Future<bool> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await ApiService.dio.post(
        '/accounts/login/',
        data: {
          'email': email,
          'password': password,
        },
      );

      final data = response.data;

      final accessToken = data['access'];
      final refreshToken = data['refresh'];

      if (accessToken == null || refreshToken == null) {
        return false;
      }

      await _storage.write(
        key: _accessTokenKey,
        value: accessToken.toString(),
      );

      await _storage.write(
        key: _refreshTokenKey,
        value: refreshToken.toString(),
      );

      final user = {
        'id': data['id'],
        'username': data['username'],
        'email': data['email'],
        'phone_number': data['phone_number'],
        'role': data['role'],
        'first_name': data['first_name'],
        'last_name': data['last_name'],
      };

      await _storage.write(
        key: _userKey,
        value: jsonEncode(user),
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> getAccessToken() async {
    return _storage.read(key: _accessTokenKey);
  }

  static Future<String?> getRefreshToken() async {
    return _storage.read(key: _refreshTokenKey);
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final userData = await _storage.read(key: _userKey);

    if (userData == null || userData.isEmpty) {
      return null;
    }

    try {
      return jsonDecode(userData) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();

    return token != null && token.isNotEmpty;
  }

  static Future<void> logout() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userKey);
  }
}