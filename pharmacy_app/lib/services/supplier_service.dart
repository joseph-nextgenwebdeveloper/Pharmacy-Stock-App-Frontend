import 'package:dio/dio.dart';

import '../models/supplier.dart';
import 'api_service.dart';
import 'cache_service.dart';

class SupplierService {
  static const String _endpoint = '/suppliers/';
  static const String cacheKey = 'suppliers';

  static Future<List<Supplier>> getCachedSuppliers() async {
    final items = await CacheService.readList(cacheKey);
    return items.map(Supplier.fromJson).toList();
  }

  static Future<List<Supplier>> getSuppliers() async {
    try {
      final items = await ApiService.getAllPages(_endpoint);
      await CacheService.write(cacheKey, items);
      return items.map(Supplier.fromJson).toList();
    } on DioException catch (e) {
      throw ApiService.exceptionFor(e, 'Failed to load suppliers.');
    }
  }

  static Future<Supplier> getSupplier(
    int id,
  ) async {
    try {
      final response = await ApiService.dio.get(
        '$_endpoint$id/',
      );

      return Supplier.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiService.exceptionFor(e, 'Failed to load supplier.');
    }
  }

  static Future<Supplier> createSupplier(
    Supplier supplier,
  ) async {
    try {
      final response = await ApiService.dio.post(
        _endpoint,
        data: supplier.toJson(),
      );

      return Supplier.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiService.exceptionFor(e, 'Failed to create supplier.');
    }
  }

  static Future<Supplier> updateSupplier(
    Supplier supplier,
  ) async {
    try {
      final response = await ApiService.dio.put(
        '$_endpoint${supplier.id}/',
        data: supplier.toJson(),
      );

      return Supplier.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiService.exceptionFor(e, 'Failed to update supplier.');
    }
  }
}
