import 'package:dio/dio.dart';

import '../models/stock_movement.dart';
import 'api_service.dart';
import 'cache_service.dart';

class StockMovementService {
  static const String _endpoint =
      '/inventory/stock-movements/';
  static const String cacheKey = 'movements';

  /// The cache keeps only the newest entries so it stays small and fast.
  static const int _cacheLimit = 600;

  static Future<List<StockMovement>> getCachedMovements() async {
    final items = await CacheService.readList(cacheKey);
    return items.map(StockMovement.fromJson).toList();
  }

  static Future<List<StockMovement>> getStockMovements() async {
    try {
      final items = await ApiService.getAllPages(_endpoint);
      await CacheService.write(
        cacheKey,
        items.length > _cacheLimit ? items.sublist(0, _cacheLimit) : items,
      );
      return items.map(StockMovement.fromJson).toList();
    } on DioException catch (e) {
      throw ApiService.exceptionFor(e, 'Failed to load stock movements.');
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
      throw ApiService.exceptionFor(e, 'Failed to load stock movement.');
    }
  }

  /// Records a stock in / stock out movement.
  ///
  /// [movementType] is "IN" or "OUT". [reason] is one of RECEIVED, RETURNED,
  /// DISPENSED, DAMAGED, EXPIRED, COUNT_DISCREPANCY, CORRECTION, OTHER; when
  /// omitted the server uses RECEIVED for IN and DISPENSED for OUT.
  static Future<StockMovement> createMovement({
    required int medicineId,
    int? batchId,
    required int quantity,
    required String movementType,
    String? reason,
    String? note,
    String? reference,
  }) async {
    try {
      final response = await ApiService.dio.post(
        _endpoint,
        data: {
          'medicine': medicineId,
          if (batchId != null) 'batch': batchId,
          'quantity': quantity,
          'movement_type': movementType,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
          if (note != null && note.isNotEmpty) 'note': note,
          if (reference != null && reference.isNotEmpty) 'reference': reference,
        },
      );

      return StockMovement.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiService.exceptionFor(e, 'Failed to record stock movement.');
    }
  }
}
