import 'package:flutter/material.dart';
import 'api_service.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;
  DateTime? _lastFetched;

  final ApiService _apiService = ApiService();

  void syncFromNotifications(List<dynamic> items) {
    final count = items.where((item) {
      if (item is Map) {
        final isRead = item['is_read'] == true ||
            item['read'] == true ||
            item['read_at'] != null;
        return !isRead;
      }
      return false;
    }).length;

    _unreadCount = count < 0 ? 0 : count;
    _lastFetched = DateTime.now();
    notifyListeners();
  }

  Future<void> fetchUnreadCount({bool force = false}) async {
    if (!force &&
        _lastFetched != null &&
        DateTime.now().difference(_lastFetched!).inSeconds < 10) {
      return;
    }

    try {
      final res = await _apiService.get('/notifications/unread-count');
      if (res.statusCode == 200) {
        final unread = (res.data is Map && res.data['unread'] != null)
            ? int.tryParse(res.data['unread'].toString()) ?? 0
            : 0;
        setUnreadCount(unread);
      }
    } catch (e) {
      debugPrint('Error fetching unread count: $e');
    }
  }

  void setUnreadCount(int count) {
    _unreadCount = count < 0 ? 0 : count;
    _lastFetched = DateTime.now();
    notifyListeners();
  }

  void decrementCount() {
    if (_unreadCount > 0) {
      _unreadCount--;
      _lastFetched = DateTime.now();
      notifyListeners();
    }
  }

  void clearCount() {
    _unreadCount = 0;
    _lastFetched = DateTime.now();
    notifyListeners();
  }
}
