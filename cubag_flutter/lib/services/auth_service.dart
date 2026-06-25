import 'package:flutter/material.dart';
import '../utils/session_storage.dart';
import 'api_service.dart';
import 'socket_service.dart';
import 'push_notification_service.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final ApiService _apiService = ApiService();
  final SocketService _socketService = SocketService();
  final PushNotificationService _pushNotificationService = PushNotificationService();

  bool _isAuthenticated = false;
  String? _userRole;
  String? _userPhotoUrl;
  String? _userName;
  String? _userEmail;
  List<String> _permissions = [];
  bool _notificationsInitialized = false;

  bool get isAuthenticated => _isAuthenticated;
  String? get userRole => _userRole;
  String? get userPhotoUrl => _userPhotoUrl;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  List<String> get permissions => _permissions;

  bool hasPermission(String key) {
    if (_userRole == 'admin') return true;
    return _permissions.contains(key);
  }

  Future<void> updatePhoto(String url) async {
    _userPhotoUrl = url;
    await SessionStorage.instance.setString('cubag_photo', url);
    notifyListeners();
  }

  Future<void> checkAuthStatus() async {
    final token = await SessionStorage.instance.getString('cubag_token');
    _userRole = await SessionStorage.instance.getString('cubag_role');
    _userPhotoUrl = await SessionStorage.instance.getString('cubag_photo');
    _userName = await SessionStorage.instance.getString('cubag_name');
    _userEmail = await SessionStorage.instance.getString('cubag_email');
    _permissions = await SessionStorage.instance.getStringList('cubag_permissions') ?? [];

    if (token != null) {
      _isAuthenticated = true;
      _initServices();
    }
    notifyListeners();
  }

  void _initServices() {
    _socketService.initSocket();

    // Guard against multiple initializations
    if (!_notificationsInitialized) {
      _pushNotificationService.initialize();
      _notificationsInitialized = true;
    }
  }

  void _disposeServices() {
    _socketService.dispose();
    _notificationsInitialized = false;
  }

  Future<void> _fetchPermissions() async {
    try {
      final res = await _apiService.get('/sub-admins/me/permissions');
      if (res.statusCode == 200) {
        final perms = List<String>.from(res.data['permissions'] ?? []);
        _permissions = perms;
        await SessionStorage.instance.setStringList('cubag_permissions', perms);
      }
    } catch (_) {}
  }

  Future<String?> login(String email, String password) async {
    try {
      final response = await _apiService.post('/auth/login', data: {
        'identifier': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        final token = data['token'];
        final user = data['user'] as Map<String, dynamic>? ?? {};
        final role = user['role']?.toString() ?? 'member';

        await SessionStorage.instance.setString('cubag_token', token);
        await SessionStorage.instance.setString('cubag_role', role);
        if (user['id'] != null) await SessionStorage.instance.setString('cubag_id', user['id'].toString());
        if (user['name'] != null) await SessionStorage.instance.setString('cubag_name', user['name'].toString());
        if (user['email'] != null) await SessionStorage.instance.setString('cubag_email', user['email'].toString());
        if (user['profile_photo'] != null) await SessionStorage.instance.setString('cubag_photo', user['profile_photo'].toString());

        _isAuthenticated = true;
        _userRole = role;
        _userPhotoUrl = user['profile_photo']?.toString();
        _userName = user['name']?.toString();
        _userEmail = user['email']?.toString();

        _initServices();

        if (role == 'admin' || role == 'sub_admin') {
          _fetchPermissions().then((_) {
            notifyListeners();
          });
        }

        notifyListeners();
        return null;
      }
      return 'Incorrect email or password.';
    } catch (e) {
      final err = e.toString().toLowerCase();
      if (err.contains('timeout') || err.contains('connecting')) {
        return 'Server is waking up. Please try again in 5 seconds.';
      }
      return 'Incorrect email or password.';
    }
  }

  Future<void> logout() async {
    await SessionStorage.instance.clear();
    _isAuthenticated = false;
    _userRole = null;
    _userPhotoUrl = null;
    _userName = null;
    _userEmail = null;
    _permissions = [];
    _disposeServices();
    notifyListeners();
  }
}
