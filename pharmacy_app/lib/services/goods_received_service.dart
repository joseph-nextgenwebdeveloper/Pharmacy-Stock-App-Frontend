import 'package:dio/dio.dart';

import '../models/supplier.dart';
import 'api_service.dart';

class SupplierService {
  static const String _endpoint = '/suppliers/';

  static Future<List<Supplier>> getSuppliers() async {
    try {
      final response = await ApiService.dio.get(_endpoint);

      final data = response.data;

      if (data is List) {
        return data
            .map((json) => Supplier.fromJson(json))
            .toList();
      }

      if (data is Map<String, dynamic> &&
          data['results'] is List) {
        return (data['results'] as List)
            .map((json) => Supplier.fromJson(json))
            .toList();
      }

      return [];
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['detail'] ??
            'Failed to load suppliers.',
      );
    }
  }

  static Future<Supplier> getSupplier(int id) async {
    try {
      final response = await ApiService.dio.get(
        '$_endpoint$id/',
      );

      return Supplier.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['detail'] ??
            'Failed to load supplier.',
      );
    }
  }

  static Future<Supplier> createSupplier(
      Supplier supplier) async {
    try {
      final response = await ApiService.dio.post(
        _endpoint,
        data: supplier.toJson(),
      );

      return Supplier.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(
        e.response?.data.toString() ??
            'Failed to create supplier.',
      );
    }
  }

  static Future<Supplier> updateSupplier(
    int id,
    Supplier supplier,
  ) async {
    try {
      final response = await ApiService.dio.put(
        '$_endpoint$id/',
        data: supplier.toJson(),
      );

      return Supplier.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(
        e.response?.data.toString() ??
            'Failed to update supplier.',
      );
    }
  }
}