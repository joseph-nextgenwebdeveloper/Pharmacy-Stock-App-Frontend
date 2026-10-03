import 'dart:io';

import 'package:dio/dio.dart';

import '../models/medicine.dart';
import 'api_service.dart';

class InventoryService {
  static const String _endpoint = '/inventory/medicines/';

  static Future<List<Medicine>> getMedicines() async {
    try {
      // Follows pagination so every medicine is returned, not just the
      // first 20 (the backend's default page size).
      final items = await ApiService.getAllPages(_endpoint);
      return items.map(Medicine.fromJson).toList();
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['detail'] ??
            'Failed to load medicines.',
      );
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
      throw Exception(
        e.response?.data?['detail'] ??
            'Failed to load medicine.',
      );
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
      throw Exception(
        e.response?.data.toString() ??
            'Failed to create medicine.',
      );
    }
  }

  static Future<Medicine> updateMedicine(
    int id,
    Medicine medicine,
  ) async {
    try {
      final response = await ApiService.dio.put(
        '$_endpoint$id/',
        data: medicine.toJson(),
      );

      return Medicine.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw Exception(
        e.response?.data.toString() ??
            'Failed to update medicine.',
      );
    }
  }
}