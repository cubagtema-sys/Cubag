import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  Map<String, dynamic> _complianceSettings = {};
  bool _fetchingSettings = true;
  bool _savingSettings = false;
  String _settingsMessage = '';
  bool _settingsSuccess = false;

  final _payPunctualCtrl = TextEditingController();
  final _payHistoryCtrl = TextEditingController();
  final _licActiveCtrl = TextEditingController();
  final _licInactiveCtrl = TextEditingController();
  final _taskCtrl = TextEditingController();
  final _surveyCtrl = TextEditingController();
  final _agmActiveCtrl = TextEditingController();
  final _agmInactiveCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUser();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    setState(() => _fetchingSettings = true);
    try {
      final res = await ApiService().get('/compliance-settings');
      if (res.statusCode == 200) {
        setState(() {
          _complianceSettings = res.data ?? {};
          _payPunctualCtrl.text = _complianceSettings['payment_punctual']?.toString() ?? '25';
          _payHistoryCtrl.text = _complianceSettings['payment_history']?.toString() ?? '15';
          _licActiveCtrl.text = _complianceSettings['license_active']?.toString() ?? '15';
          _licInactiveCtrl.text = _complianceSettings['license_inactive']?.toString() ?? '5';
          _taskCtrl.text = _complianceSettings['task_completion']?.toString() ?? '15';
          _surveyCtrl.text = _complianceSettings['survey_completion']?.toString() ?? '10';
          _agmActiveCtrl.text = _complianceSettings['agm_active']?.toString() ?? '10';
          _agmInactiveCtrl.text = _complianceSettings['agm_inactive']?.toString() ?? '5';
        });
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _fetchingSettings = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _savingSettings = true;
      _settingsMessage = '';
    });
    try {
      final res = await ApiService().put('/compliance-settings', data: {
        'payment_punctual': int.tryParse(_payPunctualCtrl.text) ?? 25,
        'payment_history': int.tryParse(_payHistoryCtrl.text) ?? 15,
        'license_active': int.tryParse(_licActiveCtrl.text) ?? 15,
        'license_inactive': int.tryParse(_licInactiveCtrl.text) ?? 5,
        'task_completion': int.tryParse(_taskCtrl.text) ?? 15,
        'survey_completion': int.tryParse(_surveyCtrl.text) ?? 10,
        'agm_active': int.tryParse(_agmActiveCtrl.text) ?? 10,
        'agm_inactive': int.tryParse(_agmInactiveCtrl.text) ?? 5,
      });
      if (res.statusCode == 200) {
        setState(() {
          _settingsSuccess = true;
          _settingsMessage = '✅ Settings updated and scores recalculated.';
        });
      } else {
        setState(() {
          _settingsSuccess = false;
          _settingsMessage = '❌ Update failed.';
        });
      }
    } catch (_) {
      setState(() {
        _settingsSuccess = false;
        _settingsMessage = '❌ Network error.';
      });
    } finally {
      setState(() => _savingSettings = false);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _settingsMessage = '');
      });
    }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final cardBg = isDark ? const Color(0xFF1e293b) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0);
    final textColor = isDark ? const Color(0xFFf8fafc) : const Color(0xFF0f172a);
    final subTextColor = isDark ? const Color(0xFF94a3b8) : const Color(0xFF475569);
    final inputBg = isDark ? const Color(0xFF0f172a).withValues(alpha: 0.4) : const Color(0xFFf8fafc);

    return AppLayout(
      title: 'Platform Settings',
      scrollable: true,
      child: _fetchingUser
          ? const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator(color: Color(0xFFf08232))))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile details card
                    Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                  child: Icon(Icons.person_outline_rounded, color: primary, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Profile Details',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: textColor),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _readOnlyField('Full Name', _user['name']?.toString() ?? '—', inputBg, borderColor, textColor, subTextColor),
                            const SizedBox(height: 16),
                            _readOnlyField('Email Address', _user['email']?.toString() ?? '—', inputBg, borderColor, textColor, subTextColor),
                            const SizedBox(height: 16),
                            _readOnlyField('Role', (_user['role']?.toString() ?? '—').toUpperCase(), inputBg, borderColor, textColor, subTextColor),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Change password card
                    Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                  child: Icon(Icons.lock_reset_rounded, color: primary, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Reset Password',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: textColor),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            if (_message.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: _isSuccess ? const Color(0xFF10b981).withValues(alpha: 0.15) : const Color(0xFFef4444).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _isSuccess ? const Color(0xFF10b981).withValues(alpha: 0.3) : const Color(0xFFef4444).withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(_isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: _isSuccess ? const Color(0xFF10b981) : const Color(0xFFef4444), size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _message.replaceAll('✅ ', '').replaceAll('❌ ', ''),
                                        style: GoogleFonts.outfit(
                                          color: _isSuccess ? const Color(0xFF10b981) : const Color(0xFFef4444),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                            _pwField('Current Password', _currentCtrl, _showCurrent, () => setState(() => _showCurrent = !_showCurrent), inputBg, borderColor, textColor, subTextColor, primary),
                            const SizedBox(height: 16),
                            _pwField('New Password', _newCtrl, _showNew, () => setState(() => _showNew = !_showNew), inputBg, borderColor, textColor, subTextColor, primary),
                            const SizedBox(height: 16),
                            _pwField('Confirm Password', _confirmCtrl, _showConfirm, () => setState(() => _showConfirm = !_showConfirm), inputBg, borderColor, textColor, subTextColor, primary),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _changePassword,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : Text(
                                        'Update Password',
                                        style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Compliance Weights Card
                    const SizedBox(height: 24),
                    if (!_fetchingSettings)
                      Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                    child: Icon(Icons.score_rounded, color: primary, size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Compliance Scoring Weights',
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: textColor),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              if (_settingsMessage.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: _settingsSuccess ? const Color(0xFF10b981).withValues(alpha: 0.15) : const Color(0xFFef4444).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _settingsSuccess ? const Color(0xFF10b981).withValues(alpha: 0.3) : const Color(0xFFef4444).withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(_settingsSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: _settingsSuccess ? const Color(0xFF10b981) : const Color(0xFFef4444), size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _settingsMessage.replaceAll('✅ ', '').replaceAll('❌ ', ''),
                                          style: GoogleFonts.outfit(
                                            color: _settingsSuccess ? const Color(0xFF10b981) : const Color(0xFFef4444),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                              Text("Payment Points", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor, fontSize: 15)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(child: _weightField('Punctual', _payPunctualCtrl, inputBg, borderColor, textColor, subTextColor, primary)),
                                  const SizedBox(width: 16),
                                  Expanded(child: _weightField('History', _payHistoryCtrl, inputBg, borderColor, textColor, subTextColor, primary)),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Text("License Points", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor, fontSize: 15)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(child: _weightField('Active', _licActiveCtrl, inputBg, borderColor, textColor, subTextColor, primary)),
                                  const SizedBox(width: 16),
                                  Expanded(child: _weightField('Inactive', _licInactiveCtrl, inputBg, borderColor, textColor, subTextColor, primary)),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Text("Tasks & Surveys Points", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor, fontSize: 15)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(child: _weightField('Tasks', _taskCtrl, inputBg, borderColor, textColor, subTextColor, primary)),
                                  const SizedBox(width: 16),
                                  Expanded(child: _weightField('Surveys', _surveyCtrl, inputBg, borderColor, textColor, subTextColor, primary)),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Text("AGM Points", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor, fontSize: 15)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(child: _weightField('Active', _agmActiveCtrl, inputBg, borderColor, textColor, subTextColor, primary)),
                                  const SizedBox(width: 16),
                                  Expanded(child: _weightField('Inactive', _agmInactiveCtrl, inputBg, borderColor, textColor, subTextColor, primary)),
                                ],
                              ),
                              const SizedBox(height: 28),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _savingSettings ? null : _saveSettings,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primary,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 0,
                                  ),
                                  child: _savingSettings
                                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : Text(
                                          'Save Compliance Weights',
                                          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 48), // Bottom padding
                  ],
                ),
              ),
            ),
    );
  }

  Widget _readOnlyField(String label, String value, Color inputBg, Color borderColor, Color textColor, Color subTextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: subTextColor),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            value,
            style: GoogleFonts.outfit(fontSize: 15, color: textColor, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _pwField(String label, TextEditingController ctrl, bool show, VoidCallback toggle, Color inputBg, Color borderColor, Color textColor, Color subTextColor, Color primary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: subTextColor),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          obscureText: !show,
          style: GoogleFonts.outfit(color: textColor, fontSize: 15),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: inputBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor, width: 1.5)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primary, width: 2)),
            suffixIcon: IconButton(
              icon: Icon(show ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: subTextColor, size: 22),
              onPressed: toggle,
            ),
          ),
        ),
      ],
    );
  }

  Widget _weightField(String label, TextEditingController ctrl, Color inputBg, Color borderColor, Color textColor, Color subTextColor, Color primary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: subTextColor),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: GoogleFonts.outfit(color: textColor, fontSize: 15, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: inputBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor, width: 1.5)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primary, width: 2)),
          ),
        ),
      ],
    );
  }
}
