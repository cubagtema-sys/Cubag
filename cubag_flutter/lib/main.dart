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
