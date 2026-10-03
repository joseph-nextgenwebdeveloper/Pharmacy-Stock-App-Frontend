import 'package:dio/dio.dart';

import '../models/category.dart';
import 'api_service.dart';

class CategoryService {
  static Future<List<Category>> getCategories() async {
    try {
      final items = await ApiService.getAllPages('/inventory/categories/');
      return items.map(Category.fromJson).toList();
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

  static Future<Category> createCategory({
    required String name,
    String description = '',
  }) async {
    try {
      final response = await ApiService.dio.post(
        '/inventory/categories/',
        data: {
          'name': name,
          'description': description,
        },
      );

      return Category.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final data = e.response?.data;

      if (data is Map<String, dynamic>) {
        throw Exception(data.toString());
      }

      throw Exception('Failed to create category.');
    }
  }
}