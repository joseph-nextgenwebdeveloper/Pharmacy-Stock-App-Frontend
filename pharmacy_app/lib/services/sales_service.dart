import 'package:dio/dio.dart';

import '../models/sale.dart';
import 'api_service.dart';

class SaleService {
  static const String _endpoint = '/sales/';

  static Future<List<Sale>> getSales() async {
    try {
      final response = await ApiService.dio.get(_endpoint);

      final data = response.data;

      if (data is List) {
        return data
            .map(
              (json) => Sale.fromJson(
                json as Map<String, dynamic>,
              ),
            )
            .toList();
      }

      if (data is Map<String, dynamic> &&
          data['results'] is List) {
        return (data['results'] as List)
            .map(
              (json) => Sale.fromJson(
                json as Map<String, dynamic>,
              ),
            )
            .toList();
      }

      return [];
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['detail'] ??
            'Failed to load sales.',
      );
    }
  }

  static Future<Sale> getSale(int id) async {
    try {
      final response = await ApiService.dio.get(
        '$_endpoint$id/',
      );

      return Sale.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['detail'] ??
            'Failed to load sale.',
      );
    }
  }

  static Future<Sale> createSale(
    Sale sale,
  ) async {
    try {
      final response = await ApiService.dio.post(
        _endpoint,
        data: sale.toJson(),
      );

      return Sale.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw Exception(
        e.response?.data.toString() ??
            'Failed to create sale.',
      );
    }
  }
}