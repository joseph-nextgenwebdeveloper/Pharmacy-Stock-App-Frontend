import 'package:dio/dio.dart';

import '../models/sale.dart';
import 'api_service.dart';
import 'cache_service.dart';

class SaleService {
  static const String _endpoint = '/sales/';
  static const String cacheKey = 'sales';

  static List<Map<String, dynamic>> _rows(dynamic data) {
    List raw = const [];
    if (data is List) {
      raw = data;
    } else if (data is Map<String, dynamic> && data['results'] is List) {
      raw = data['results'] as List;
    }
    return raw
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  static Future<List<Sale>> getCachedSales() async {
    final items = await CacheService.readList(cacheKey);
    return items.map(Sale.fromJson).toList();
  }

  static Future<List<Sale>> getSales() async {
    try {
      final response = await ApiService.dio.get(_endpoint);
      final items = _rows(response.data);
      await CacheService.write(
        cacheKey,
        items.length > 300 ? items.sublist(0, 300) : items,
      );
      return items.map(Sale.fromJson).toList();
    } on DioException catch (e) {
      throw ApiService.exceptionFor(e, 'Failed to load sales.');
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
      throw ApiService.exceptionFor(e, 'Failed to load sale.');
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
      throw ApiService.exceptionFor(e, 'Failed to create sale.');
    }
  }
}
