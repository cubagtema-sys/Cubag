import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../components/custom_dropdown.dart';
import '../services/api_service.dart';
import '../components/app_logo.dart';

const _kOrange = Color(0xFFf08232);
const _kOrangeDark = Color(0xFFe06920);

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  int _step = 1;
  bool _loading = false;
  String _error = '';

  bool _showPw = false;
  bool _showConfirm = false;

  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _licCtrl     = TextEditingController();
  final _agcCtrl     = TextEditingController();
  final _otpCtrl     = TextEditingController();
  final _pwCtrl      = TextEditingController();
  final _cpwCtrl     = TextEditingController();

  final Map<String, String> _form = {
    'portOfOperation': 'Tema Port',
    'memberType': 'Individual Broker',
  };

  void _err(String msg) => setState(() => _error = msg);

  void _step1Next() {
    if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
      _err('Please provide your identity details to continue.'); return;
    }
    _err(''); setState(() => _step = 2);
  }

  Future<void> _step2Next() async {
    if (_companyCtrl.text.trim().isEmpty) { _err('Please enter your agency or company name.'); return; }
    _err(''); setState(() => _loading = true);
    try {
      final res = await ApiService().post('/auth/send-otp', data: {'email': _emailCtrl.text.trim()});
      if (res.statusCode == 200) {
        setState(() { _step = 3; _error = ''; });
      } else {
        _err(res.data['message'] ?? 'Failed to send verification code.');
      }
    } catch (_) { _err('Network error. Please try again.'); }
    setState(() => _loading = false);
  }

  Future<void> _verifyOtp() async {
    if (_otpCtrl.text.length != 6) { _err('Enter the 6-digit code sent to your email.'); return; }
    _err(''); setState(() => _loading = true);
    try {
      final res = await ApiService().post('/auth/verify-email', data: {'email': _emailCtrl.text.trim(), 'token': _otpCtrl.text.trim()});
      if (res.statusCode == 200) {
        setState(() { _step = 4; _error = ''; });
      } else {
        _err(res.data['message'] ?? 'Invalid or expired code.');
      }
    } catch (_) { _err('Connection error. Try again.'); }
    setState(() => _loading = false);
  }

  Future<void> _register() async {
    if (_pwCtrl.text != _cpwCtrl.text) { _err('Passwords do not match.'); return; }
    if (_pwCtrl.text.length < 8) { _err('Password must be at least 8 characters.'); return; }
    _err(''); setState(() => _loading = true);
    try {
      final res = await ApiService().post('/auth/register', data: {
        'name': _nameCtrl.text.trim(), 'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(), 'company': _companyCtrl.text.trim(),
        'licenseNumber': _licCtrl.text.trim(), 'agencyCode': _agcCtrl.text.trim(),
        'portOfOperation': _form['portOfOperation'], 'memberType': _form['memberType'],
        'password': _pwCtrl.text,
      });
      if (res.statusCode == 200 || res.statusCode == 201) {
        if (mounted) context.go('/login');
      } else { _err(res.data['message'] ?? 'Registration failed.'); }
    } catch (_) { _err('Connection error. Please try again.'); }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 700;

    return Scaffold(
      body: isWide ? _buildWideLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildWideLayout() => Row(children: [
    Expanded(flex: 4, child: _buildSidebar()),
    Expanded(flex: 6, child: _buildFormPanel(fullscreen: false)),
  ]);

  Widget _buildMobileLayout() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_kOrange, _kOrangeDark, Color(0xFF1a1a2e)]),
    ),
    child: SafeArea(child: Center(child: SingleChildScrollView(child: Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 40, offset: const Offset(0, 20))]),
      child: _buildFormContent(),
    )))),
  );

  Widget _buildSidebar() => Container(
    decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_kOrange, _kOrangeDark])),
    child: Stack(children: [
      Positioned(top: -80, right: -80, child: Container(width: 280, height: 280, decoration: BoxDecoration(color: Colors.white.withAlpha(18), shape: BoxShape.circle))),
      Positioned(bottom: -60, left: -60, child: Container(width: 200, height: 200, decoration: BoxDecoration(color: Colors.white.withAlpha(12), shape: BoxShape.circle))),
      Padding(padding: const EdgeInsets.all(40), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('CUBAG', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1)),
        const SizedBox(height: 8),
        const Text('Join the Official Broker Community', style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w500)),
        const SizedBox(height: 48),
        _sidebarFeature(Icons.how_to_reg, 'Quick & Secured Sign Up'),
        const SizedBox(height: 20),
        _sidebarFeature(Icons.verified_user_outlined, 'Official Registry Listing'),
        const SizedBox(height: 20),
        _sidebarFeature(Icons.handshake_outlined, 'Direct Port Operations Access'),
      ])),
    ]),
  );

  Widget _sidebarFeature(IconData icon, String label) => Row(children: [
    Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white.withAlpha(25), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: Colors.white, size: 20)),
    const SizedBox(width: 14),
    Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14))),
  ]);

  Widget _buildFormPanel({required bool fullscreen}) => Container(
    color: Colors.white,
    child: Center(child: SingleChildScrollView(child: Container(
      padding: const EdgeInsets.all(40),
      constraints: const BoxConstraints(maxWidth: 520),
      child: _buildFormContent(),
    ))),
  );

  Widget _buildFormContent() {
    final isSmall = MediaQuery.of(context).size.width < 360;
    final stepLabels = ['Identity', 'Professional', 'Verify', 'Security'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Center(child: Column(children: [
        AppLogo(size: isSmall ? 44 : 56, borderRadius: 12, showShadow: true),
        const SizedBox(height: 12),
        Text(['Join CUBAG', 'Professional Profile', 'Verify Identity', 'Secure Account'][_step - 1], style: TextStyle(fontSize: isSmall ? 18 : 22, fontWeight: FontWeight.bold, color: const Color(0xFF0f172a))),
        const SizedBox(height: 4),
        Text(['Provide contact information.', 'Tell us about your agency.', 'Enter verification code.', 'Choose a password.'][_step - 1], textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ])),
      const SizedBox(height: 20),

      // Step progress indicator — optimized for mobile
      Row(children: List.generate(4, (i) {
        final n = i + 1;
        final done = _step > n;
        final active = _step == n;
        return Expanded(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            if (i > 0) Expanded(child: Container(height: 2, color: _step > n - 1 ? _kOrange : Colors.grey.shade200)),
            CircleAvatar(radius: isSmall ? 11 : 13, backgroundColor: done || active ? _kOrange : Colors.grey.shade200, child: done ? const Icon(Icons.check, color: Colors.white, size: 12) : Text('$n', style: TextStyle(color: done || active ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 10))),
            if (i < 3) Expanded(child: Container(height: 2, color: done ? _kOrange : Colors.grey.shade200)),
          ]),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              stepLabels[i], 
              textAlign: TextAlign.center, 
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: done || active ? _kOrange : Colors.grey),
            ),
          ),
        ]));
      })),
      const SizedBox(height: 20),

      // Error
      if (_error.isNotEmpty)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0x19ef4444), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0x33ef4444))),
          child: Row(children: [const Icon(Icons.error_outline, color: Color(0xFFef4444), size: 18), const SizedBox(width: 8), Expanded(child: Text(_error, style: const TextStyle(color: Color(0xFFef4444), fontSize: 13, fontWeight: FontWeight.w600)))]),
        ),

      // Step content
      if (_step == 1) _buildStep1(),
      if (_step == 2) _buildStep2(),
      if (_step == 3) _buildStep3(),
      if (_step == 4) _buildStep4(),

      const SizedBox(height: 20),
      Center(child: TextButton(onPressed: () => context.go('/login'), child: const Text.rich(TextSpan(children: [
        TextSpan(text: "Already have an account? ", style: TextStyle(color: Colors.grey)),
        TextSpan(text: 'Sign In', style: TextStyle(color: _kOrange, fontWeight: FontWeight.bold)),
      ])))),
    ]);
  }

  Widget _field(String label, TextEditingController ctrl, {TextInputType type = TextInputType.text, String? hint, IconData? icon}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0f172a))),
    const SizedBox(height: 8),
    TextField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, color: Colors.grey, size: 20) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kOrange, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    ),
    const SizedBox(height: 14),
  ]);

  Widget _dropdown(String label, String value, List<String> opts, void Function(String) onChange, {IconData? icon}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0f172a))),
    const SizedBox(height: 8),
    CustomDropdown<String>(
      value: value,
      items: opts.map((o) => DropdownItem<String>(value: o, label: o)).toList(),
      onChanged: onChange,
      prefixIcon: icon != null ? Icon(icon, color: Colors.grey, size: 20) : null,
    ),
    const SizedBox(height: 14),
  ]);

  Widget _buildStep1() => Column(children: [
    _field('Full Name', _nameCtrl, hint: 'e.g. John Mensah', icon: Icons.person_outline),
    _field('Email Address', _emailCtrl, type: TextInputType.emailAddress, hint: 'e.g. john@agency.com', icon: Icons.email_outlined),
    _field('Phone Number', _phoneCtrl, type: TextInputType.phone, hint: 'e.g. 024 5678 901', icon: Icons.phone_outlined),
    _dropdown('Membership Type', _form['memberType']!, ['Individual Broker', 'Corporate Agency', 'Associate Member'], (v) => setState(() => _form['memberType'] = v), icon: Icons.badge_outlined),
    const SizedBox(height: 10),
    SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: _step1Next, style: ElevatedButton.styleFrom(backgroundColor: _kOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Next Step', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)))),
  ]);

  Widget _buildStep2() => Column(children: [
    _field('Agency or Company Name', _companyCtrl, hint: 'e.g. Global Logistics Ltd', icon: Icons.business_outlined),
    Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _kOrange.withAlpha(12), border: Border.all(color: _kOrange.withAlpha(40)), borderRadius: BorderRadius.circular(10)),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.info_outline, color: _kOrange, size: 16), SizedBox(width: 6), Text('Note for New Applicants:', style: TextStyle(fontSize: 12, color: _kOrange, fontWeight: FontWeight.bold))]),
        SizedBox(height: 4),
        Text("If you don't have these details yet, leave them blank. CUBAG will assign them upon approval.", style: TextStyle(fontSize: 11, color: Colors.grey))
      ]),
    ),
    _field('License # (Optional)', _licCtrl, hint: 'LIC/...', icon: Icons.assignment_outlined),
    _field('Agency Code (Optional)', _agcCtrl, hint: 'CUB-...', icon: Icons.code_outlined),
    _dropdown('Primary Port of Operation', _form['portOfOperation']!, ['Tema Port', 'Takoradi Port', 'KIA Air Cargo', 'Elubo Border', 'Aflao Border'], (v) => setState(() => _form['portOfOperation'] = v), icon: Icons.anchor),
    const SizedBox(height: 10),
    Row(children: [
      Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = 1), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.grey), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), minimumSize: const Size(0, 44)), child: const Text('Back', style: TextStyle(color: Colors.grey, fontSize: 13)))),
      const SizedBox(width: 8),
      Expanded(flex: 2, child: ElevatedButton(onPressed: _loading ? null : _step2Next, style: ElevatedButton.styleFrom(backgroundColor: _kOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), minimumSize: const Size(0, 44)), child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Verify Email', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)))),
    ]),
  ]);

  Widget _buildStep3() => Column(children: [
    Center(child: Container(width: 60, height: 60, decoration: BoxDecoration(color: _kOrange.withAlpha(20), shape: BoxShape.circle), child: const Icon(Icons.mark_email_read, color: _kOrange, size: 30))),
    const SizedBox(height: 12),
    const Text('Check your inbox for a 6-digit verification code.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
    const SizedBox(height: 20),
    TextField(controller: _otpCtrl, keyboardType: TextInputType.number, maxLength: 6, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 12), decoration: InputDecoration(hintText: '000000', counterText: '', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
    const SizedBox(height: 24),
    Row(children: [
      Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = 2), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.grey), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), minimumSize: const Size(0, 48)), child: const Text('Back', style: TextStyle(color: Colors.grey)))),
      const SizedBox(width: 12),
      Expanded(flex: 2, child: ElevatedButton(onPressed: _loading ? null : _verifyOtp, style: ElevatedButton.styleFrom(backgroundColor: _kOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), minimumSize: const Size(0, 48)), child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Verify Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)))),
    ]),
  ]);

  Widget _buildStep4() => Column(children: [
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Create Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0f172a))),
      const SizedBox(height: 8),
      TextField(controller: _pwCtrl, obscureText: !_showPw, decoration: InputDecoration(hintText: 'At least 8 characters', prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey, size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), suffixIcon: IconButton(icon: Icon(_showPw ? Icons.visibility_off : Icons.visibility, color: Colors.grey, size: 20), onPressed: () => setState(() => _showPw = !_showPw)))),
      const SizedBox(height: 16),
      const Text('Confirm Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0f172a))),
      const SizedBox(height: 8),
      TextField(controller: _cpwCtrl, obscureText: !_showConfirm, decoration: InputDecoration(hintText: 'Repeat password', prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey, size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), suffixIcon: IconButton(icon: Icon(_showConfirm ? Icons.visibility_off : Icons.visibility, color: Colors.grey, size: 20), onPressed: () => setState(() => _showConfirm = !_showConfirm)))),
    ]),
    const SizedBox(height: 24),
    Row(children: [
      Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = 3), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.grey), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), minimumSize: const Size(0, 48)), child: const Text('Back', style: TextStyle(color: Colors.grey)))),
      const SizedBox(width: 12),
      Expanded(flex: 2, child: ElevatedButton(onPressed: _loading ? null : _register, style: ElevatedButton.styleFrom(backgroundColor: _kOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), minimumSize: const Size(0, 48)), child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Complete', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)))),
    ]),
  ]);
}
