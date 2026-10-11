import 'package:dio/dio.dart';

import '../models/goods_received.dart';
import 'api_service.dart';
import 'cache_service.dart';

class GoodsReceivedService {
  static const String _endpoint = '/purchases/goods-received/';
  static const String cacheKey = 'goods_received';

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

  static Future<List<GoodsReceived>> getCachedGoodsReceived() async {
    final items = await CacheService.readList(cacheKey);
    return items.map(GoodsReceived.fromJson).toList();
  }

  static Future<List<GoodsReceived>> getGoodsReceived() async {
    try {
      final response = await ApiService.dio.get(_endpoint);
      final items = _rows(response.data);
      await CacheService.write(
        cacheKey,
        items.length > 200 ? items.sublist(0, 200) : items,
      );
      return items.map(GoodsReceived.fromJson).toList();
    } on DioException catch (e) {
      throw ApiService.exceptionFor(e, 'Failed to load deliveries.');
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
      throw ApiService.exceptionFor(e, 'Failed to load delivery.');
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
      throw ApiService.exceptionFor(e, 'Failed to save delivery.');
    }
  }
}
