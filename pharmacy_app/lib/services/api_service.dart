import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_exception.dart';
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

  // ------------------------------------------------------------------
  // Connectivity. There is no extra plugin: the app simply notices whether
  // its own requests reach the server. Any HTTP response (even an error
  // status) means "online"; a connection error / timeout means "offline".
  // ------------------------------------------------------------------
  static const String offlineMessage =
      'You are offline. Connect to the internet to save changes.';

  static final ValueNotifier<bool> online = ValueNotifier<bool>(true);
  static DateTime? lastSuccessAt;

  static bool isConnectionError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return true;
      default:
        return e.error is SocketException;
    }
  }

  static void _markOnline() {
    lastSuccessAt = DateTime.now();
    if (!online.value) online.value = true;
  }

  static void _markOffline() {
    if (online.value) online.value = false;
  }

  /// Quick "can I reach the server?" probe (used by the offline banner's
  /// Retry button and the background re-check while offline).
  static Future<bool> checkConnection() async {
    try {
      await _refreshDio.get(
        '/accounts/profile/',
        options: Options(
          validateStatus: (_) => true,
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      _markOnline();
      return true;
    } catch (_) {
      _markOffline();
      return false;
    }
  }

  /// Turns any failure into one readable sentence: "You are offline...",
  /// the server's own message ("Quantity: Not enough stock in this batch
  /// (only 5 left)."), or [fallback].
  static String messageFor(Object error, [String fallback = 'Something went wrong.']) {
    if (error is ApiException) return error.message;

    if (error is DioException) {
      if (isConnectionError(error)) return offlineMessage;

      final parsed = _parseBody(error.response?.data);
      if (parsed != null && parsed.isNotEmpty) return parsed;

      final code = error.response?.statusCode;
      if (code == 401) return 'Your session expired. Please sign in again.';
      if (code == 403) return 'You do not have permission to do that.';
      if (code != null && code >= 500) {
        return 'The server had a problem. Please try again in a moment.';
      }
    }
    return fallback;
  }

  static ApiException exceptionFor(Object error, [String fallback = 'Something went wrong.']) {
    final offline = error is DioException && isConnectionError(error);
    return ApiException(messageFor(error, fallback), offline: offline);
  }

  static String _pretty(String key) {
    if (key == 'non_field_errors' || key == 'detail' || key == 'error') return '';
    final spaced = key.replaceAll('_', ' ');
    return spaced.isEmpty ? '' : '${spaced[0].toUpperCase()}${spaced.substring(1)}';
  }

  static String? _parseBody(dynamic data) {
    if (data is String) {
      final t = data.trim();
      if (t.isEmpty || t.startsWith('<') || t.length > 300) return null;
      return t;
    }
    if (data is List) {
      for (final item in data) {
        final r = _parseBody(item);
        if (r != null) return r;
      }
      return null;
    }
    if (data is Map) {
      final parts = <String>[];
      data.forEach((key, value) {
        final inner = _parseBody(value);
        if (inner == null) return;
        final label = _pretty(key.toString());
        parts.add(label.isEmpty ? inner : '$label: $inner');
      });
      return parts.isEmpty ? null : parts.join('\n');
    }
    return null;
  }

  static Future<void> initialize() async {
    dio.interceptors.add(
      InterceptorsWrapper(
        onResponse: (response, handler) {
          _markOnline();
          handler.next(response);
        },
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
          if (isConnectionError(error)) {
            _markOffline();
          } else if (error.response != null) {
            _markOnline();
          }

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

    // Ask for big pages: far fewer round trips (the backend caps at 500).
    String? url = firstUrl.contains('page_size')
        ? firstUrl
        : '$firstUrl${firstUrl.contains('?') ? '&' : '?'}page_size=200';

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
