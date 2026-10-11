import 'dart:io';

import 'package:dio/dio.dart';

import '../models/medicine.dart';
import 'api_service.dart';
import 'cache_service.dart';

class InventoryService {
  static const String _endpoint = '/inventory/medicines/';
  static const String cacheKey = 'medicines';

  /// What was downloaded last time (empty if nothing yet).
  static Future<List<Medicine>> getCachedMedicines() async {
    final items = await CacheService.readList(cacheKey);
    return items.map(Medicine.fromJson).toList();
  }

  static Future<List<Medicine>> getMedicines() async {
    try {
      // Follows pagination so every medicine is returned.
      final items = await ApiService.getAllPages(_endpoint);
      await CacheService.write(cacheKey, items);
      return items.map(Medicine.fromJson).toList();
    } on DioException catch (e) {
      throw ApiService.exceptionFor(e, 'Failed to load medicines.');
    }
  }

  static Future<Medicine> getMedicine(
    int id,
  ) async {
    try {
      final response = await ApiService.dio.get(
        '$_endpoint$id/',
      );

      return Medicine.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiService.exceptionFor(e, 'Failed to load medicine.');
    }
  }

  static Future<Medicine> createMedicine(
    Medicine medicine, {
    String? imagePath,
  }) async {
    try {
      final response = await ApiService.dio.post(
        _endpoint,
        data: imagePath == null
            ? medicine.toJson()
            : FormData.fromMap({
                ...medicine.toJson(),
                'image': await MultipartFile.fromFile(
                  imagePath,
                  filename: imagePath.split(Platform.pathSeparator).last,
                ),
              }),
      );

      return Medicine.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiService.exceptionFor(e, 'Failed to create medicine.');
    }
  }

  static Future<Medicine> updateMedicine(
    int id,
    Medicine medicine, {
    String? imagePath,
  }) async {
    try {
      final response = await ApiService.dio.put(
        '$_endpoint$id/',
        data: imagePath == null
            ? medicine.toJson()
            : FormData.fromMap({
                ...medicine.toJson(),
                'image': await MultipartFile.fromFile(
                  imagePath,
                  filename: imagePath.split(Platform.pathSeparator).last,
                ),
              }),
      );

      return Medicine.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiService.exceptionFor(e, 'Failed to update medicine.');
    }
  }
}
