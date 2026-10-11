import 'package:flutter/foundation.dart';

import '../models/activity_log.dart';
import '../services/user_service.dart';

/// "Who did what": my own activity, and (for admins / store managers) the
/// whole team's.
class ActivityProvider extends ChangeNotifier {
  List<ActivityLog> _mine = [];
  List<ActivityLog> _team = [];
  List<StaffMember> _staff = [];
  ActivitySummary _summary = const ActivitySummary();

  bool _isLoading = false;
  bool _hydrated = false;
  String? _error;

  List<ActivityLog> get mine => List.unmodifiable(_mine);
  List<ActivityLog> get team => List.unmodifiable(_team);
  List<StaffMember> get staff => List.unmodifiable(_staff);
  ActivitySummary get summary => _summary;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadMine() async {
    if (!_hydrated) {
      _hydrated = true;
      final cached = await ActivityService.getCached();
      final cachedSummary = await ActivityService.getCachedSummary();
      if (_mine.isEmpty && cached.isNotEmpty) _mine = cached;
      if (cachedSummary != null) _summary = cachedSummary;
      notifyListeners();
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        ActivityService.getActivity(scope: 'mine'),
        ActivityService.getSummary(),
      ]);
      _mine = results[0] as List<ActivityLog>;
      _summary = results[1] as ActivitySummary;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Team-wide feed (admins / store managers). [userId] narrows to one person.
  Future<void> loadTeam({int? userId, String? action, String? date}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_staff.isEmpty) {
        try {
          _staff = await ActivityService.getStaff();
        } catch (_) {/* filter chips just won't show */}
      }
      _team = await ActivityService.getActivity(
        scope: 'all',
        userId: userId,
        action: action,
        date: date,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void reset() {
    _mine = [];
    _team = [];
    _staff = [];
    _summary = const ActivitySummary();
    _hydrated = false;
    notifyListeners();
  }
}
