import 'package:flutter/material.dart';
import '../components/app_layout.dart';
import '../services/api_service.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  Map<String, dynamic> _user = {};
  bool _isLoading = false;
  bool _fetchingUser = true;
  String _message = '';
  bool _isSuccess = false;

  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void initState() {
    super.initState();
    _fetchUser();
  }

  Future<void> _fetchUser() async {
    setState(() => _fetchingUser = true);
    try {
      final res = await ApiService().get('/auth/me');
      if (res.statusCode == 200) {
        setState(() {
          _user = res.data ?? {};
        });
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _fetchingUser = false);
    }
  }

  Future<void> _changePassword() async {
    if (_newCtrl.text != _confirmCtrl.text) {
      setState(() {
        _message = 'New passwords do not match.';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      final res = await ApiService().post('/auth/change-password', data: {
        'current_password': _currentCtrl.text,
        'new_password': _newCtrl.text,
      });

      if (res.statusCode == 200) {
        setState(() {
          _message = '✅ Password successfully reset.';
          _isSuccess = true;
          _currentCtrl.clear();
          _newCtrl.clear();
          _confirmCtrl.clear();
        });
      } else {
        setState(() {
          _message = '❌ ${res.data['message'] ?? 'Update failed'}';
          _isSuccess = false;
        });
      }
    } catch (_) {
      setState(() {
        _message = '❌ Network error. Try again.';
        _isSuccess = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _message = '';
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFFf08232);

    return AppLayout(
      title: 'Platform Settings',
      child: _fetchingUser
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile details card
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.person_outline, color: primary, size: 24),
                                const SizedBox(width: 8),
                                const Text(
                                  'Profile Details',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _readOnlyField('Full Name', _user['name']?.toString() ?? '—'),
                            const SizedBox(height: 12),
                            _readOnlyField('Email Address', _user['email']?.toString() ?? '—'),
                            const SizedBox(height: 12),
                            _readOnlyField('Role', (_user['role']?.toString() ?? '—').toUpperCase()),
                          ],
                        ),
                      ),
                    ),
              const SizedBox(height: 20),

              // Change password card
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lock_reset, color: primary, size: 24),
                          const SizedBox(width: 8),
                          const Text(
                            'Reset Password',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_message.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: _isSuccess ? const Color(0x1510b981) : const Color(0x15ef4444),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _message,
                            style: TextStyle(
                              color: _isSuccess ? const Color(0xFF10b981) : const Color(0xFFef4444),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _pwField('Current Password', _currentCtrl, _showCurrent, () => setState(() => _showCurrent = !_showCurrent)),
                      const SizedBox(height: 12),
                      _pwField('New Password', _newCtrl, _showNew, () => setState(() => _showNew = !_showNew)),
                      const SizedBox(height: 12),
                      _pwField('Confirm Password', _confirmCtrl, _showConfirm, () => setState(() => _showConfirm = !_showConfirm)),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _changePassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text(
                                  'Update Password',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _readOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade500.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _pwField(String label, TextEditingController ctrl, bool show, VoidCallback toggle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          obscureText: !show,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFf08232), width: 2)),
            suffixIcon: IconButton(
              icon: Icon(show ? Icons.visibility : Icons.visibility_off, color: Colors.grey, size: 20),
              onPressed: toggle,
            ),
          ),
        ),
      ],
    );
  }
}
