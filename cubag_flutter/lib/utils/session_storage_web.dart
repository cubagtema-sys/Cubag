// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'session_storage.dart';

SessionStorage getSessionStorage() => WebSessionStorage();

class WebSessionStorage implements SessionStorage {
  @override
  Future<void> setString(String key, String value) async {
    html.window.sessionStorage[key] = value;
  }

  @override
  Future<String?> getString(String key) async {
    return html.window.sessionStorage[key];
  }

  @override
  Future<void> setStringList(String key, List<String> value) async {
    html.window.sessionStorage[key] = jsonEncode(value);
  }

  @override
  Future<List<String>?> getStringList(String key) async {
    final val = html.window.sessionStorage[key];
    if (val == null) return null;
    try {
      final decoded = jsonDecode(val);
      if (decoded is List) {
        return List<String>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> remove(String key) async {
    html.window.sessionStorage.remove(key);
  }

  @override
  Future<void> clear() async {
    html.window.sessionStorage.clear();
  }
}
