import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/app_layout.dart';
import '../services/api_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _changingPw = false;
  bool _loading = false;
  bool _notificationsEnabled = true;
  String _message = '';
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  Future<void> _changePassword() async {
    if (_newCtrl.text != _confirmCtrl.text) {
      setState(() => _message = 'Passwords do not match!');
      return;
    }
    setState(() { _loading = true; _message = ''; });
    try {
      final res = await ApiService().post('/auth/change-password', data: {'current_password': _currentCtrl.text, 'new_password': _newCtrl.text});
      if (!mounted) return;  // BUG-F45 fix
      if (res.statusCode == 200) {
        setState(() { _message = '✅ Password updated successfully!'; });
        Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() { _changingPw = false; _message = ''; _currentCtrl.clear(); _newCtrl.clear(); _confirmCtrl.clear(); }); });
      } else {
        // BUG-F46 fix: guard res.data type before indexing
        final msg = res.data is Map ? (res.data['message'] ?? 'Update failed') : 'Update failed';
        setState(() => _message = '❌ $msg');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _message = '❌ Connection error. Try again.');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    // BUG-F44 fix: dispose all 3 controllers
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return AppLayout(
      title: 'Account Settings',
      child: !_changingPw ? _buildMenu(primary) : _buildPasswordForm(primary),
    );
  }

  Widget _buildMenu(Color primary) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        const Padding(padding: EdgeInsets.all(16), child: Align(alignment: Alignment.centerLeft, child: Text('Settings & Security', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
        const Divider(height: 1),
        ListTile(leading: const Icon(Icons.lock_outline), title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w600)), trailing: const Icon(Icons.chevron_right), onTap: () => setState(() => _changingPw = true)),
        const Divider(height: 1),
        SwitchListTile(
          value: _notificationsEnabled,
          // F-47 fix: persist toggle to server
          onChanged: (v) async {
            setState(() => _notificationsEnabled = v);
            try {
              await ApiService().post('/auth/update-preferences', data: {'push_notifications': v});
            } catch (_) {
              // Revert on failure so UI matches server state
              if (mounted) setState(() => _notificationsEnabled = !v);
            }
          },
          secondary: const Icon(Icons.notifications_active_outlined),
          title: const Text('Push Notifications', style: TextStyle(fontWeight: FontWeight.w600))),
        const Divider(height: 1),
        Padding(padding: const EdgeInsets.only(left: 16, top: 12, bottom: 4), child: Align(alignment: Alignment.centerLeft, child: Text('CONTACT & SUPPORT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1)))),
        _contactItem(Icons.call, const Color(0xFFf08232), 'Call Support', '+233 (0) 302 123 456', () async {
          final uri = Uri.parse('tel:+233302123456');
          if (await canLaunchUrl(uri)) await launchUrl(uri);
        }),
        const Divider(height: 1),
        _contactItem(Icons.mail_outline, const Color(0xFF3b82f6), 'Email Us', 'support@cubag.org.gh', () async {
          final uri = Uri.parse('mailto:support@cubag.org.gh');
          if (await canLaunchUrl(uri)) await launchUrl(uri);
        }),
        const Divider(height: 1),
        _contactItem(Icons.forum_outlined, const Color(0xFF10b981), 'Support Center', 'Help desk & messages', () => context.go('/engagement')),
      ]),
    );
  }

  Widget _contactItem(IconData icon, Color color, String label, String sub, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(9)), child: Icon(icon, color: color, size: 18)),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
    );
  }

  Widget _buildPasswordForm(Color primary) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 24),
          _pwField('Current Password', _currentCtrl, _showCurrent, () => setState(() => _showCurrent = !_showCurrent)),
          const SizedBox(height: 16),
          _pwField('New Password', _newCtrl, _showNew, () => setState(() => _showNew = !_showNew)),
          const SizedBox(height: 16),
          _pwField('Confirm New Password', _confirmCtrl, _showConfirm, () => setState(() => _showConfirm = !_showConfirm)),
          if (_message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_message, style: TextStyle(color: _message.contains('✅') ? Colors.green : Colors.red, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: ElevatedButton(onPressed: _loading ? null : _changePassword, style: ElevatedButton.styleFrom(backgroundColor: primary, minimumSize: const Size(0, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Update Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
            const SizedBox(width: 12),
            Expanded(child: OutlinedButton(onPressed: () => setState(() => _changingPw = false), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Cancel'))),
          ]),
        ]),
      ),
    );
  }

  Widget _pwField(String label, TextEditingController ctrl, bool show, VoidCallback toggle) {
    return TextField(
      controller: ctrl,
      obscureText: !show,
      decoration: InputDecoration(
        labelText: label,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        suffixIcon: IconButton(icon: Icon(show ? Icons.visibility : Icons.visibility_off, color: Colors.grey), onPressed: toggle),
      ),
    );
  }
}
