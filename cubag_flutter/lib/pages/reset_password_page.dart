import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../components/app_logo.dart';

const _kOrange = Color(0xFFf08232);
const _kOrangeDark = Color(0xFFe06920);

class ResetPasswordPage extends StatefulWidget {
  final String? email;
  final String? token;
  const ResetPasswordPage({super.key, this.email, this.token});
  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _pwCtrl  = TextEditingController();
  final _cpwCtrl = TextEditingController();
  bool _loading  = false;
  bool _success  = false;
  bool _showPw   = false;
  bool _showCpw  = false;
  String _error  = '';

  Future<void> _reset() async {
    if (_pwCtrl.text != _cpwCtrl.text) { setState(() => _error = 'Passwords do not match.'); return; }
    if (_pwCtrl.text.length < 8) { setState(() => _error = 'Password must be at least 8 characters.'); return; }
    setState(() { _loading = true; _error = ''; });
    try {
      final res = await ApiService().post('/auth/reset-password', data: {
        'email': widget.email ?? '',
        'code': widget.token ?? '',
        'new_password': _pwCtrl.text
      });
      if (res.statusCode == 200) {
        setState(() => _success = true);
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) context.go('/login');
      } else {
        setState(() => _error = res.data['message'] ?? 'Failed to reset password.');
      }
    } catch (_) {
      setState(() => _error = 'Connection error. Please try again later.');
    }
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
        _sidebarFeature(Icons.lock_reset_outlined, 'Password Reset Service'),
        const SizedBox(height: 20),
        _sidebarFeature(Icons.security_outlined, 'Secure Data Transmission'),
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
    if (widget.email == null || widget.token == null) {
      return Column(
        crossAxisAlignment: isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: isMobile ? Alignment.centerLeft : Alignment.center,
            child: const AppLogo(size: 56, borderRadius: 12, showShadow: true),
          ),
          const SizedBox(height: 24),
          Center(
            child: Container(width: 64, height: 64, decoration: const BoxDecoration(color: Color(0x19ef4444), shape: BoxShape.circle), child: const Icon(Icons.error_outline, color: Color(0xFFef4444), size: 40)),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: isMobile ? Alignment.centerLeft : Alignment.center,
            child: const Text('Invalid Link', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0f172a))),
          ),
          const SizedBox(height: 8),
          Text('The password reset link is invalid or missing required parameters.', textAlign: isMobile ? TextAlign.left : TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.5)),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: () => context.go('/forgot-password'), style: ElevatedButton.styleFrom(backgroundColor: _kOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), child: const Text('Request New Link', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
        ],
      );
    }

    if (_success) {
      return Column(
        crossAxisAlignment: isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: isMobile ? Alignment.centerLeft : Alignment.center,
            child: const AppLogo(size: 56, borderRadius: 12, showShadow: true),
          ),
          const SizedBox(height: 24),
          Center(
            child: Container(width: 64, height: 64, decoration: const BoxDecoration(color: Color(0x1910b981), shape: BoxShape.circle), child: const Icon(Icons.check_circle, color: Color(0xFF10b981), size: 40)),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: isMobile ? Alignment.centerLeft : Alignment.center,
            child: const Text('Password Reset', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0f172a))),
          ),
          const SizedBox(height: 8),
          Text('Your password has been updated successfully. Redirecting to login...', textAlign: isMobile ? TextAlign.left : TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.5)),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: () => context.go('/login'), style: ElevatedButton.styleFrom(backgroundColor: _kOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), child: const Text('Back to Login', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
        ],
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Align(
        alignment: Alignment.center,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const AppLogo(size: 56, borderRadius: 12, showShadow: true),
            const SizedBox(height: 16),
            const Text(
              'Set New Password',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF0f172a), letterSpacing: -0.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Choose a new, secure password for your account.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.3),
              textAlign: TextAlign.center,
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
      const Text('New Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
      const SizedBox(height: 8),
      TextField(
        controller: _pwCtrl,
        obscureText: !_showPw,
        decoration: InputDecoration(
          hintText: 'Enter new password',
          prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade400, size: 20),
          suffixIcon: IconButton(icon: Icon(_showPw ? Icons.visibility_off : Icons.visibility, color: Colors.grey.shade400, size: 20), onPressed: () => setState(() => _showPw = !_showPw)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kOrange, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        )
      ),
      const SizedBox(height: 16),
      const Text('Confirm Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
      const SizedBox(height: 8),
      TextField(
        controller: _cpwCtrl,
        obscureText: !_showCpw,
        decoration: InputDecoration(
          hintText: 'Confirm new password',
          prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade400, size: 20),
          suffixIcon: IconButton(icon: Icon(_showCpw ? Icons.visibility_off : Icons.visibility, color: Colors.grey.shade400, size: 20), onPressed: () => setState(() => _showCpw = !_showCpw)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kOrange, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        )
      ),
      const SizedBox(height: 28),
      SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: _loading ? null : _reset, style: ElevatedButton.styleFrom(backgroundColor: _kOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Update Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
    ]);
  }
}
