import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'socket_service.dart';
import 'push_notification_service.dart';

class AuthService extends ChangeNotifier {
  static AuthService? _instance;
  static AuthService get instance {
    _instance ??= AuthService._internal();
    return _instance!;
  }

  factory AuthService() => instance;
  AuthService._internal();

  final ApiService _apiService = ApiService();
  final SocketService _socketService = SocketService();
  final PushNotificationService _pushNotificationService = PushNotificationService();

  bool _isAuthenticated = false;
  String? _userRole;
  String? _userPhotoUrl;
  List<String> _permissions = [];

  bool get isAuthenticated => _isAuthenticated;
  String? get userRole => _userRole;
  String? get userPhotoUrl => _userPhotoUrl;

  /// Permission keys granted to this user (sub-admins only; admins always pass).
  List<String> get permissions => _permissions;

  /// Returns true if this user can access a given admin module.
  bool hasPermission(String key) {
    if (_userRole == 'admin') return true;
    return _permissions.contains(key);
  }

  Future<void> updatePhoto(String url) async {
    _userPhotoUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cubag_photo', url);
    notifyListeners();
  }

  Future<void> checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('cubag_token');
    _userRole = prefs.getString('cubag_role');
    _userPhotoUrl = prefs.getString('cubag_photo');
    _permissions = prefs.getStringList('cubag_permissions') ?? [];

    if (token != null) {
      _isAuthenticated = true;
      _initServices();
    }
    notifyListeners();
  }

  void _initServices() {
    _socketService.initSocket();
    _pushNotificationService.initialize();
  }

  void _disposeServices() {
    _socketService.dispose();
  }

  Future<void> _fetchPermissions() async {
    try {
      final res = await _apiService.get('/sub-admins/me/permissions');
      if (res.statusCode == 200) {
        final perms = List<String>.from(res.data['permissions'] ?? []);
        _permissions = perms;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('cubag_permissions', perms);
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

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cubag_token', token);
        await prefs.setString('cubag_role', role);
        if (user['id'] != null) await prefs.setString('cubag_id', user['id'].toString());
        if (user['name'] != null) await prefs.setString('cubag_name', user['name'].toString());
        if (user['email'] != null) await prefs.setString('cubag_email', user['email'].toString());

        _isAuthenticated = true;
        _userRole = role;
        _initServices();

        if (role == 'admin' || role == 'sub_admin') {
          await _fetchPermissions();
        }

        notifyListeners();
        return null;
      }
      return 'Login failed';
    } catch (e) {
      return 'Connection error or Invalid credentials';
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cubag_token');
    await prefs.remove('cubag_role');
    await prefs.remove('cubag_id');
    await prefs.remove('cubag_name');
    await prefs.remove('cubag_email');
    await prefs.remove('cubag_photo');
    await prefs.remove('cubag_permissions');
    _isAuthenticated = false;
    _userRole = null;
    _userPhotoUrl = null;
    _permissions = [];
    _disposeServices();
    notifyListeners();
  }
}
