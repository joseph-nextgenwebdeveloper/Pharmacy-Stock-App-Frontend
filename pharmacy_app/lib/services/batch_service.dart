import 'package:dio/dio.dart';

import '../models/batch.dart';
import 'api_service.dart';

class BatchService {
  static const String _endpoint = '/inventory/batches/';

  static Future<List<Batch>> getBatches() async {
    try {
      final items = await ApiService.getAllPages(_endpoint);
      return items.map(Batch.fromJson).toList();
    } on DioException catch (e) {
      final data = e.response?.data;

      if (data is Map<String, dynamic>) {
        throw Exception(
          data['detail'] ??
              data.toString(),
        );
      }

      throw Exception(
        'Failed to load batches.',
      );
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
      final data = e.response?.data;

      if (data is Map<String, dynamic>) {
        throw Exception(
          data['detail'] ??
              data.toString(),
        );
      }

      throw Exception(
        'Failed to load batch.',
      );
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
      final data = e.response?.data;

      if (data is Map<String, dynamic>) {
        throw Exception(
          data.toString(),
        );
      }

      throw Exception(
        'Failed to create batch.',
      );
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
      final data = e.response?.data;

      if (data is Map<String, dynamic>) {
        throw Exception(
          data.toString(),
        );
      }

      throw Exception(
        'Failed to update batch.',
      );
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
      final data = e.response?.data;

      if (data is Map<String, dynamic>) {
        throw Exception(
          data.toString(),
        );
      }

      throw Exception(
        'Failed to delete batch.',
      );
    }
  }
}