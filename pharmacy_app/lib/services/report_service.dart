import 'package:dio/dio.dart';

import '../models/expired_medicine_report.dart';
import '../models/fast_moving_medicine.dart';
import '../models/inventory_report.dart';
import '../models/monthly_movement_report.dart';
import '../models/slow_moving_medicine.dart';
import '../models/stock_valuation_report.dart';
import 'api_service.dart';

class ReportService {
  static const String _baseEndpoint = '/reports/';

  static Future<List<InventoryReport>> getInventoryReport() async {
    try {
      final response = await ApiService.dio.get(
        '${_baseEndpoint}inventory/',
      );

      return _parseList(
        response.data,
        (json) => InventoryReport.fromJson(json),
      );
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['detail'] ??
            'Failed to load inventory report.',
      );
    }
  }

  static Future<MonthlyMovementReport> getMonthlyMovementReport({
    required int year,
    required int month,
  }) async {
    try {
      final response = await ApiService.dio.get(
        '${_baseEndpoint}monthly-movements/',
        queryParameters: {
          'year': year,
          'month': month,
        },
      );

      return MonthlyMovementReport.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['detail'] ??
            'Failed to load monthly movement report.',
      );
    }
  }

  static Future<List<ExpiredMedicineReport>>
      getExpiredMedicineReport() async {
    try {
      final response = await ApiService.dio.get(
        '${_baseEndpoint}expired/',
      );

      return _parseList(
        response.data,
        (json) => ExpiredMedicineReport.fromJson(json),
      );
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['detail'] ??
            'Failed to load expired medicine report.',
      );
    }
  }

  static Future<List<StockValuationReport>>
      getStockValuationReport() async {
    try {
      final response = await ApiService.dio.get(
        '${_baseEndpoint}valuation/',
      );

      return _parseList(
        response.data,
        (json) => StockValuationReport.fromJson(json),
      );
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['detail'] ??
            'Failed to load stock valuation report.',
      );
    }
  }

  static Future<List<FastMovingMedicine>>
      getFastMovingMedicines() async {
    try {
      final response = await ApiService.dio.get(
        '${_baseEndpoint}fast-moving/',
      );

      return _parseList(
        response.data,
        (json) => FastMovingMedicine.fromJson(json),
      );
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['detail'] ??
            'Failed to load fast-moving medicine report.',
      );
    }
  }

  static Future<List<SlowMovingMedicine>>
      getSlowMovingMedicines() async {
    try {
      final response = await ApiService.dio.get(
        '${_baseEndpoint}slow-moving/',
      );

      return _parseList(
        response.data,
        (json) => SlowMovingMedicine.fromJson(json),
      );
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['detail'] ??
            'Failed to load slow-moving medicine report.',
      );
    }
  }

  static List<T> _parseList<T>(
    dynamic data,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (data is List) {
      return data
          .map(
            (json) => fromJson(
              json as Map<String, dynamic>,
            ),
          )
          .toList();
    }

    if (data is Map<String, dynamic> &&
        data['results'] is List) {
      return (data['results'] as List)
          .map(
            (json) => fromJson(
              json as Map<String, dynamic>,
            ),
          )
          .toList();
    }

    return [];
  }
}