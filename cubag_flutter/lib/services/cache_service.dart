import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// Simple offline cache for announcements, schedules, and public materials.
/// Caches API responses in SharedPreferences with TTL.
/// Falls back to cached data when the network request fails.
class CacheService {
  static const _prefix = 'cache_';
  static const _ttlMinutes = 30; // Cache expires after 30 minutes

  final ApiService _api = ApiService();

  /// Fetch with cache-first strategy.
  /// Returns cached data immediately if available, then refreshes in background.
  /// If network fails, returns cached data (or null).
  Future<List<dynamic>> fetchCached(String endpoint, {int ttl = _ttlMinutes}) async {
    final key = '$_prefix${endpoint.replaceAll('/', '_')}';
    final prefs = await SharedPreferences.getInstance();

    // Try cache first
    List<dynamic>? cached;
    final raw = prefs.getString(key);
    final tsKey = '${key}_ts';
    if (raw != null) {
      try {
        cached = jsonDecode(raw) as List<dynamic>;
      } catch (_) {}
    }

    // Check if cache is still fresh
    final lastFetch = prefs.getInt(tsKey) ?? 0;
    final age = DateTime.now().millisecondsSinceEpoch - lastFetch;
    final isFresh = age < ttl * 60 * 1000;

    if (cached != null && isFresh) {
      debugPrint('[Cache] HIT (fresh) for $endpoint');
      return cached;
    }

    // Try network
    try {
      final res = await _api.get(endpoint);
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data is List ? res.data as List<dynamic> : [res.data];
        // Save to cache
        await prefs.setString(key, jsonEncode(data));
        await prefs.setInt(tsKey, DateTime.now().millisecondsSinceEpoch);
        debugPrint('[Cache] REFRESHED for $endpoint');
        return data;
      }
    } catch (e) {
      debugPrint('[Cache] Network failed for $endpoint: $e');
    }

    // Fallback to stale cache
    if (cached != null) {
      debugPrint('[Cache] HIT (stale fallback) for $endpoint');
      return cached;
    }

    return [];
  }

  /// Fetch a map-shaped response with cache.
  Future<Map<String, dynamic>> fetchCachedMap(String endpoint, {int ttl = _ttlMinutes}) async {
    final key = '$_prefix${endpoint.replaceAll('/', '_')}';
    final prefs = await SharedPreferences.getInstance();

    Map<String, dynamic>? cached;
    final raw = prefs.getString(key);
    final tsKey = '${key}_ts';
    if (raw != null) {
      try {
        cached = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {}
    }

    final lastFetch = prefs.getInt(tsKey) ?? 0;
    final age = DateTime.now().millisecondsSinceEpoch - lastFetch;
    final isFresh = age < ttl * 60 * 1000;

    if (cached != null && isFresh) return cached;

    try {
      final res = await _api.get(endpoint);
      if (res.statusCode == 200 && res.data is Map) {
        final data = res.data as Map<String, dynamic>;
        await prefs.setString(key, jsonEncode(data));
        await prefs.setInt(tsKey, DateTime.now().millisecondsSinceEpoch);
        return data;
      }
    } catch (_) {}

    return cached ?? {};
  }

  /// Clear all cached data.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
    for (final k in keys) {
      await prefs.remove(k);
    }
    debugPrint('[Cache] All caches cleared');
  }

  /// Clear a specific endpoint cache.
  Future<void> invalidate(String endpoint) async {
    final key = '$_prefix${endpoint.replaceAll('/', '_')}';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    await prefs.remove('${key}_ts');
  }
}
