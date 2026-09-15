import 'package:dio/dio.dart';

import '../models/user.dart';
import 'api_service.dart';

class UserService {
  static const String _endpoint = '/accounts/profile/';

  static Future<User> getProfile() async {
    try {
      final response = await ApiService.dio.get(
        _endpoint,
      );

      return User.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      final data = e.response?.data;

      if (data is Map<String, dynamic>) {
        throw Exception(
          data['detail'] ??
              data['error'] ??
              'Failed to load profile.',
        );
      }

      throw Exception(
        'Failed to load profile.',
      );
    }
  }
}