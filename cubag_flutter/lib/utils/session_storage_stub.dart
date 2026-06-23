import 'package:shared_preferences/shared_preferences.dart';
import 'session_storage.dart';

SessionStorage getSessionStorage() => StubSessionStorage();

class StubSessionStorage implements SessionStorage {
  @override
  Future<void> setString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  @override
  Future<String?> getString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  @override
  Future<void> setStringList(String key, List<String> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, value);
  }

  @override
  Future<List<String>?> getStringList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key);
  }

  @override
  Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = [
      'cubag_token',
      'cubag_role',
      'cubag_id',
      'cubag_name',
      'cubag_email',
      'cubag_photo',
      'cubag_permissions',
    ];
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}
