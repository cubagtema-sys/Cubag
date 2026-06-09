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
      if (!mounted) return;
      if (res.statusCode == 200) {
        context.go('/dashboard');
      } else {
        setState(() => _error = res.data['message'] ?? 'Invalid or expired code');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Connection error. Please try again.');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try { await ApiService().post('/auth/resend-otp', data: {'email': widget.email ?? ''}); } catch (_) {}
    if (!mounted) return;
    for (final c in _ctrls) { c.clear(); }
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

  Widget _buildMobileLayout() => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _buildFormContent(isMobile: true),
          ),
        ),
      ),
    ),
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
    Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white.withAlpha(25), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: Colors.white, size: 20)),
    const SizedBox(width: 14),
    Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
  ]);

  Widget _buildFormPanel() => Container(
    color: Colors.white,
    child: Center(child: SingleChildScrollView(child: Container(
      padding: const EdgeInsets.all(48),
      constraints: const BoxConstraints(maxWidth: 480),
      child: _buildFormContent(isMobile: false),
    ))),
  );

  Widget _buildFormContent({bool isMobile = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Align(
        alignment: isMobile ? Alignment.centerLeft : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.start,
          children: [
            const AppLogo(size: 56, borderRadius: 12, showShadow: true),
            const SizedBox(height: 16),
            const Text(
              'Verify Your Email',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF0f172a), letterSpacing: -0.5),
            ),
            const SizedBox(height: 6),
            Text(
              'We sent a 6-digit code to:\n${widget.email ?? "your email"}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.3),
            ),
          ],
        ),
      ),
      const SizedBox(height: 32),

      if (_error.isNotEmpty)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0x19ef4444), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x33ef4444))),
          child: Row(children: [const Icon(Icons.error_outline, color: Color(0xFFef4444), size: 18), const SizedBox(width: 10), Expanded(child: Text(_error, style: const TextStyle(color: Color(0xFFef4444), fontSize: 13, fontWeight: FontWeight.w600)))]),
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
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kOrange, width: 2)),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onChanged: (v) {
              if (v.isNotEmpty && i < 5) _nodes[i+1].requestFocus();
              if (v.isEmpty && i > 0) _nodes[i-1].requestFocus();
            },
          ),
        ),
      ))),
      const SizedBox(height: 32),

      SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
        onPressed: _loading ? null : _verify,
        style: ElevatedButton.styleFrom(backgroundColor: _kOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
        child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Verify & Activate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      )),
      const SizedBox(height: 24),
      Center(child: _canResend
        ? TextButton(onPressed: _resending ? null : _resend, child: Text(_resending ? 'Sending...' : 'Resend Code', style: const TextStyle(color: _kOrange, fontWeight: FontWeight.bold, fontSize: 14)))
        : Text('Resend code in $_countdown s', style: TextStyle(color: Colors.grey.shade500, fontSize: 14))),
      const SizedBox(height: 12),
      Center(child: TextButton(onPressed: () => context.go('/register'), child: const Text('Wrong email? Go Back', style: TextStyle(color: _kOrange, fontWeight: FontWeight.bold, fontSize: 14)))),
    ]);
  }
}
