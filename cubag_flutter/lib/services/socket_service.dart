import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  socket_io.Socket? _socket;
  socket_io.Socket? get socket => _socket;

  /// Derives the Socket.IO server root URL from the same API_URL
  /// env var used by ApiService — stripping the trailing /api/ segment.
  /// Default falls back to the production backend, NOT localhost.
  static String get _socketUrl {
    // ApiService.baseUrl returns something like:
    //   https://cubag-backend.onrender.com/api/
    // Socket.IO lives at the root:
    //   https://cubag-backend.onrender.com
    String url = ApiService.baseUrl;
    // Strip trailing slash
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    // Strip /api suffix so we get the server root
    if (url.endsWith('/api')) url = url.substring(0, url.length - 4);
    return url;
  }

  Future<void> initSocket() async {
    // Prevent duplicate connections
    if (_socket != null && _socket!.connected) {
      debugPrint('[Socket] Already connected — skipping init');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('cubag_token');
    final url = _socketUrl;

    debugPrint('[Socket] Connecting to $url');

    _socket = socket_io.io(url, <String, dynamic>{
      'transports': ['websocket', 'polling'], // fallback to polling if WS blocked
      'autoConnect': false,
      'reconnection': true,
      'reconnectionAttempts': 5,
      'reconnectionDelay': 2000,
      'extraHeaders': {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    });

    _socket!.connect();

    _socket!.onConnect((_) {
      debugPrint('[Socket] Connected ✓');
    });

    _socket!.onConnectError((err) {
      debugPrint('[Socket] Connection error: $err');
    });

    _socket!.onDisconnect((_) {
      debugPrint('[Socket] Disconnected');
    });

    _socket!.on('notification', (data) {
      debugPrint('[Socket] Notification: $data');
    });
  }

  /// Update the auth token after login without full reconnect.
  Future<void> refreshToken() async {
    if (_socket == null) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('cubag_token');
    if (token != null) {
      _socket!.io.options?['extraHeaders'] = {'Authorization': 'Bearer $token'};
    }
  }

  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
