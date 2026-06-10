import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/router.dart';
import 'auth_service.dart';

dynamic _decodeJsonString(String data) => jsonDecode(data);
String _encodeJson(dynamic data) => jsonEncode(data);

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late Dio _dio;

  // Set dynamically via --dart-define=API_URL=https://your-api-url.com
  static const _base = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://cubag-backend.onrender.com/api',
  );

  static String get _normalizedBase {
    String url = _base;
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
    debugPrint('[ApiService] Initializing Singleton Base URL: $_normalizedBase');
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

    // Optimize JSON parsing
    _dio.transformer = BackgroundTransformer();
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
    try { return (await _dio.get(_path(path))).data; } catch (_) { return null; }
  }

  /// Instantly fires [onData] with cached local data (if any), 
  /// then fetches fresh data from the API in the background, updates the cache, 
  /// and fires [onData] again with the fresh data.
  Future<void> fetchDataWithCache(String path, Function(dynamic data, bool isCached) onData) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'cache_v1_${_path(path)}';

    // 1. Immediately return cached data if available
    final cachedStr = prefs.getString(cacheKey);
    if (cachedStr != null) {
      try {
        final cachedJson = await compute(jsonDecode, cachedStr);
        onData(cachedJson, true);
      } catch (e) {
        debugPrint('[Cache Error] Failed to decode cache for $path: $e');
      }
    }

    // 2. Fetch fresh data in the background
    try {
      final res = await _dio.get(_path(path));
      dynamic freshData = res.data;
      if (freshData is String) {
        try { freshData = _decodeJsonString(freshData); } catch (_) {}
      }
      
      // Update cache asynchronously
      if (freshData != null) {
        prefs.setString(cacheKey, _encodeJson(freshData));
      }
      
      // Always call onData so pages can exit their loading state
      onData(freshData, false);
    } catch (e) {
      debugPrint('[API Error] Background fetch failed for $path: $e');
      // Always call onData even on error so loading spinners don't freeze
      onData(null, false);
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
    try { return (await _dio.post(_path(path), data: data)).data; } catch (_) { return null; }
  }

  Future<dynamic> putData(String path, dynamic data) async {
    try { return (await _dio.put(_path(path), data: data)).data; } catch (_) { return null; }
  }

  Future<dynamic> patchData(String path, dynamic data) async {
    try { return (await _dio.patch(_path(path), data: data)).data; } catch (_) { return null; }
  }

  Future<dynamic> deleteData(String path) async {
    try { return (await _dio.delete(_path(path))).data; } catch (_) { return null; }
  }

  static List<dynamic> ensureList(dynamic data) {
    if (data == null) return [];
    if (data is String) {
      try { data = jsonDecode(data); } catch (_) { return []; }
    }
    if (data is List) return data;
    if (data is Map) {
      if (data.containsKey('data') && data['data'] is List) {
        return data['data'] as List<dynamic>;
      }
      if (data.containsKey('items') && data['items'] is List) {
        return data['items'] as List<dynamic>;
      }
      for (var value in data.values) {
        if (value is List) return value as List<dynamic>;
      }
    }
    return [];
  }
}
