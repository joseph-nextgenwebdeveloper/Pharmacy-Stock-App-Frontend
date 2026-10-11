import 'package:dio/dio.dart';

import '../models/batch.dart';
import 'api_service.dart';
import 'cache_service.dart';

class BatchService {
  static const String _endpoint = '/inventory/batches/';
  static const String cacheKey = 'batches';

  static Future<List<Batch>> getCachedBatches() async {
    final items = await CacheService.readList(cacheKey);
    return items.map(Batch.fromJson).toList();
  }

  static Future<List<Batch>> getBatches() async {
    try {
      final items = await ApiService.getAllPages(_endpoint);
      await CacheService.write(cacheKey, items);
      return items.map(Batch.fromJson).toList();
    } on DioException catch (e) {
      throw ApiService.exceptionFor(e, 'Failed to load batches.');
    }
  }

  static Future<Batch> getBatch(
    int id,
  ) async {
    try {
      final response = await ApiService.dio.get(
        '$_endpoint$id/',
      );

      return Batch.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiService.exceptionFor(e, 'Failed to load batch.');
    }
  }

  static Future<Batch> createBatch(
    Batch batch,
  ) async {
    try {
      final response = await ApiService.dio.post(
        _endpoint,
        data: batch.toJson(),
      );

      return Batch.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiService.exceptionFor(e, 'Failed to create batch.');
    }
  }

  static Future<Batch> updateBatch(
    Batch batch,
  ) async {
    try {
      final response = await ApiService.dio.put(
        '$_endpoint${batch.id}/',
        data: batch.toJson(),
      );

      return Batch.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiService.exceptionFor(e, 'Failed to update batch.');
    }
  }

  static Future<void> deleteBatch(
    int id,
  ) async {
    try {
      await ApiService.dio.delete(
        '$_endpoint$id/',
      );
    } on DioException catch (e) {
      throw ApiService.exceptionFor(e, 'Failed to delete batch.');
    }
  }
}
