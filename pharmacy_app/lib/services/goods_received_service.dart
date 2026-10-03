import 'package:dio/dio.dart';

import '../models/goods_received.dart';
import 'api_service.dart';

class GoodsReceivedService {
  static const String _endpoint = '/purchases/goods-received/';

  static Future<List<GoodsReceived>> getGoodsReceived() async {
    try {
      final response = await ApiService.dio.get(_endpoint);

      final data = response.data;

      if (data is List) {
        return data
            .map(
              (json) => GoodsReceived.fromJson(
                json as Map<String, dynamic>,
              ),
            )
            .toList();
      }

      if (data is Map<String, dynamic> &&
          data['results'] is List) {
        return (data['results'] as List)
            .map(
              (json) => GoodsReceived.fromJson(
                json as Map<String, dynamic>,
              ),
            )
            .toList();
      }

      return [];
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['detail'] ??
            'Failed to load deliveries.',
      );
    }
  }

  static Future<GoodsReceived> getGoodsReceivedDetail(
    int id,
  ) async {
    try {
      final response = await ApiService.dio.get(
        '$_endpoint$id/',
      );

      return GoodsReceived.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['detail'] ??
            'Failed to load delivery.',
      );
    }
  }

  static Future<GoodsReceived> createGoodsReceived(
    GoodsReceived goodsReceived,
  ) async {
    try {
      final response = await ApiService.dio.post(
        _endpoint,
        data: goodsReceived.toJson(),
      );

      return GoodsReceived.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw Exception(
        e.response?.data.toString() ??
            'Failed to save delivery.',
      );
    }
  }
}