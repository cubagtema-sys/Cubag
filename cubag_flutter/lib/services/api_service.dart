import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/router.dart';
import 'auth_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late Dio _dio;

  static const _base = 'http://localhost:5001/api';

  static String get _normalizedBase {
    String url = _base.trim();
    if (!url.endsWith('/api') && !url.endsWith('/api/')) {
      if (url.endsWith('/')) {
        url = '${url}api';
      } else {
        url = '$url/api';
      }
    }
    if (!url.endsWith('/')) {
      url = '$url/';
    }
    return url;
  }

  static String get baseUrl => _normalizedBase;
  String get instanceBaseUrl => _normalizedBase;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: _normalizedBase,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('cubag_token');
        if (token != null && !options.headers.containsKey('Authorization')) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          await AuthService().logout();
          appRouter.go('/login');
        }
        return handler.next(error);
      },
    ));
  }

  String _path(String p) => p.startsWith('/') ? p.substring(1) : p;

  Future<Response<dynamic>> get(String path, {Options? options}) =>
      _dio.get(_path(path), options: options);

  static Options rawResponseOptions() => Options(responseType: ResponseType.plain);

  Future<Response<dynamic>> post(String path, {dynamic data}) =>
      _dio.post(_path(path), data: data);

  Future<Response<dynamic>> put(String path, {dynamic data}) =>
      _dio.put(_path(path), data: data);

  Future<Response<dynamic>> patch(String path, {dynamic data}) =>
      _dio.patch(_path(path), data: data);

  Future<Response<dynamic>> delete(String path) => _dio.delete(_path(path));

  Future<Response<dynamic>> upload(String path, FormData data) =>
      _dio.post(_path(path), data: data, options: Options(contentType: 'multipart/form-data'));

  Future<dynamic> fetchData(String path) async {
    try {
      final res = await _dio.get(_path(path));
      return res.data;
    } catch (_) {
      return null;
    }
  }

  Future<void> fetchDataWithCache(String path, Function(dynamic data, bool isCached, {bool hasError}) onData) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'cache_v1_${_path(path)}';

    final cachedStr = prefs.getString(cacheKey);
    if (cachedStr != null) {
      try {
        final decoded = jsonDecode(cachedStr);
        onData(decoded, true, hasError: false);
      } catch (_) {}
    }

    try {
      final res = await _dio.get(_path(path));
      final freshData = res.data;
      if (freshData != null) {
        prefs.setString(cacheKey, jsonEncode(freshData));
      }
      onData(freshData, false, hasError: false);
    } catch (e) {
      debugPrint('[API Error] $path: $e');
      onData(null, false, hasError: true);
    }
  }

  Future<dynamic> getPublic(String path) async {
    try {
      final bare = Dio(BaseOptions(
        baseUrl: _normalizedBase,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ));
      final res = await bare.get(_path(path));
      return res.data;
    } catch (e) {
      debugPrint('getPublic error for path $path: $e');
      return null;
    }
  }

  Future<dynamic> postData(String path, dynamic data) async {
    try {
      final res = await _dio.post(_path(path), data: data);
      return res.data;
    } catch (_) {
      return null;
    }
  }

  Future<dynamic> putData(String path, dynamic data) async {
    try {
      final res = await _dio.put(_path(path), data: data);
      return res.data;
    } catch (_) {
      return null;
    }
  }

  Future<dynamic> patchData(String path, dynamic data) async {
    try {
      final res = await _dio.patch(_path(path), data: data);
      return res.data;
    } catch (_) {
      return null;
    }
  }

  Future<dynamic> deleteData(String path) async {
    try {
      final res = await _dio.delete(_path(path));
      return res.data;
    } catch (_) {
      return null;
    }
  }

  static List<dynamic> ensureList(dynamic data) {
    if (data == null) return [];
    if (data is List) return data;
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is List) return decoded;
        if (decoded is Map) return _findListInMap(decoded);
      } catch (_) {}
    }
    if (data is Map) {
      return _findListInMap(data);
    }
    return [];
  }

  static List<dynamic> _findListInMap(Map data) {
    if (data.containsKey('data') && data['data'] is List) return data['data'];
    if (data.containsKey('items') && data['items'] is List) return data['items'];
    if (data.containsKey('results') && data['results'] is List) return data['results'];
    for (var v in data.values) {
      if (v is List) return v;
    }
    return [];
  }
}
