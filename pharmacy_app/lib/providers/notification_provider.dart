import 'package:flutter/foundation.dart';

import '../models/notification.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  List<AppNotification> _notifications = [];
  bool _isLoading = false;
  bool _hydrated = false;
  String? _error;

  List<AppNotification> get notifications =>
      List.unmodifiable(_notifications);

  bool get isLoading => _isLoading;
  String? get error => _error;

  int get unreadCount =>
      _notifications.where((notification) => !notification.isRead).length;

  Future<void> loadNotifications() async {
    if (!_hydrated) {
      _hydrated = true;
      final cached = await NotificationService.getCachedNotifications();
      if (_notifications.isEmpty && cached.isNotEmpty) {
        _notifications = cached;
        notifyListeners();
      }
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _notifications = await NotificationService.getNotifications();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await loadNotifications();
  }

  Future<void> markAsRead(int id) async {
    try {
      final updatedNotification =
          await NotificationService.markAsRead(id);

      final index = _notifications.indexWhere(
        (notification) => notification.id == id,
      );

      if (index != -1) {
        _notifications[index] = updatedNotification;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await NotificationService.markAllAsRead();
      _notifications =
          _notifications.map((n) => n.copyWith(isRead: true)).toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void reset() {
    _notifications = [];
    _hydrated = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}