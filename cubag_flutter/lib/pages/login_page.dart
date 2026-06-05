import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../components/app_logo.dart';

const _kOrange = Color(0xFFf08232);
const _kOrangeDark = Color(0xFFe06920);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _loading    = false;
  bool _showPw     = false;
  String? _error;

  final BiometricService _bioService = BiometricService();
  bool _bioAvailable = false;
  bool _bioEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    if (kIsWeb) return;
    final available = await _bioService.isBiometricAvailable();
    final enabled = await _bioService.isBiometricEnabled();
    if (mounted) setState(() { _bioAvailable = available; _bioEnabled = enabled; });
  }

  Future<void> _handleBiometricLogin() async {
    final creds = await _bioService.getSavedCredentials();
    if (creds == null) {
      setState(() => _error = 'No saved credentials. Please sign in manually first.');
      return;
    }

    final authenticated = await _bioService.authenticate();
    if (!authenticated) return;

    setState(() { _loading = true; _error = null; });
    final authService = Provider.of<AuthService>(context, listen: false);
    final error = await authService.login(creds['email']!, creds['password']!);

    if (mounted) {
      setState(() { _loading = false; _error = error; });
      if (error == null) {
        final role = authService.userRole;
        context.go((role == 'admin' || role == 'sub_admin') ? '/admin/dashboard' : '/dashboard');
      }
    }
  }

  Future<void> _handleLogin() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Please enter your email and password.');
      return;
    }
    setState(() { _loading = true; _error = null; });

    final authService = Provider.of<AuthService>(context, listen: false);
    final error = await authService.login(_emailCtrl.text.trim(), _passCtrl.text);

    if (mounted) {
      setState(() { _loading = false; _error = error; });
      if (error == null) {
        // Save credentials for biometric re-login on next visit
        if (_bioAvailable) {
          await _bioService.saveCredentials(_emailCtrl.text.trim(), _passCtrl.text);
          await _bioService.setBiometricEnabled(true);
        }
        final role = authService.userRole;
        context.go((role == 'admin' || role == 'sub_admin') ? '/admin/dashboard' : '/dashboard');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 700;
    return Scaffold(body: isWide ? _buildWideLayout() : _buildMobileLayout());
  }

  Widget _buildWideLayout() => Row(children: [
    Expanded(flex: 4, child: _buildSidebar()),
    Expanded(flex: 6, child: _buildFormPanel()),
  ]);

  Widget _buildMobileLayout() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_kOrange, _kOrangeDark, Color(0xFF1a1a2e)]),
    ),
    child: SafeArea(child: Center(child: SingleChildScrollView(child: Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 40, offset: const Offset(0, 20))]),
      child: _buildForm(),
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
        const Text('Enterprise Mobility Platform', style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w500)),
        const SizedBox(height: 48),
        _sidebarFeature(Icons.shield_outlined, 'Official Credentials'),
        const SizedBox(height: 20),
        _sidebarFeature(Icons.bar_chart, 'Real-time Intelligence'),
        const SizedBox(height: 20),
        _sidebarFeature(Icons.lock_outline, 'Bank-grade Security'),
      ])),
    ]),
  );

  Widget _sidebarFeature(IconData icon, String label) => Row(children: [
    Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white.withAlpha(25), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: Colors.white, size: 20)),
    const SizedBox(width: 14),
    Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
  ]);

  Widget _buildFormPanel() => Container(
    color: Colors.white,
    child: Center(child: SingleChildScrollView(child: Container(
      padding: const EdgeInsets.all(48),
      constraints: const BoxConstraints(maxWidth: 480),
      child: _buildForm(),
    ))),
  );

  Widget _buildForm() {
    final isSmall = MediaQuery.of(context).size.width < 360;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    Center(child: Column(children: [
      AppLogo(size: isSmall ? 50 : 60, borderRadius: 14, showShadow: true),
      const SizedBox(height: 12),
      Text('Welcome Back', style: TextStyle(fontSize: isSmall ? 22 : 26, fontWeight: FontWeight.bold, color: const Color(0xFF0f172a))),
      const SizedBox(height: 4),
      Text('Sign in to the CUBAG Member Portal', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: isSmall ? 11 : 13)),
    ])),
    const SizedBox(height: 24),

    if (_error != null)
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0x19ef4444), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0x33ef4444))),
        child: Row(children: [const Icon(Icons.error_outline, color: Color(0xFFef4444), size: 18), const SizedBox(width: 8), Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFef4444), fontSize: 13, fontWeight: FontWeight.w600)))]),
      ),

    const Text('Email Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0f172a))),
    const SizedBox(height: 8),
    TextFormField(
      controller: _emailCtrl,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        hintText: 'broker@example.com',
        prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kOrange, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    ),
    const SizedBox(height: 16),

    const Text('Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0f172a))),
    const SizedBox(height: 8),
    TextFormField(
      controller: _passCtrl,
      obscureText: !_showPw,
      decoration: InputDecoration(
        hintText: '••••••••',
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey, size: 20),
        suffixIcon: IconButton(icon: Icon(_showPw ? Icons.visibility_off : Icons.visibility, color: Colors.grey, size: 20), onPressed: () => setState(() => _showPw = !_showPw)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kOrange, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    ),

    Align(alignment: Alignment.centerRight, child: TextButton(
      onPressed: () => context.go('/forgot-password'),
      style: TextButton.styleFrom(foregroundColor: _kOrange),
      child: const Text('Forgot Password?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    )),
    const SizedBox(height: 8),

    SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
      onPressed: _loading ? null : _handleLogin,
      style: ElevatedButton.styleFrom(backgroundColor: _kOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
      child: _loading
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
        : const Text('Sign In', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    )),

    // ── Biometric quick login (mobile only) ──
    if (_bioAvailable && _bioEnabled && !kIsWeb) ...[
      const SizedBox(height: 12),
      Row(children: [
        const Expanded(child: Divider(color: Color(0xFFe2e8f0))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('or', style: TextStyle(color: Colors.grey.shade500, fontSize: 11))),
        const Expanded(child: Divider(color: Color(0xFFe2e8f0))),
      ]),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, height: 48, child: OutlinedButton.icon(
        onPressed: _loading ? null : _handleBiometricLogin,
        icon: const Icon(Icons.fingerprint, size: 20, color: _kOrange),
        label: const Text('Sign in with Biometrics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        style: OutlinedButton.styleFrom(foregroundColor: _kOrange, side: const BorderSide(color: _kOrange, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      )),
    ],
    const SizedBox(height: 24),

    Center(child: GestureDetector(
      onTap: () => context.go('/register'),
      child: const Text.rich(TextSpan(children: [
        TextSpan(text: "Don't have an account? ", style: TextStyle(color: Colors.grey)),
        TextSpan(text: 'Join CUBAG', style: TextStyle(color: _kOrange, fontWeight: FontWeight.bold)),
      ])),
    )),
  ]);
}
