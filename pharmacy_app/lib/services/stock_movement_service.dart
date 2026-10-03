import 'package:dio/dio.dart';

import '../models/stock_movement.dart';
import 'api_service.dart';

class StockMovementService {
  static const String _endpoint =
      '/inventory/stock-movements/';

  static Future<List<StockMovement>> getStockMovements() async {
    try {
      final items = await ApiService.getAllPages(_endpoint);
      return items.map(StockMovement.fromJson).toList();
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

  /// Records a stock in / stock out / correction movement.
  ///
  /// [movementType] should match whatever choices the backend's
  /// StockMovement.movement_type field expects (e.g. "IN", "OUT",
  /// "ADJUSTMENT"). Adjust the strings used from the UI if the backend
  /// uses different values.
  static Future<StockMovement> createMovement({
    required int medicineId,
    int? batchId,
    required int quantity,
    required String movementType,
    String? note,
  }) async {
    try {
      final response = await ApiService.dio.post(
        _endpoint,
        data: {
          'medicine': medicineId,
          if (batchId != null) 'batch': batchId,
          'quantity': quantity,
          'movement_type': movementType,
          if (note != null && note.isNotEmpty) 'note': note,
        },
      );

      return StockMovement.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      final data = e.response?.data;

      if (data is Map<String, dynamic>) {
        throw Exception(data.toString());
      }

      throw Exception('Failed to record stock movement.');
    }
  }
}