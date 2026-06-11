import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
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
      setState(() => _message = '❌ Passwords do not match!');
      return;
    }
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final res = await ApiService().post('/auth/change-password', data: {
        'current_password': _currentCtrl.text,
        'new_password': _newCtrl.text,
      });
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() {
          _message = '✅ Password updated successfully!';
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _changingPw = false;
              _message = '';
              _currentCtrl.clear();
              _newCtrl.clear();
              _confirmCtrl.clear();
            });
          }
        });
      } else {
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
      scrollable: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: !_changingPw ? _buildMenu(primary) : _buildPasswordForm(primary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenu(Color primary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section 1: Security & Preferences
        Card(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: const Color(0xFFcbd5e1).withAlpha(120), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Text(
                  'SECURITY & PREFERENCES',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF64748b),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFf1f5f9)),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.lock_outline_rounded, color: primary, size: 18),
                ),
                title: Text(
                  'Change Password',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: const Color(0xFF1e293b),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94a3b8), size: 20),
                onTap: () => setState(() => _changingPw = true),
              ),
              const Divider(height: 1, color: Color(0xFFf1f5f9)),
              SwitchListTile(
                value: _notificationsEnabled,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                activeThumbColor: primary,
                activeTrackColor: primary.withAlpha(120),
                onChanged: (v) async {
                  setState(() => _notificationsEnabled = v);
                  try {
                    await ApiService().post('/auth/update-preferences', data: {'push_notifications': v});
                  } catch (_) {
                    if (mounted) setState(() => _notificationsEnabled = !v);
                  }
                },
                secondary: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3b82f6).withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.notifications_active_outlined, color: Color(0xFF3b82f6), size: 18),
                ),
                title: Text(
                  'Push Notifications',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: const Color(0xFF1e293b),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Section 2: Contact & Support
        Card(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: const Color(0xFFcbd5e1).withAlpha(120), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Text(
                  'CONTACT & SUPPORT',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF64748b),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFf1f5f9)),
              _contactItem(
                Icons.call_rounded,
                const Color(0xFFf08232),
                'Call Support',
                '+233 (0) 302 123 456',
                () async {
                  final uri = Uri.parse('tel:+233302123456');
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                },
              ),
              const Divider(height: 1, color: Color(0xFFf1f5f9)),
              _contactItem(
                Icons.mail_outline_rounded,
                const Color(0xFF3b82f6),
                'Email Us',
                'support@cubag.org.gh',
                () async {
                  final uri = Uri.parse('mailto:support@cubag.org.gh');
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                },
              ),
              const Divider(height: 1, color: Color(0xFFf1f5f9)),
              _contactItem(
                Icons.forum_outlined,
                const Color(0xFF10b981),
                'Support Center',
                'Help desk & messages',
                () => context.go('/engagement'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _contactItem(IconData icon, Color color, String label, String sub, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(
        label,
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.w700,
          fontSize: 13.5,
          color: const Color(0xFF1e293b),
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          sub,
          style: GoogleFonts.outfit(
            fontSize: 11.5,
            color: const Color(0xFF64748b),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94a3b8), size: 20),
    );
  }

  Widget _buildPasswordForm(Color primary) {
    Widget? messageWidget;
    if (_message.isNotEmpty) {
      final isSuccess = _message.contains('✅');
      final msgColor = isSuccess ? const Color(0xFF10b981) : const Color(0xFFef4444);
      final msgBg = isSuccess ? const Color(0xFF10b981).withAlpha(15) : const Color(0xFFef4444).withAlpha(15);
      final cleanMsg = _message.replaceAll('✅', '').replaceAll('❌', '').trim();

      messageWidget = Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: msgBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: msgColor.withAlpha(80), width: 1),
        ),
        child: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
              color: msgColor,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                cleanMsg,
                style: GoogleFonts.outfit(
                  color: msgColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFFcbd5e1).withAlpha(120), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Change Password',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: const Color(0xFF1e293b),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Please enter your current password to verify identity, followed by your new password.',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: const Color(0xFF64748b),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            _pwField(
              'Current Password',
              _currentCtrl,
              _showCurrent,
              () => setState(() => _showCurrent = !_showCurrent),
            ),
            const SizedBox(height: 16),
            _pwField(
              'New Password',
              _newCtrl,
              _showNew,
              () => setState(() => _showNew = !_showNew),
            ),
            const SizedBox(height: 16),
            _pwField(
              'Confirm New Password',
              _confirmCtrl,
              _showConfirm,
              () => setState(() => _showConfirm = !_showConfirm),
            ),
            if (messageWidget != null) ...[
              const SizedBox(height: 16),
              messageWidget,
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : _changePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            'Update Password',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _changingPw = false;
                      _message = '';
                      _currentCtrl.clear();
                      _newCtrl.clear();
                      _confirmCtrl.clear();
                    }),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      side: const BorderSide(color: Color(0xFFcbd5e1), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF475569)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pwField(String label, TextEditingController ctrl, bool show, VoidCallback toggle) {
    return TextField(
      controller: ctrl,
      obscureText: !show,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.outfit(color: const Color(0xFF94a3b8), fontSize: 13, fontWeight: FontWeight.w600),
        prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF94a3b8), size: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: const Color(0xFFcbd5e1).withAlpha(120), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        suffixIcon: IconButton(
          icon: Icon(show ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: const Color(0xFF94a3b8), size: 18),
          onPressed: toggle,
        ),
      ),
      style: GoogleFonts.outfit(color: const Color(0xFF1e293b), fontSize: 13.5, fontWeight: FontWeight.w500),
    );
  }
}
