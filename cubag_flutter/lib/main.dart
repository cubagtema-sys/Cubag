import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'core/router.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/api_service.dart';
import 'services/push_notification_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  // 1. Basic binding initialization
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Silence logs in Production to boost speed
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // 3. Initialize Local Caching (Fast, synchronous DB for offline support)
  await Hive.initFlutter();
  await Hive.openBox('api_cache');

  // 4. Start other services in parallel (Non-blocking)
  _initAppServices();

  // 5. Launch App immediately
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: AuthService()),
        ChangeNotifierProvider(create: (_) => NotificationService()),
      ],
      child: const CubagApp(),
    ),
  );
}

/// Initializes heavy services in the background to speed up startup.
Future<void> _initAppServices() async {
  if (kIsWeb) {
    _protectWebCollections();
  }

  // Firebase, Auth check, and Backend Heartbeat in parallel
  await Future.wait([
    _initFirebase(),
    AuthService().checkAuthStatus(),
    _backendHeartbeat(), // "Wake up" Render backend
  ]);
}

Future<void> _initFirebase() async {
  if (kIsWeb) return;
  try {
    await Firebase.initializeApp();
    await PushNotificationService().initialize();
  } catch (e) {
    // Silent fail in production
  }
}

/// Pings the backend immediately on startup to wake it up from "Sleep" (Render.com free tier)
Future<void> _backendHeartbeat() async {
  try {
    // A simple GET to the health endpoint or base URL
    await ApiService().getPublic('health').timeout(const Duration(seconds: 5));
  } catch (_) {
    // We don't care if it fails, the goal is just to trigger the "Wake up"
  }
}

class CubagApp extends StatelessWidget {
  const CubagApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'CUBAG',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        // Lock text scale factor to 1.0 across all devices (Mobile/Web)
        // so the layout matches the web build exactly, ignoring Android
        // system-level "Large Text" accessibility settings that break UI.
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0),
          ),
          child: child!,
        );
      },
    );
  }
}

void _protectWebCollections() {
  final maps = <Map<String, dynamic>>[
    <String, String>{},
    const <String, String>{},
    const <String, String>{'a': 'b'},
    Map<String, String>.unmodifiable({'a': 'b'}),
    <String, dynamic>{'a': 'b'},
  ];
  for (final map in maps) {
    map.entries.where((e) => e.key == 'a').toList();
    map.keys.where((k) => k == 'a').toList();
    map.values.where((v) => v == 'b').toList();
  }
  final lists = <List<dynamic>>[
    [],
    ['a'],
    [1, 2, 3],
  ];
  for (final list in lists) {
    list.where((e) => e == 'a').toList();
    list.take(1).toList();
  }
}
