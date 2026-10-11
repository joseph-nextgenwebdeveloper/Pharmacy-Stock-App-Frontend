import 'package:dio/dio.dart';

import '../models/dashboard.dart';
import 'api_service.dart';
import 'cache_service.dart';

class DashboardService {
  static const String _endpoint = '/dashboard/';
  static const String cacheKey = 'dashboard';

  static Future<Dashboard?> getCachedDashboard() async {
    final map = await CacheService.readMap(cacheKey);
    return map == null ? null : Dashboard.fromJson(map);
  }

  static Future<Dashboard> getDashboard() async {
    try {
      final response = await ApiService.dio.get(
        _endpoint,
      );

      final data = response.data as Map<String, dynamic>;
      await CacheService.write(cacheKey, data);
      return Dashboard.fromJson(data);
    } on DioException catch (e) {
      throw ApiService.exceptionFor(e, 'Failed to load dashboard data.');
    }
  }
}
