import 'package:dio/dio.dart';

import 'api_service.dart';

class PurchaseService {
  static const String _endpoint = '/purchases/goods-received/';

  static Future<List<dynamic>> getGoodsReceived() async {
    try {
      final response = await ApiService.dio.get(_endpoint);

      final data = response.data;

      if (data is List) {
        return data;
      }

      if (data is Map<String, dynamic> &&
          data['results'] is List) {
        return data['results'];
      }

      return [];
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['detail'] ??
            'Failed to load deliveries.',
      );
    }
  }

  static Future<Map<String, dynamic>> getGoodsReceivedDetail(
      int id) async {
    try {
      final response = await ApiService.dio.get(
        '$_endpoint$id/',
      );

      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['detail'] ??
            'Failed to load delivery.',
      );
    }
  }

  static Future<void> createGoodsReceived(
      Map<String, dynamic> data) async {
    try {
      await ApiService.dio.post(
        _endpoint,
        data: data,
      );
    } on DioException catch (e) {
      throw Exception(
        e.response?.data.toString() ??
            'Failed to save delivery.',
      );
    }
  }
}