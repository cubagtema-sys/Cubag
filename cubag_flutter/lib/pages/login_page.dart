import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../components/app_logo.dart';

const _kOrange = Color(0xFFf08232);

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
  bool _rememberMe      = false;
  String? _error;
  String _loginMode     = 'email';

  final BiometricService _bioService = BiometricService();
  bool _bioAvailable = false;
  bool _bioEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSavedIdentifier();
    _checkBiometric();
  }

  Future<void> _loadSavedIdentifier() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString('remembered_identifier');
    final savedMode = prefs.getString('remembered_mode');
    if (savedId != null && mounted) {
      setState(() {
        _identifierCtrl.text = savedId;
        _rememberMe = true;
        if (savedMode != null) _loginMode = savedMode;
      });
    }
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
    final identifier = creds['email']!;
    final error = await authService.login(identifier, creds['password']!);

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

    final identifier = _loginMode == 'email' ? raw.toLowerCase() : raw;
    final authService = Provider.of<AuthService>(context, listen: false);
    final error = await authService.login(identifier, _passCtrl.text);

    if (mounted) {
      setState(() { _loading = false; _error = error; });
      if (error == null) {
        final prefs = await SharedPreferences.getInstance();
        if (_rememberMe) {
          await prefs.setString('remembered_identifier', raw);
          await prefs.setString('remembered_mode', _loginMode);
        } else {
          await prefs.remove('remembered_identifier');
          await prefs.remove('remembered_mode');
        }

        if (_bioAvailable && !kIsWeb) {
          final alreadyEnabled = await _bioService.isBiometricEnabled();
          if (!alreadyEnabled && mounted) {
            bool? consent = _rememberMe;
            if (!_rememberMe) {
              consent = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Enable Biometric Login?', style: TextStyle(color: Colors.grey)),
                  content: const Text('Would you like to use fingerprint or face recognition next time?', style: TextStyle(color: Colors.grey)),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Not Now', style: TextStyle(color: Colors.grey))),
                    ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), style: ElevatedButton.styleFrom(backgroundColor: _kOrange), child: const Text('Enable', style: TextStyle(color: Colors.white))),
                  ],
                ),
              );
            }
            if (consent == true) {
              await _bioService.saveCredentials(raw, _passCtrl.text);
              await _bioService.setBiometricEnabled(true);
            }
          } else if (alreadyEnabled) {
            await _bioService.saveCredentials(raw, _passCtrl.text);
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
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive ? [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4, offset: const Offset(0, 2))] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isActive ? _kOrange : Colors.grey.shade400),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: isActive ? FontWeight.w800 : FontWeight.w600, color: isActive ? _kOrange : Colors.grey.shade400)),
            ],
          ),
        ),
      ),
    );
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
        Expanded(flex: 30, child: _buildFormPanel(padding: 40)),
      ]);

  Widget _buildTwoColumnLayout() => Row(children: [
        Expanded(flex: 45, child: _buildBrandPanel()),
        Expanded(flex: 55, child: _buildFormPanel(padding: 50)),
      ]);

  Widget _buildMobileLayout() => SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _buildForm(),
            ),
          ),
        ),
      );

  Widget _buildBrandPanel() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0f172a), Color(0xFF1e293b)],
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
                color: Colors.white.withAlpha(8),
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
                      color: _kOrange,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Customs Brokers Association of Ghana',
                    style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'The official mobile gateway for licensed customs clearing and logistics firms in Ghana.',
                    style: TextStyle(
                      color: Colors.grey.shade500,
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
              'Capabilities',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0f172a),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Secure, fast, and unified port solutions at your fingertips.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 40),
            _infoCard(
              icon: Icons.shield_outlined,
              title: 'Secure Access & Credentials',
              desc: 'Manage your verified broker profile, keep track of standing scores, and renew certifications.',
            ),
            const SizedBox(height: 24),
            _infoCard(
              icon: Icons.map_outlined,
              title: 'Vessel & Cargo Intelligence',
              desc: 'Access live maritime AIS tracking feeds, port schedules, and custom cargo clearing timelines.',
            ),
            const SizedBox(height: 24),
            _infoCard(
              icon: Icons.wallet_outlined,
              title: 'Integrated Payments Gateway',
              desc: 'Settle annual dues and platform charges directly using Mobile Money or bank transfers instantly.',
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

  Widget _buildFormPanel({double padding = 60}) => Container(
        color: Colors.white,
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _buildForm(),
            ),
          ),
        ),
      );

  Widget _buildForm() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const AppLogo(size: 60, borderRadius: 14, showShadow: true),
            const SizedBox(height: 24),
            const Text('Welcome Back', textAlign: TextAlign.center, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Color(0xFF0f172a), letterSpacing: -0.5)),
            const SizedBox(height: 8),
            Text('Sign in to the CUBAG Member Portal', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 15, height: 1.4)),
          ],
        ),
      ),
      const SizedBox(height: 40),

      if (_error != null)
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: const Color(0xFFfef2f2), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFfee2e2))),
          child: Row(children: [const Icon(Icons.error_outline, color: Color(0xFFef4444), size: 18), const SizedBox(width: 12), Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFb91c1c), fontSize: 14, fontWeight: FontWeight.w600)))]),
        ),

      Container(
        decoration: BoxDecoration(color: const Color(0xFFf1f5f9), borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.all(4),
        child: Row(children: [
          _loginTab('email',  Icons.email_outlined,   'Email'),
          _loginTab('phone',  Icons.phone_outlined,    'Phone'),
        ]),
      ),
      const SizedBox(height: 24),

      _inputLabel(_loginMode == 'email' ? 'Email Address' : 'Phone Number'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _identifierCtrl,
        keyboardType: _loginMode == 'email' ? TextInputType.emailAddress : TextInputType.phone,
        decoration: _inputDecoration(
          hint: _loginMode == 'email' ? 'name@agency.com' : '024 000 0000',
          icon: _loginMode == 'email' ? Icons.mail_outline : Icons.phone_android_outlined,
        ),
      ),
      const SizedBox(height: 20),

      _inputLabel('Password'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _passCtrl,
        obscureText: !_showPw,
        decoration: _inputDecoration(
          hint: '••••••••',
          icon: Icons.lock_outline_rounded,
          suffix: IconButton(icon: Icon(_showPw ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey.shade400, size: 20), onPressed: () => setState(() => _showPw = !_showPw)),
        ),
      ),

      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              SizedBox(width: 24, height: 24, child: Checkbox(value: _rememberMe, activeColor: _kOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), onChanged: (v) => setState(() => _rememberMe = v ?? false))),
              const SizedBox(width: 8),
              GestureDetector(onTap: () => setState(() => _rememberMe = !_rememberMe), child: const Text('Keep me signed in', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF475569)))),
            ],
          ),
          TextButton(onPressed: () => context.go('/forgot-password'), child: const Text('Forgot?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
        ],
      ),
      const SizedBox(height: 32),

      SizedBox(width: double.infinity, height: 56, child: ElevatedButton(
        onPressed: _loading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(backgroundColor: _kOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
        child: _loading
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
          : const Text('Sign In to Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      )),

      if (_bioAvailable && _bioEnabled && !kIsWeb) ...[
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: Divider(color: Colors.grey.shade200)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('OR', style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1))),
          Expanded(child: Divider(color: Colors.grey.shade200)),
        ]),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, height: 56, child: OutlinedButton.icon(
          onPressed: _loading ? null : _handleBiometricLogin,
          icon: const Icon(Icons.fingerprint_rounded, size: 24),
          label: const Text('Biometric Login', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          style: OutlinedButton.styleFrom(foregroundColor: _kOrange, side: const BorderSide(color: _kOrange, width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        )),
      ],
      const SizedBox(height: 48),

      Center(
        child: GestureDetector(
          onTap: () => context.go('/register'),
          child: const Text.rich(TextSpan(children: [
            TextSpan(text: "New to CUBAG? ", style: TextStyle(color: Color(0xFF64748b), fontSize: 15, fontWeight: FontWeight.w500)),
            TextSpan(text: 'Create an Account', style: TextStyle(color: _kOrange, fontWeight: FontWeight.w800, fontSize: 15)),
          ])),
        ),
      ),
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
