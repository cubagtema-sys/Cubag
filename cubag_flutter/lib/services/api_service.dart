import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/router.dart';
import 'auth_service.dart';

class ApiService {
  late Dio _dio;

  // Set dynamically via --dart-define=API_URL=https://your-api-url.com
  static const _base = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://127.0.0.1:5000/api',
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

  /// Expose for pages that need to construct file URLs
  String get baseUrl => _normalizedBase;

  ApiService() {
    debugPrint('[ApiService] Base URL: $_normalizedBase');
    _dio = Dio(BaseOptions(
      baseUrl: _normalizedBase,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
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
          // Clean up auth state and notify UI
          await AuthService().logout();
          
          // Redirect to login page
          appRouter.go('/login');
        }
        return handler.next(error);
      },
    ));
  }

  String _path(String p) => p.startsWith('/') ? p.substring(1) : p;

  // ──────────────────────────────────────────────────────────────────────────
  // Legacy-compatible methods (return full Dio Response for older pages)
  // ──────────────────────────────────────────────────────────────────────────

  /// Authenticated GET — returns full Dio Response (use .statusCode, .data).
  Future<Response<dynamic>> get(String path, {Options? options}) =>
      _dio.get(_path(path), options: options);

  /// Options for receiving raw text responses (e.g. CSV exports).
  static Options rawResponseOptions() => Options(responseType: ResponseType.plain);

  /// Authenticated POST — named data: param for compat. Returns full Dio Response.
  Future<Response<dynamic>> post(String path, {dynamic data}) =>
      _dio.post(_path(path), data: data);

  /// Authenticated PUT — named data: param for compat. Returns full Dio Response.
  Future<Response<dynamic>> put(String path, {dynamic data}) =>
      _dio.put(_path(path), data: data);

  /// Authenticated PATCH — named data: param for compat. Returns full Dio Response.
  Future<Response<dynamic>> patch(String path, {dynamic data}) =>
      _dio.patch(_path(path), data: data);

  /// Authenticated DELETE — returns full Dio Response.
  Future<Response<dynamic>> delete(String path) => _dio.delete(_path(path));

  /// Authenticated multipart POST.
  Future<Response<dynamic>> upload(String path, FormData data) =>
      _dio.post(_path(path), data: data, options: Options(contentType: 'multipart/form-data'));

  // ──────────────────────────────────────────────────────────────────────────
  // Convenience helpers — return body directly, null on error
  // ──────────────────────────────────────────────────────────────────────────

  /// Authenticated GET — returns body (List, Map, etc.) or null.
  Future<dynamic> fetchData(String path) async {
    try { return (await _dio.get(_path(path))).data; } catch (_) { return null; }
  }

  /// Public (no-auth) GET — returns body or null.
  /// Uses a bare Dio instance with no auth interceptor to avoid token injection.
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

  /// Authenticated POST — returns body or null.
  Future<dynamic> postData(String path, dynamic data) async {
    try { return (await _dio.post(_path(path), data: data)).data; } catch (_) { return null; }
  }

  /// Authenticated PUT — returns body or null.
  Future<dynamic> putData(String path, dynamic data) async {
    try { return (await _dio.put(_path(path), data: data)).data; } catch (_) { return null; }
  }

  /// Authenticated PATCH — returns body or null.
  Future<dynamic> patchData(String path, dynamic data) async {
    try { return (await _dio.patch(_path(path), data: data)).data; } catch (_) { return null; }
  }

  /// Authenticated DELETE — returns body or null.
  Future<dynamic> deleteData(String path) async {
    try { return (await _dio.delete(_path(path))).data; } catch (_) { return null; }
  }
}
