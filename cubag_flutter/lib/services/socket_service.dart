import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  socket_io.Socket? _socket;

  socket_io.Socket? get socket => _socket;
  
  final String _serverUrl = const String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://127.0.0.1:5000',
  );

  void initSocket() async {
    // Prevent multiple initializations
    if (_socket != null && _socket!.connected) {
      debugPrint('Socket already initialized and connected');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('cubag_token');

    String cleanUrl = _serverUrl;
    if (cleanUrl.endsWith('/api')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 4);
    } else if (cleanUrl.endsWith('/api/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 5);
    }

    _socket = socket_io.io(cleanUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'extraHeaders': {
        if (token != null) 'Authorization': 'Bearer $token'
      }
    });

    _socket?.connect();

    _socket?.onConnect((_) {
      debugPrint('Socket connected');
    });

    _socket?.onDisconnect((_) {
      debugPrint('Socket disconnected');
    });

    _socket?.on('notification', (data) {
      debugPrint('Received notification: $data');
    });
  }

  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
