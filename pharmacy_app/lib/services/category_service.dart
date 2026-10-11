import 'package:dio/dio.dart';

import '../models/category.dart';
import 'api_service.dart';
import 'cache_service.dart';

class CategoryService {
  static const String cacheKey = 'categories';

  static Future<List<Category>> getCachedCategories() async {
    final items = await CacheService.readList(cacheKey);
    return items.map(Category.fromJson).toList();
  }

  static Future<List<Category>> getCategories() async {
    try {
      final items = await ApiService.getAllPages('/inventory/categories/');
      await CacheService.write(cacheKey, items);
      return items.map(Category.fromJson).toList();
    } on DioException catch (e) {
      throw ApiService.exceptionFor(e, 'Failed to load categories.');
    }
  }

  static Future<Category> getCategory(int id) async {
    try {
      final response = await ApiService.dio.get(
        '/inventory/categories/$id/',
      );

      return Category.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiService.exceptionFor(e, 'Failed to load category.');
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
      throw ApiService.exceptionFor(e, 'Failed to create category.');
    }
  }
}
