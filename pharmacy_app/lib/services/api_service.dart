import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_environment.dart';

class ApiService {
  static const FlutterSecureStorage _storage =
      FlutterSecureStorage();

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  // Render's free tier spins the backend down when idle — the first
  // request after a quiet period can take 30-50s to "wake" it. A short
  // timeout here doesn't actually stop that request on the server (it
  // keeps running and completes anyway), it just makes the app give up
  // and show a false failure to the person — e.g. retrying "register"
  // after a timeout hits "username already exists" because the first
  // request had, in fact, gone through. 60s gives cold starts room to
  // finish without the client bailing early.
  static const Duration _coldStartTimeout = Duration(seconds: 60);

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: AppEnvironment.apiBaseUrl,
      connectTimeout: _coldStartTimeout,
      receiveTimeout: _coldStartTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  // Separate, interceptor-free client used only for the refresh call so it
  // never recurses back into the 401 handler below.
  static final Dio _refreshDio = Dio(
    BaseOptions(
      baseUrl: AppEnvironment.apiBaseUrl,
      connectTimeout: _coldStartTimeout,
      receiveTimeout: _coldStartTimeout,
    ),
  );

  // Guards against many requests racing to refresh the same expired token
  // at once — they all await this single in-flight refresh instead.
  static Future<String?>? _refreshInFlight;

  static Future<void> initialize() async {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(
            key: _accessTokenKey,
          );

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          handler.next(options);
        },
        onError: (error, handler) async {
          final isUnauthorized = error.response?.statusCode == 401;
          final alreadyRetried = error.requestOptions.extra['retried'] == true;

          if (!isUnauthorized || alreadyRetried) {
            handler.next(error);
            return;
          }

          final newAccessToken = await _refreshAccessToken();

          if (newAccessToken == null) {
            // Refresh token is missing, expired, or blacklisted — this is
            // the only case where the person should actually be signed out.
            await _storage.delete(key: _accessTokenKey);
            await _storage.delete(key: _refreshTokenKey);
            handler.next(error);
            return;
          }

          // Replay the original request with the new access token.
          final retryOptions = error.requestOptions;
          retryOptions.extra['retried'] = true;
          retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';

          try {
            final response = await dio.fetch(retryOptions);
            handler.resolve(response);
          } on DioException catch (retryError) {
            handler.next(retryError);
          }
        },
      ),
    );
  }

  /// Follows a DRF-paginated list endpoint (PAGE_SIZE is 20 on this
  /// backend) and returns every item across every page. Without this,
  /// any list with more than 20 records — medicines, batches, stock
  /// movements — silently showed only its first page.
  static Future<List<Map<String, dynamic>>> getAllPages(
    String firstUrl,
  ) async {
    final items = <Map<String, dynamic>>[];
    String? url = firstUrl;

    while (url != null) {
      final response = await dio.get(url);
      final data = response.data;

      if (data is List) {
        items.addAll(data.cast<Map<String, dynamic>>());
        break;
      }

      if (data is Map<String, dynamic> && data['results'] is List) {
        items.addAll((data['results'] as List).cast<Map<String, dynamic>>());
        final next = data['next'] as String?;
        // "next" is an absolute URL; strip the baseUrl so Dio's base
        // options (and the auth header interceptor) still apply to it.
        url = next == null
            ? null
            : next.replaceFirst(AppEnvironment.apiBaseUrl, '');
      } else {
        break;
      }
    }

    return items;
  }

  /// Exchanges the stored refresh token for a new access token (and,
  /// since ROTATE_REFRESH_TOKENS is on, a new refresh token too), storing
  /// both. Returns the new access token, or null if refresh wasn't possible.
  static Future<String?> _refreshAccessToken() {
    return _refreshInFlight ??= _doRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  static Future<String?> _doRefresh() async {
    final refreshToken = await _storage.read(key: _refreshTokenKey);

    if (refreshToken == null || refreshToken.isEmpty) {
      return null;
    }

    try {
      final response = await _refreshDio.post(
        '/accounts/token/refresh/',
        data: jsonEncode({'refresh': refreshToken}),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      final newAccess = response.data['access'] as String?;
      final newRefresh = response.data['refresh'] as String?;

      if (newAccess == null) return null;

      await _storage.write(key: _accessTokenKey, value: newAccess);

      if (newRefresh != null && newRefresh.isNotEmpty) {
        await _storage.write(key: _refreshTokenKey, value: newRefresh);
      }

      return newAccess;
    } catch (_) {
      return null;
    }
  }
}
