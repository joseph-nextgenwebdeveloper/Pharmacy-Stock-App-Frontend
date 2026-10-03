import 'package:dio/dio.dart';

import '../models/supplier.dart';
import 'api_service.dart';

class SupplierService {
  static const String _endpoint = '/suppliers/';

  static Future<List<Supplier>> getSuppliers() async {
    try {
      final response = await ApiService.dio.get(
        _endpoint,
      );

      final data = response.data;

      if (data is List) {
        return data
            .map(
              (json) => Supplier.fromJson(
                json as Map<String, dynamic>,
              ),
            )
            .toList();
      }

      if (data is Map<String, dynamic> &&
          data['results'] is List) {
        return (data['results'] as List)
            .map(
              (json) => Supplier.fromJson(
                json as Map<String, dynamic>,
              ),
            )
            .toList();
      }

      return [];
    } on DioException catch (e) {
      final data = e.response?.data;

      if (data is Map<String, dynamic>) {
        throw Exception(
          data['detail'] ??
              data.toString(),
        );
      }

      throw Exception(
        'Failed to load suppliers.',
      );
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
      final data = e.response?.data;

      if (data is Map<String, dynamic>) {
        throw Exception(
          data['detail'] ??
              data.toString(),
        );
      }

      throw Exception(
        'Failed to load supplier.',
      );
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
      final data = e.response?.data;

      if (data is Map<String, dynamic>) {
        throw Exception(
          data.toString(),
        );
      }

      throw Exception(
        'Failed to create supplier.',
      );
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
      final data = e.response?.data;

      if (data is Map<String, dynamic>) {
        throw Exception(
          data.toString(),
        );
      }

      throw Exception(
        'Failed to update supplier.',
      );
    }
  }
}