import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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

  static Future<String?> register({
    required String username,
    String? firstName,
    String? lastName,
    required String email,
    String? phoneNumber,
    required String password,
  }) async {
    try {
      final data = {
        'username': username,
        'email': email,
        'password': password,
      };

      if (firstName != null && firstName.trim().isNotEmpty) {
        data['first_name'] = firstName.trim();
      }

      if (lastName != null && lastName.trim().isNotEmpty) {
        data['last_name'] = lastName.trim();
      }

      if (phoneNumber != null &&
          phoneNumber.trim().isNotEmpty) {
        data['phone_number'] = phoneNumber.trim();
      }

      await ApiService.dio.post(
        '/accounts/register/',
        data: data,
      );

      return null;
    } on DioException catch (e) {
      debugPrint(
        'REGISTER ERROR TYPE: ${e.type}',
      );
      debugPrint(
        'REGISTER ERROR MESSAGE: ${e.message}',
      );
      debugPrint(
        'REGISTER ERROR STATUS: ${e.response?.statusCode}',
      );
      debugPrint(
        'REGISTER ERROR DATA: ${e.response?.data}',
      );

      final responseData = e.response?.data;

      if (responseData is Map) {
        for (final entry in responseData.entries) {
          final value = entry.value;

          if (value is List && value.isNotEmpty) {
            return value.first.toString();
          }

          if (value is String && value.isNotEmpty) {
            return value;
          }
        }
      }

      return 'Registration failed. Please check your details and try again.';
    } catch (_) {
      return 'Registration failed. Please try again.';
    }
  }

  static Future<String?> getAccessToken() async =>
      _storage.read(key: _accessTokenKey);

  static Future<String?> getRefreshToken() async =>
      _storage.read(key: _refreshTokenKey);

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