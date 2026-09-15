import 'package:dio/dio.dart';

import '../models/dashboard.dart';
import 'api_service.dart';

class DashboardService {
  static const String _endpoint = '/dashboard/';

  static Future<Dashboard> getDashboard() async {
    try {
      final response = await ApiService.dio.get(
        _endpoint,
      );

      return Dashboard.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['detail'] ??
            'Failed to load dashboard data.',
      );
    }
  }
}