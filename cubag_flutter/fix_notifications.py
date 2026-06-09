import re

# 1. Update push_notification_service.dart
with open('lib/services/push_notification_service.dart', 'r') as f:
    push_content = f.read()

# Replace unconditional requestPermission
old_req = """      // ── Request FCM permissions ─────────────────────────────────────────────
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('FCM permission: ${settings.authorizationStatus}');"""
new_req = """      // ── Request FCM permissions ─────────────────────────────────────────────
      final currentSettings = await _messaging.getNotificationSettings();
      if (currentSettings.authorizationStatus == AuthorizationStatus.notDetermined) {
         // Do not request permission yet, let the UI handle the soft prompt!
         debugPrint('FCM permission not determined yet, skipping native prompt.');
      } else {
         final settings = await _messaging.requestPermission(alert: true, badge: true, sound: true);
         debugPrint('FCM permission: ${settings.authorizationStatus}');
      }"""
push_content = push_content.replace(old_req, new_req)

with open('lib/services/push_notification_service.dart', 'w') as f:
    f.write(push_content)

# 2. Update app_layout.dart to include the soft prompt
with open('lib/components/app_layout.dart', 'r') as f:
    layout_content = f.read()

import_sp = "import 'package:shared_preferences/shared_preferences.dart';"
if import_sp not in layout_content:
    layout_content = layout_content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:shared_preferences/shared_preferences.dart';\nimport 'package:firebase_messaging/firebase_messaging.dart';\nimport '../services/push_notification_service.dart';")

init_old = """  @override
  void initState() {
    super.initState();
  }"""
init_new = """  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNotificationPrompt();
    });
  }

  Future<void> _checkNotificationPrompt() async {
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      if (!auth.isAuthenticated) return;

      final prefs = await SharedPreferences.getInstance();
      final lastPrompt = prefs.getInt('last_notif_prompt') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      // Remind every 3 days if not determined
      if (now - lastPrompt < 3 * 24 * 60 * 60 * 1000 && lastPrompt != 0) return;

      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.getNotificationSettings();
      
      if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        if (!mounted) return;
        final primary = Theme.of(context).primaryColor;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(children: [
              Icon(Icons.notifications_active_rounded, color: Color(0xFFf08232), size: 28),
              SizedBox(width: 12),
              Text('Stay in the know', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ]),
            content: const Text('Turn on notifications to get instant alerts on cargo schedules, payment updates, and important CUBAG announcements.', style: TextStyle(color: Color(0xFF475569), fontSize: 14)),
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            actions: [
              TextButton(
                onPressed: () {
                  prefs.setInt('last_notif_prompt', now);
                  Navigator.pop(ctx);
                },
                child: const Text('Remind me later', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                onPressed: () async {
                  prefs.setInt('last_notif_prompt', now);
                  Navigator.pop(ctx);
                  await messaging.requestPermission(alert: true, badge: true, sound: true);
                  PushNotificationService().initialize(); 
                },
                style: ElevatedButton.styleFrom(backgroundColor: primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                child: const Text('Allow notifications', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (_) {}
  }"""
if "Future<void> _checkNotificationPrompt() async" not in layout_content:
    layout_content = layout_content.replace(init_old, init_new)

with open('lib/components/app_layout.dart', 'w') as f:
    f.write(layout_content)

