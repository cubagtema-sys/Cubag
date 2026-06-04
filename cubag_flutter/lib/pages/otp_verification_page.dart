import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../components/app_logo.dart';

const _kOrange = Color(0xFFf08232);
const _kOrangeDark = Color(0xFFe06920);

class OTPVerificationPage extends StatefulWidget {
  final String? email;
  const OTPVerificationPage({super.key, this.email});
  @override
  State<OTPVerificationPage> createState() => _OTPVerificationPageState();
}

class _OTPVerificationPageState extends State<OTPVerificationPage> {
  final List<TextEditingController> _ctrls = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  bool _resending = false;
  String _error = '';
  int _countdown = 60;
  bool _canResend = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _countdown = 60; _canResend = false;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() { _countdown--; if (_countdown <= 0) { _canResend = true; t.cancel(); } });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _ctrls) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _ctrls.map((c) => c.text).join();
    if (code.length < 6) { setState(() => _error = 'Please enter all 6 digits'); return; }
    setState(() { _loading = true; _error = ''; });
    try {
      final res = await ApiService().post('/auth/verify-otp', data: {'email': widget.email ?? '', 'otp': code});
      if (res.statusCode == 200) {
        if (mounted) context.go('/dashboard');
      } else {
        setState(() => _error = res.data['message'] ?? 'Invalid or expired code');
      }
    } catch (_) { setState(() => _error = 'Connection error. Please try again.'); }
    setState(() => _loading = false);
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try { await ApiService().post('/auth/resend-otp', data: {'email': widget.email ?? ''}); } catch (_) {}
    for (final c in _ctrls) {
      c.clear();
    }
    _nodes[0].requestFocus();
    _startTimer();
    setState(() => _resending = false);
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
    Expanded(flex: 6, child: _buildFormPanel()),
  ]);

  Widget _buildMobileLayout() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_kOrange, _kOrangeDark, Color(0xFF1a1a2e)]),
    ),
    child: SafeArea(child: Center(child: SingleChildScrollView(child: Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(28),
      constraints: const BoxConstraints(maxWidth: 420),
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
        const Text('Enterprise Mobility Platform', style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w500)),
        const SizedBox(height: 48),
        _sidebarFeature(Icons.lock_person_outlined, 'Secure Two-Factor Authentication'),
        const SizedBox(height: 20),
        _sidebarFeature(Icons.mark_email_read_outlined, 'Verification Code via Email'),
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
      child: _buildFormContent(),
    ))),
  );

  Widget _buildFormContent() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Center(child: Column(children: [
        const AppLogo(size: 60, borderRadius: 16, showShadow: true),
        const SizedBox(height: 16),
        const Text('Verify Your Email', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0f172a))),
        const SizedBox(height: 8),
        Text('We sent a 6-digit code to:\n${widget.email ?? "your email"}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 13)),
      ])),
      const SizedBox(height: 28),

      if (_error.isNotEmpty)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0x19ef4444), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0x33ef4444))),
          child: Row(children: [const Icon(Icons.error_outline, color: Color(0xFFef4444), size: 18), const SizedBox(width: 8), Expanded(child: Text(_error, style: const TextStyle(color: Color(0xFFef4444), fontSize: 13, fontWeight: FontWeight.w600)))]),
        ),

      Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(6, (i) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: TextField(
            controller: _ctrls[i], focusNode: _nodes[i],
            keyboardType: TextInputType.number, maxLength: 1, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0f172a)),
            decoration: InputDecoration(
              counterText: '',
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.grey, width: 1)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kOrange, width: 2)),
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (v) {
              if (v.isNotEmpty && i < 5) _nodes[i+1].requestFocus();
              if (v.isEmpty && i > 0) _nodes[i-1].requestFocus();
            },
          ),
        ),
      ))),
      const SizedBox(height: 28),

      SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
        onPressed: _loading ? null : _verify,
        style: ElevatedButton.styleFrom(backgroundColor: _kOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Verify & Activate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      )),
      const SizedBox(height: 16),
      Center(child: _canResend
        ? TextButton(onPressed: _resending ? null : _resend, child: Text(_resending ? 'Sending...' : 'Resend Code', style: const TextStyle(color: _kOrange, fontWeight: FontWeight.bold)))
        : Text('Resend code in $_countdown s', style: const TextStyle(color: Colors.grey, fontSize: 13))),
      const SizedBox(height: 8),
      Center(child: TextButton(onPressed: () => context.go('/register'), child: const Text('Wrong email? Go Back', style: TextStyle(color: _kOrange, fontWeight: FontWeight.bold)))),
    ]);
  }
}
