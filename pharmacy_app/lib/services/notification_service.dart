import 'package:dio/dio.dart';

import '../models/notification.dart';
import 'api_service.dart';

class NotificationService {
  static const String _endpoint = '/notifications/';

  static Future<List<AppNotification>> getNotifications() async {
    try {
      final response = await ApiService.dio.get(_endpoint);

      final data = response.data;

      if (data is List) {
        return data
            .map(
              (json) => AppNotification.fromJson(
                json as Map<String, dynamic>,
              ),
            )
            .toList();
      }

      if (data is Map<String, dynamic> &&
          data['results'] is List) {
        return (data['results'] as List)
            .map(
              (json) => AppNotification.fromJson(
                json as Map<String, dynamic>,
              ),
            )
            .toList();
      }

      return [];
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['detail'] ??
            'Failed to load notifications.',
      );
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
      throw Exception(
        e.response?.data?['detail'] ??
            'Failed to load notification.',
      );
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
      throw Exception(
        e.response?.data?['detail'] ??
            'Failed to mark notification as read.',
      );
    }
  }
}