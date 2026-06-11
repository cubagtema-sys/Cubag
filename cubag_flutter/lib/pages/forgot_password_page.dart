import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../components/app_logo.dart';

const _kOrange = Color(0xFFf08232);

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
    if (_emailCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your email address.');
      return;
    }
    setState(() { _loading = true; _error = ''; });
    try {
      final res = await ApiService().post('/auth/forgot-password', data: {'email': _emailCtrl.text.trim()});
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() => _sent = true);
      } else {
        setState(() => _error = res.data['message'] ?? "We couldn't find an account with that email.");
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Connection failed. Please check your network.');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1050;
    final isTablet = size.width > 700 && size.width <= 1050;

    return Scaffold(
      backgroundColor: Colors.white,
      body: isDesktop
          ? _buildThreeColumnLayout()
          : (isTablet ? _buildTwoColumnLayout() : _buildMobileLayout()),
    );
  }

  Widget _buildThreeColumnLayout() => Row(children: [
        Expanded(flex: 35, child: _buildBrandPanel()),
        Expanded(flex: 35, child: _buildInfoPanel()),
        Expanded(flex: 30, child: _buildFormPanel(padding: 40, showLogo: false)),
      ]);

  Widget _buildTwoColumnLayout() => Row(children: [
        Expanded(flex: 45, child: _buildBrandPanel()),
        Expanded(flex: 55, child: _buildFormPanel(padding: 50, showLogo: false)),
      ]);

  Widget _buildMobileLayout() => SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _buildFormContent(showLogo: true),
            ),
          ),
        ),
      );

  Widget _buildBrandPanel() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFf08232), Color(0xFFea580c)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -50,
              bottom: -50,
              child: Icon(
                Icons.directions_boat,
                size: 300,
                color: Colors.white.withAlpha(15),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppLogo(size: 64, borderRadius: 16),
                  const SizedBox(height: 32),
                  Text(
                    'CUBAG',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 60,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Customs Brokers Association of Ghana',
                    style: GoogleFonts.outfit(
                      color: Colors.white.withAlpha(220),
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'The official mobile gateway for licensed customs clearing and logistics firms in Ghana.',
                    style: TextStyle(
                      color: Colors.white.withAlpha(180),
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildInfoPanel() => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFf8fafc),
          border: Border(right: BorderSide(color: Color(0xFFe2e8f0), width: 1)),
        ),
        padding: const EdgeInsets.all(48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Security Center',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0f172a),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ensure your member account remains secure and authorized.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 40),
            _infoCard(
              icon: Icons.verified_user_outlined,
              title: 'Authorized Retrieval',
              desc: 'Password recovery is restricted to verified customs broker accounts with registered email credentials.',
            ),
            const SizedBox(height: 24),
            _infoCard(
              icon: Icons.lock_reset_outlined,
              title: 'Secure Reset Links',
              desc: 'We use temporary, encrypted single-use tokens sent to your inbox to protect against unauthorized access.',
            ),
            const SizedBox(height: 24),
            _infoCard(
              icon: Icons.contact_support_outlined,
              title: 'Need Assistance?',
              desc: 'If you no longer have access to your registered contact info, please contact the CUBAG Support Desk.',
            ),
          ],
        ),
      );

  Widget _infoCard({required IconData icon, required String title, required String desc}) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: const Color(0xFFf1f5f9)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kOrange.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _kOrange, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0f172a),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    desc,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildFormPanel({double padding = 60, required bool showLogo}) => Container(
        color: Colors.white,
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _buildFormContent(showLogo: showLogo),
            ),
          ),
        ),
      );

  Widget _buildFormContent({required bool showLogo}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (showLogo) ...[
              const AppLogo(size: 60, borderRadius: 14, showShadow: true),
              const SizedBox(height: 24),
            ],
            const Text('Reset Password', textAlign: TextAlign.center, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Color(0xFF0f172a), letterSpacing: -0.5)),
            const SizedBox(height: 8),
            Text("Enter your email and we'll send you a link to reset your password.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 15, height: 1.4)),
          ],
        ),
      ),
      const SizedBox(height: 40),

      if (_sent) ...[
        Center(
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _kOrange.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mark_email_read_outlined, color: _kOrange, size: 36),
              ),
              const SizedBox(height: 24),
              const Text(
                'Check your Inbox',
                style: TextStyle(color: Color(0xFF0f172a), fontWeight: FontWeight.w900, fontSize: 20),
              ),
              const SizedBox(height: 12),
              Text(
                'If an account exists for ${_emailCtrl.text.trim()}, you will receive a password reset link shortly.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => context.go('/login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('Back to Login', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ] else ...[
        if (_error.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFfef2f2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFfee2e2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFef4444), size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _error,
                    style: const TextStyle(color: Color(0xFFb91c1c), fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

        _inputLabel('Recovery Email'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: _inputDecoration(
            hint: 'name@agency.com',
            icon: Icons.mail_outline,
          ),
        ),
        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: _loading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Text('Send Reset Link', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(height: 32),

        Center(
          child: GestureDetector(
            onTap: () => context.go('/login'),
            child: const Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: "Remember your password? ", style: TextStyle(color: Color(0xFF64748b), fontSize: 15, fontWeight: FontWeight.w500)),
                  TextSpan(text: 'Sign In', style: TextStyle(color: _kOrange, fontWeight: FontWeight.w800, fontSize: 15)),
                ],
              ),
            ),
          ),
        ),
      ],
    ]);
  }

  Widget _inputLabel(String text) => Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1e293b)));

  InputDecoration _inputDecoration({required String hint, required IconData icon, Widget? suffix}) => InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, color: const Color(0xFF94a3b8), size: 20),
    suffixIcon: suffix,
    filled: true,
    fillColor: Colors.white,
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFe2e8f0), width: 1.5)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _kOrange, width: 2)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    hintStyle: const TextStyle(color: Color(0xFF94a3b8)),
  );
}
