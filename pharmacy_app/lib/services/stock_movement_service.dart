import 'package:dio/dio.dart';

import '../models/stock_movement.dart';
import 'api_service.dart';

class StockMovementService {
  static const String _endpoint =
      '/inventory/stock-movements/';

  static Future<List<StockMovement>> getStockMovements() async {
    try {
      final response = await ApiService.dio.get(_endpoint);

      final data = response.data;

      if (data is List) {
        return data
            .map(
              (json) => StockMovement.fromJson(
                json as Map<String, dynamic>,
              ),
            )
            .toList();
      }

      if (data is Map<String, dynamic> &&
          data['results'] is List) {
        return (data['results'] as List)
            .map(
              (json) => StockMovement.fromJson(
                json as Map<String, dynamic>,
              ),
            )
            .toList();
      }

      return [];
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['detail'] ??
            'Failed to load stock movements.',
      );
    }
  }

  static Future<StockMovement> getStockMovement(
    int id,
  ) async {
    try {
      final response = await ApiService.dio.get(
        '$_endpoint$id/',
      );

      return StockMovement.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['detail'] ??
            'Failed to load stock movement.',
      );
    }
  }
}