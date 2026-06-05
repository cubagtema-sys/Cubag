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
  final _identifierCtrl = TextEditingController();
  final _passCtrl       = TextEditingController();
  bool _loading         = false;
  bool _showPw          = false;
  String? _error;
  String _loginMode     = 'email'; // 'email' or 'phone'

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
    final error = await authService.login(creds['email']!.toLowerCase(), creds['password']!);

    if (mounted) {
      setState(() { _loading = false; _error = error; });
      if (error == null) {
        final role = authService.userRole;
        context.go((role == 'admin' || role == 'sub_admin') ? '/admin/dashboard' : '/dashboard');
      }
    }
  }

  Future<void> _handleLogin() async {
    final raw = _identifierCtrl.text.trim();
    if (raw.isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Please enter your ${_loginMode == 'email' ? 'email' : 'phone number'} and password.');
      return;
    }
    setState(() { _loading = true; _error = null; });

    // Normalise: lowercase for email, digits-only kept as-is for phone
    final identifier = _loginMode == 'email' ? raw.toLowerCase() : raw;
    final authService = Provider.of<AuthService>(context, listen: false);
    final error = await authService.login(identifier, _passCtrl.text);

    if (mounted) {
      setState(() { _loading = false; _error = error; });
      if (error == null) {
        // BUG-13 fix: ask for user consent before saving biometric credentials
        if (_bioAvailable && !kIsWeb) {
          final alreadyEnabled = await _bioService.isBiometricEnabled();
          if (!alreadyEnabled && mounted) {
            final consent = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Enable Biometric Login?'),
                content: const Text(
                  'Would you like to use fingerprint or face recognition to sign in faster next time?'
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Not Now'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(backgroundColor: _kOrange),
                    child: const Text('Enable', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
            if (consent == true) {
              await _bioService.saveCredentials(_identifierCtrl.text.trim(), _passCtrl.text);
              await _bioService.setBiometricEnabled(true);
            }
          }
        }
        if (mounted) {
          final role = authService.userRole;
          context.go((role == 'admin' || role == 'sub_admin') ? '/admin/dashboard' : '/dashboard');
        }
      }
    }
  }

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Widget _loginTab(String mode, IconData icon, String label) {
    final isActive = _loginMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _loginMode = mode;
          _identifierCtrl.clear();
          _error = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isActive
                ? [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 6, offset: const Offset(0, 2))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isActive ? _kOrange : Colors.grey.shade400),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? _kOrange : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

  Widget _buildMobileLayout() => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _buildForm(isMobile: true),
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
      child: _buildForm(isMobile: false),
    ))),
  );

  Widget _buildForm({bool isMobile = false}) {
    final isSmall = MediaQuery.of(context).size.width < 360;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AppLogo(size: isSmall ? 48 : 56, borderRadius: 12, showShadow: true),
            const SizedBox(height: 16),
            Text(
              'Welcome Back',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isSmall ? 24 : 28,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0f172a),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Sign in to the CUBAG Member Portal',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: isSmall ? 13 : 14,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 32),

      if (_error != null)
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0x19ef4444), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x33ef4444))),
          child: Row(children: [const Icon(Icons.error_outline, color: Color(0xFFef4444), size: 18), const SizedBox(width: 10), Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFef4444), fontSize: 13, fontWeight: FontWeight.w600)))]),
        ),

      // ── Email / Phone toggle ──────────────────────────────────
      Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            _loginTab('email',  Icons.email_outlined,   'Email'),
            _loginTab('phone',  Icons.phone_outlined,    'Phone'),
          ],
        ),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _identifierCtrl,
        keyboardType: _loginMode == 'email' ? TextInputType.emailAddress : TextInputType.phone,
        autocorrect: false,
        textCapitalization: TextCapitalization.none,
        decoration: InputDecoration(
          hintText: _loginMode == 'email' ? 'broker@example.com' : '024 5678 901',
          prefixIcon: Icon(
            _loginMode == 'email' ? Icons.email_outlined : Icons.phone_outlined,
            color: Colors.grey.shade400, size: 20,
          ),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kOrange, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
      const SizedBox(height: 20),

      const Text('Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
      const SizedBox(height: 8),
      TextFormField(
        controller: _passCtrl,
        obscureText: !_showPw,
        decoration: InputDecoration(
          hintText: '••••••••',
          prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade400, size: 20),
          suffixIcon: IconButton(icon: Icon(_showPw ? Icons.visibility_off : Icons.visibility, color: Colors.grey.shade400, size: 20), onPressed: () => setState(() => _showPw = !_showPw)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kOrange, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),

      Center(child: TextButton(
        onPressed: () => context.go('/forgot-password'),
        style: TextButton.styleFrom(foregroundColor: _kOrange),
        child: const Text('Forgot Password?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      )),
      const SizedBox(height: 12),

      SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
        onPressed: _loading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(backgroundColor: _kOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
        child: _loading
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      )),

      if (_bioAvailable && _bioEnabled && !kIsWeb) ...[
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Divider(color: Colors.grey.shade200)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: TextStyle(color: Colors.grey.shade400, fontSize: 13))),
          Expanded(child: Divider(color: Colors.grey.shade200)),
        ]),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, height: 52, child: OutlinedButton.icon(
          onPressed: _loading ? null : _handleBiometricLogin,
          icon: const Icon(Icons.fingerprint, size: 20, color: _kOrange),
          label: const Text('Sign in with Biometrics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          style: OutlinedButton.styleFrom(foregroundColor: _kOrange, side: const BorderSide(color: _kOrange, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        )),
      ],
      const SizedBox(height: 32),

      Center(
        child: GestureDetector(
          onTap: () => context.go('/register'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Don't have an account?",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 4),
              const Text(
                'Join CUBAG',
                style: TextStyle(
                  color: _kOrange,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    ]);
  }
}
