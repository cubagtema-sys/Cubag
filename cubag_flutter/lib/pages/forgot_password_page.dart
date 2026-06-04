import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../components/app_logo.dart';

const _kOrange = Color(0xFFf08232);
const _kOrangeDark = Color(0xFFe06920);

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String _error = '';

  Future<void> _submit() async {
    if (_emailCtrl.text.trim().isEmpty) return;
    setState(() { _loading = true; _error = ''; });
    try {
      final res = await ApiService().post('/auth/forgot-password', data: {'email': _emailCtrl.text.trim()});
      if (res.statusCode == 200) {
        setState(() => _sent = true);
      } else {
        setState(() => _error = res.data['message'] ?? "We couldn't find an account with that email.");
      }
    } catch (_) { setState(() => _error = 'Connection failed. Please check your network.'); }
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
        _sidebarFeature(Icons.lock_reset, 'Simple Password Recovery'),
        const SizedBox(height: 20),
        _sidebarFeature(Icons.email_outlined, 'Secure Verification Link'),
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
        const Text('Reset Password', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0f172a))),
        const SizedBox(height: 8),
        const Text("Enter your email and we'll send you a link to reset your password.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
      ])),
      const SizedBox(height: 28),

      if (_sent)
        Column(children: [
          Container(width: 64, height: 64, decoration: BoxDecoration(color: _kOrange.withAlpha(20), shape: BoxShape.circle), child: const Icon(Icons.mark_email_read_outlined, color: _kOrange, size: 32)),
          const SizedBox(height: 16),
          const Text('Check your Inbox', style: TextStyle(color: Color(0xFF0f172a), fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          Text('If an account exists for ${_emailCtrl.text}, you will receive a reset link shortly.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: () => context.go('/login'), style: ElevatedButton.styleFrom(backgroundColor: _kOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text('Back to Login', style: TextStyle(fontWeight: FontWeight.bold)))),
        ])
      else ...[
        if (_error.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0x19ef4444), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0x33ef4444))),
            child: Row(children: [const Icon(Icons.error_outline, color: Color(0xFFef4444), size: 18), const SizedBox(width: 8), Expanded(child: Text(_error, style: const TextStyle(color: Color(0xFFef4444), fontSize: 13, fontWeight: FontWeight.w600)))]),
          ),

        const Text('Recovery Email', style: TextStyle(color: Color(0xFF0f172a), fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'broker@example.com',
            prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kOrange, width: 2)),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: _kOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Send Reset Link', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        )),
        const SizedBox(height: 20),
        Center(child: TextButton(onPressed: () => context.go('/login'), child: const Text("Remember your password? Sign In", style: TextStyle(color: _kOrange, fontWeight: FontWeight.bold)))),
      ],
    ]);
  }
}
