import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'core/router.dart';
import 'services/auth_service.dart';
import 'services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Prevent tree-shaking of MapEntryIterable.where (and other collections) by the Dart Web compiler (dart2js).
  // This is a known compiler issue where internal go_router references to pathParameters.entries.where
  // get optimized away if the compiler doesn't detect other references to MapEntryIterable's where method.
  if (kIsWeb) {
    final maps = <Map<String, String>>[
      <String, String>{},
      const <String, String>{},
      const <String, String>{'a': 'b'},
      const <String, String>{'a': 'b', 'c': 'd'},
      Map<String, String>.unmodifiable({'a': 'b'}),
    ];
    for (final map in maps) {
      map.entries.where((e) => e.key == 'a').toList();
      map.keys.where((k) => k == 'a').toList();
      map.values.where((v) => v == 'b').toList();
    }
  }

  // ── Firebase & Push Notifications (mobile only) ──────────────────────────
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
      await PushNotificationService().initialize();
    } catch (e) {
      debugPrint('Firebase init failed (non-fatal): $e');
    }
  }

  final authService = AuthService();
  try {
    await authService.checkAuthStatus();
  } catch (e, stack) {
    debugPrint('Error checking auth status: $e');
    debugPrint(stack.toString());
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authService),
      ],
      child: const CubagApp(),
    ),
  );
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
    );
  }
}
