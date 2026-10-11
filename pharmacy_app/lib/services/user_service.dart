import 'dart:io';

import 'package:dio/dio.dart';

import '../models/activity_log.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'cache_service.dart';

class UserService {
  static const String _endpoint = '/accounts/profile/';
  static const String profileCacheKey = 'profile';

  static Future<User> getProfile() async {
    try {
      final response = await ApiService.dio.get(
        _endpoint,
      );

      final data = response.data as Map<String, dynamic>;
      await CacheService.write(profileCacheKey, data);
      return User.fromJson(data);
    } on DioException catch (e) {
      throw ApiService.exceptionFor(e, 'Failed to load profile.');
    }
  }

  /// Saves name / phone and optionally a new profile photo
  /// ([avatarPath]) or removes the photo ([removeAvatar]).
  static Future<User> updateProfile({
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? avatarPath,
    bool removeAvatar = false,
  }) async {
    try {
      final fields = <String, dynamic>{
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
        if (phoneNumber != null) 'phone_number': phoneNumber,
        if (removeAvatar) 'remove_avatar': 'true',
      };

      final body = FormData.fromMap({
        ...fields,
        if (avatarPath != null)
          'avatar': await MultipartFile.fromFile(
            avatarPath,
            filename: avatarPath.split(Platform.pathSeparator).last,
          ),
      });

      final response = await ApiService.dio.patch(_endpoint, data: body);
      final data = response.data as Map<String, dynamic>;
      await CacheService.write(profileCacheKey, data);
      return User.fromJson(data);
    } on DioException catch (e) {
      throw ApiService.exceptionFor(e, 'Failed to update profile.');
    }
  }
}

/// "Who did what": the activity feed, the headline numbers and the staff list.
class ActivityService {
  static const String _feed = '/accounts/activity/';

  static String _key(String scope, int? userId) =>
      'activity_${scope}_${userId ?? 'x'}';

  static Future<List<ActivityLog>> getCached({
    String scope = 'mine',
    int? userId,
  }) async {
    final items = await CacheService.readList(_key(scope, userId));
    return items.map(ActivityLog.fromJson).toList();
  }

  /// [scope] "mine" = my own actions; "all" = the whole team (admins and
  /// store managers only). [userId] narrows "all" to one person.
  static Future<List<ActivityLog>> getActivity({
    String scope = 'mine',
    int? userId,
    String? action,
    String? date,
    String? search,
    bool hideSessions = false,
    int limit = 300,
  }) async {
    try {
      final params = <String, dynamic>{
        'page_size': limit,
        if (scope == 'all' && userId == null) 'scope': 'all',
        if (userId != null) 'user': userId,
        if (action != null && action.isNotEmpty) 'action': action,
        if (date != null && date.isNotEmpty) 'date': date,
        if (search != null && search.isNotEmpty) 'search': search,
        if (hideSessions) 'hide_sessions': '1',
      };

      final response = await ApiService.dio.get(_feed, queryParameters: params);
      final data = response.data;

      List raw = const [];
      if (data is List) {
        raw = data;
      } else if (data is Map<String, dynamic> && data['results'] is List) {
        raw = data['results'] as List;
      }

      final items = raw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();

      // Only the plain, unfiltered feeds are cached for offline use.
      if (action == null && date == null && search == null) {
        await CacheService.write(_key(scope, userId), items);
      }
      return items.map(ActivityLog.fromJson).toList();
    } on DioException catch (e) {
      throw ApiService.exceptionFor(e, 'Failed to load activity.');
    }
  }

  static Future<ActivitySummary?> getCachedSummary() async {
    final map = await CacheService.readMap('activity_summary');
    return map == null ? null : ActivitySummary.fromJson(map);
  }

  static Future<ActivitySummary> getSummary() async {
    try {
      final response = await ApiService.dio.get('${_feed}summary/');
      final data = response.data as Map<String, dynamic>;
      await CacheService.write('activity_summary', data);
      return ActivitySummary.fromJson(data);
    } on DioException catch (e) {
      throw ApiService.exceptionFor(e, 'Failed to load your activity numbers.');
    }
  }

  static Future<List<StaffMember>> getStaff() async {
    try {
      final response = await ApiService.dio.get('/accounts/staff/');
      final data = response.data;
      final raw = data is List
          ? data
          : (data is Map<String, dynamic> && data['results'] is List
              ? data['results'] as List
              : const []);

      return raw
          .whereType<Map>()
          .map((m) => StaffMember.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } on DioException catch (e) {
      throw ApiService.exceptionFor(e, 'Failed to load staff.');
    }
  }
}
