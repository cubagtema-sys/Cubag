import 'package:flutter/material.dart';
import 'api_service.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  final ApiService _apiService = ApiService();

  Future<void> fetchUnreadCount() async {
    try {
      final res = await _apiService.get('/announcements');
      if (res.statusCode == 200) {
        final data = ApiService.ensureList(res.data);
        _unreadCount = data.where((a) => a['is_read'] != true).length;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching unread count: $e');
    }
  }

  void decrementCount() {
    if (_unreadCount > 0) {
      _unreadCount--;
      notifyListeners();
    }
  }

  void clearCount() {
    _unreadCount = 0;
    notifyListeners();
  }
}
