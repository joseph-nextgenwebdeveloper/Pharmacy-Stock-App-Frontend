import 'package:dio/dio.dart';

import '../models/notification.dart';
import 'api_service.dart';
import 'cache_service.dart';

class NotificationService {
  static const String _endpoint = '/notifications/';
  static const String cacheKey = 'notifications';

  static Future<List<AppNotification>> getCachedNotifications() async {
    final items = await CacheService.readList(cacheKey);
    return items.map(AppNotification.fromJson).toList();
  }

  static Future<List<AppNotification>> getNotifications() async {
    try {
      final response = await ApiService.dio.get(
        _endpoint,
        queryParameters: {'page_size': 100},
      );

      final data = response.data;
      List raw = const [];

      if (data is List) {
        raw = data;
      } else if (data is Map<String, dynamic> && data['results'] is List) {
        raw = data['results'] as List;
      }

      final items = raw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();

      await CacheService.write(cacheKey, items);
      return items.map(AppNotification.fromJson).toList();
    } on DioException catch (e) {
      throw ApiService.exceptionFor(e, 'Failed to load notifications.');
    }
  }

  static Future<AppNotification> getNotification(
    int id,
  ) async {
    try {
      final response = await ApiService.dio.get(
        '$_endpoint$id/',
      );

      return AppNotification.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiService.exceptionFor(e, 'Failed to load notification.');
    }
  }

  static Future<AppNotification> markAsRead(
    int id,
  ) async {
    try {
      final response = await ApiService.dio.patch(
        '$_endpoint$id/mark-as-read/',
      );

      return AppNotification.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiService.exceptionFor(e, 'Failed to mark notification as read.');
    }
  }

  static Future<void> markAllAsRead() async {
    try {
      await ApiService.dio.post('${_endpoint}mark-all-read/');
    } on DioException catch (e) {
      throw ApiService.exceptionFor(e, 'Failed to mark notifications as read.');
    }
  }
}
