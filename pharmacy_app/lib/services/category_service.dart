import 'package:dio/dio.dart';

import '../models/category.dart';
import 'api_service.dart';

class CategoryService {
  static Future<List<Category>> getCategories() async {
    try {
      final response = await ApiService.dio.get(
        '/inventory/categories/',
      );

      final data = response.data;

      if (data is List) {
        return data
            .map((json) => Category.fromJson(json))
            .toList();
      }

      if (data is Map<String, dynamic> &&
          data['results'] is List) {
        return (data['results'] as List)
            .map((json) => Category.fromJson(json))
            .toList();
      }

      return [];
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['detail'] ??
            'Failed to load categories.',
      );
    }
  }

  static Future<Category> getCategory(int id) async {
    try {
      final response = await ApiService.dio.get(
        '/inventory/categories/$id/',
      );

      return Category.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['detail'] ??
            'Failed to load category.',
      );
    }
  }
}