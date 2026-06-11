import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../components/app_logo.dart';

const _kOrange = Color(0xFFf08232);

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
      _err('Please provide your identity details to continue.');
      return;
    }
    _err('');
    setState(() => _step = 2);
  }

  Future<void> _step2Next() async {
    if (_companyCtrl.text.trim().isEmpty) {
      _err('Please enter your agency or company name.');
      return;
    }
    _err('');
    setState(() => _loading = true);
    try {
      final res = await ApiService().post('/auth/send-otp', data: {'email': _emailCtrl.text.trim()});
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() { _step = 3; _error = ''; });
      } else {
        _err(res.data['message'] ?? 'Failed to send verification code.');
      }
    } catch (_) {
      if (!mounted) return;
      _err('Network error. Please try again.');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _verifyOtp() async {
    if (_otpCtrl.text.length != 6) {
      _err('Enter the 6-digit code sent to your email.');
      return;
    }
    _err('');
    setState(() => _loading = true);
    try {
      final res = await ApiService().post('/auth/verify-email', data: {'email': _emailCtrl.text.trim(), 'token': _otpCtrl.text.trim()});
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() { _step = 4; _error = ''; });
      } else {
        _err(res.data['message'] ?? 'Invalid or expired code.');
      }
    } catch (_) {
      if (!mounted) return;
      _err('Connection error. Try again.');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _register() async {
    if (_pwCtrl.text != _cpwCtrl.text) {
      _err('Passwords do not match.');
      return;
    }
    if (_pwCtrl.text.length < 8) {
      _err('Password must be at least 8 characters.');
      return;
    }
    _err('');
    setState(() => _loading = true);
    try {
      final res = await ApiService().post('/auth/register', data: {
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'company': _companyCtrl.text.trim(),
        'licenseNumber': _licCtrl.text.trim(),
        'agencyCode': _agcCtrl.text.trim(),
        'portOfOperation': _form['portOfOperation'],
        'memberType': _form['memberType'],
        'password': _pwCtrl.text,
      });
      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        context.go('/login');
      } else {
        _err(res.data['message'] ?? 'Registration failed.');
      }
    } catch (_) {
      if (!mounted) return;
      _err('Connection error. Please try again.');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _companyCtrl.dispose();
    _licCtrl.dispose();
    _agcCtrl.dispose();
    _otpCtrl.dispose();
    _pwCtrl.dispose();
    _cpwCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 700;

    return Scaffold(
      backgroundColor: Colors.white,
      body: isWide ? _buildTwoColumnLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildTwoColumnLayout() => Row(children: [
        Expanded(flex: 45, child: _buildBrandPanel()),
        Expanded(flex: 55, child: _buildFormPanel(padding: 50, showLogo: false)),
      ]);

  Widget _buildMobileLayout() => SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _buildFormContent(showLogo: true, isMobile: true),
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


  Widget _buildFormPanel({double padding = 60, required bool showLogo}) => Container(
        color: Colors.white,
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _buildFormContent(showLogo: showLogo),
            ),
          ),
        ),
      );

  Widget _buildFormContent({required bool showLogo, bool isMobile = false}) {
    final stepLabels = ['Identity', 'Professional', 'Verify', 'Security'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (showLogo) ...[
              const AppLogo(size: 60, borderRadius: 14, showShadow: true),
              const SizedBox(height: 24),
            ],
            Text(
              ['Join CUBAG', 'Professional Profile', 'Verify Identity', 'Secure Account'][_step - 1],
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 30, fontWeight: FontWeight.w900, color: const Color(0xFF0f172a), letterSpacing: -0.5),
            ),
            const SizedBox(height: 8),
            Text(
              ['Provide contact information to register.', 'Tell us about your logistics agency.', 'Enter verification code sent to your email.', 'Choose a secure password for your account.'][_step - 1],
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15, height: 1.4),
            ),
          ],
        ),
      ),
      const SizedBox(height: 32),

      // Step Progress Indicator
      if (isMobile) ...[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Step $_step of 4',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
            ),
            Text(
              stepLabels[_step - 1],
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _kOrange),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _step / 4.0,
            minHeight: 6,
            backgroundColor: Colors.grey.shade100,
            valueColor: const AlwaysStoppedAnimation<Color>(_kOrange),
          ),
        ),
      ] else ...[
        SizedBox(
          height: 60,
          child: Row(
            children: List.generate(4, (i) {
              final n = i + 1;
              final done = _step > n;
              final active = _step == n;

              return Expanded(
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: Divider(thickness: 2, color: i == 0 ? Colors.transparent : (_step > i ? _kOrange : Colors.grey.shade200))),
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: done || active ? _kOrange : Colors.grey.shade200,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: done
                              ? const Icon(Icons.check, color: Colors.white, size: 14)
                              : Text('$n', style: TextStyle(color: done || active ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                        ),
                        Expanded(child: Divider(thickness: 2, color: i == 3 ? Colors.transparent : (_step > n ? _kOrange : Colors.grey.shade200))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        stepLabels[i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: done || active ? _kOrange : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
      const SizedBox(height: 32),

      if (_error.isNotEmpty)
        Container(
          width: double.infinity,
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

      if (_step == 1) _buildStep1(),
      if (_step == 2) _buildStep2(),
      if (_step == 3) _buildStep3(),
      if (_step == 4) _buildStep4(),

      const SizedBox(height: 24),
      Center(
        child: GestureDetector(
          onTap: () => context.go('/login'),
          child: const Text.rich(
            TextSpan(
              children: [
                TextSpan(text: "Already have an account? ", style: TextStyle(color: Color(0xFF64748b), fontSize: 15, fontWeight: FontWeight.w500)),
                TextSpan(text: 'Sign In', style: TextStyle(color: _kOrange, fontWeight: FontWeight.w800, fontSize: 15)),
              ],
            ),
          ),
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

  Widget _field(String label, TextEditingController ctrl, {TextInputType type = TextInputType.text, String? hint, IconData? icon}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _inputLabel(label),
    const SizedBox(height: 8),
    TextFormField(
      controller: ctrl,
      keyboardType: type,
      decoration: _inputDecoration(
        hint: hint ?? '',
        icon: icon ?? Icons.text_fields,
      ),
    ),
    const SizedBox(height: 18),
  ]);

  Widget _buildStep1() => Column(children: [
    _field('Full Name', _nameCtrl, hint: 'e.g. John Mensah', icon: Icons.person_outline),
    _field('Email Address', _emailCtrl, type: TextInputType.emailAddress, hint: 'e.g. john@agency.com', icon: Icons.email_outlined),
    _field('Phone Number', _phoneCtrl, type: TextInputType.phone, hint: 'e.g. 024 5678 901', icon: Icons.phone_outlined),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _inputLabel('Membership Type'),
      const SizedBox(height: 10),
      _buildMemberTypeCards(),
      const SizedBox(height: 18),
    ]),
    const SizedBox(height: 12),
    SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _step1Next,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kOrange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: const Text('Next Step', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
    ),
  ]);

  Widget _buildMemberTypeCards() {
    const types = [
      {'value': 'Individual Broker', 'label': 'Individual Broker', 'icon': Icons.person_outline, 'desc': 'Licensed customs broker'},
      {'value': 'Corporate Agency', 'label': 'Corporate Agency', 'icon': Icons.business_outlined, 'desc': 'Registered logistics firm'},
      {'value': 'Associate Member', 'label': 'Associate Member', 'icon': Icons.groups_outlined, 'desc': 'Supporting partner'},
    ];

    return Column(
      children: types.map((t) {
        final selected = _form['memberType'] == t['value'];
        return GestureDetector(
          onTap: () => setState(() => _form['memberType'] = t['value'] as String),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: selected ? _kOrange.withAlpha(10) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? _kOrange : const Color(0xFFe2e8f0),
                width: selected ? 2 : 1.5,
              ),
              boxShadow: selected
                  ? [BoxShadow(color: _kOrange.withAlpha(12), blurRadius: 10, offset: const Offset(0, 4))]
                  : null,
            ),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? _kOrange.withAlpha(20) : const Color(0xFFf1f5f9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  t['icon'] as IconData,
                  color: selected ? _kOrange : const Color(0xFF64748b),
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    t['label'] as String,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: selected ? _kOrange : const Color(0xFF0f172a),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t['desc'] as String,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ]),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? _kOrange : Colors.transparent,
                  border: Border.all(
                    color: selected ? _kOrange : const Color(0xFFcbd5e1),
                    width: 2,
                  ),
                ),
                child: selected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
              ),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPortCards() {
    const ports = [
      {'value': 'Tema Port',      'label': 'Tema Port',       'icon': Icons.anchor,            'desc': 'Main sea port — Greater Accra'},
      {'value': 'Takoradi Port',  'label': 'Takoradi Port',   'icon': Icons.directions_boat,   'desc': 'Western Region sea port'},
      {'value': 'KIA Air Cargo',  'label': 'KIA Air Cargo',   'icon': Icons.flight,            'desc': 'Kotoka International Airport'},
      {'value': 'Elubo Border',   'label': 'Elubo Border',    'icon': Icons.swap_horiz,        'desc': 'Ghana–Côte d\'Ivoire border'},
      {'value': 'Aflao Border',   'label': 'Aflao Border',    'icon': Icons.swap_horiz,        'desc': 'Ghana–Togo border crossing'},
    ];

    return Column(
      children: ports.map((p) {
        final selected = _form['portOfOperation'] == p['value'];
        return GestureDetector(
          onTap: () => setState(() => _form['portOfOperation'] = p['value'] as String),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: selected ? _kOrange.withAlpha(10) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? _kOrange : const Color(0xFFe2e8f0),
                width: selected ? 2 : 1.5,
              ),
              boxShadow: selected
                  ? [BoxShadow(color: _kOrange.withAlpha(12), blurRadius: 10, offset: const Offset(0, 4))]
                  : null,
            ),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? _kOrange.withAlpha(20) : const Color(0xFFf1f5f9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  p['icon'] as IconData,
                  color: selected ? _kOrange : const Color(0xFF64748b),
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    p['label'] as String,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: selected ? _kOrange : const Color(0xFF0f172a),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p['desc'] as String,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ]),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? _kOrange : Colors.transparent,
                  border: Border.all(
                    color: selected ? _kOrange : const Color(0xFFcbd5e1),
                    width: 2,
                  ),
                ),
                child: selected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
              ),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStep2() => Column(children: [
    _field('Agency or Company Name', _companyCtrl, hint: 'e.g. Global Logistics Ltd', icon: Icons.business_outlined),
    Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _kOrange.withAlpha(10), border: Border.all(color: _kOrange.withAlpha(25)), borderRadius: BorderRadius.circular(14)),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.info_outline, color: _kOrange, size: 16), SizedBox(width: 8), Text('Note for New Applicants:', style: TextStyle(fontSize: 13, color: _kOrange, fontWeight: FontWeight.bold))]),
        SizedBox(height: 8),
        Text("If you don't have these details yet, leave them blank. CUBAG will assign them upon approval.", style: TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4))
      ]),
    ),
    _field('License # (Optional)', _licCtrl, hint: 'LIC/...', icon: Icons.assignment_outlined),
    _field('Member ID (Optional)', _agcCtrl, hint: 'CUB-...', icon: Icons.badge_outlined),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _inputLabel('Primary Port of Operation'),
      const SizedBox(height: 10),
      _buildPortCards(),
      const SizedBox(height: 18),
    ]),
    const SizedBox(height: 12),
    Row(children: [
      Expanded(
        child: OutlinedButton(
          onPressed: () => setState(() => _step = 1),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFcbd5e1), width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            minimumSize: const Size(0, 56),
          ),
          child: const Text('Back', style: TextStyle(color: Color(0xFF475569), fontSize: 15, fontWeight: FontWeight.w800)),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        flex: 2,
        child: ElevatedButton(
          onPressed: _loading ? null : _step2Next,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kOrange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            minimumSize: const Size(0, 56),
            elevation: 0,
          ),
          child: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Verify Email', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ),
      ),
    ]),
  ]);

  Widget _buildStep3() => Column(children: [
    Center(
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(color: _kOrange.withAlpha(20), shape: BoxShape.circle),
        child: const Icon(Icons.mark_email_read, color: _kOrange, size: 36),
      ),
    ),
    const SizedBox(height: 24),
    const Text('Check your inbox for a 6-digit verification code.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 15)),
    const SizedBox(height: 32),
    TextFormField(
      controller: _otpCtrl,
      keyboardType: TextInputType.number,
      maxLength: 6,
      textAlign: TextAlign.center,
      style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 12),
      decoration: InputDecoration(
        hintText: '000000',
        counterText: '',
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFe2e8f0), width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _kOrange, width: 2)),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
      ),
    ),
    const SizedBox(height: 36),
    Row(children: [
      Expanded(
        child: OutlinedButton(
          onPressed: () => setState(() => _step = 2),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFcbd5e1), width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            minimumSize: const Size(0, 56),
          ),
          child: const Text('Back', style: TextStyle(color: Color(0xFF475569), fontSize: 15, fontWeight: FontWeight.w800)),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        flex: 2,
        child: ElevatedButton(
          onPressed: _loading ? null : _verifyOtp,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kOrange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            minimumSize: const Size(0, 56),
            elevation: 0,
          ),
          child: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Verify Code', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ),
      ),
    ]),
  ]);

  Widget _buildStep4() => Column(children: [
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _inputLabel('Create Password'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _pwCtrl,
        obscureText: !_showPw,
        decoration: _inputDecoration(
          hint: 'At least 8 characters',
          icon: Icons.lock_outline,
          suffix: IconButton(
            icon: Icon(_showPw ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey.shade400, size: 20),
            onPressed: () => setState(() => _showPw = !_showPw),
          ),
        ),
      ),
      const SizedBox(height: 20),
      _inputLabel('Confirm Password'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _cpwCtrl,
        obscureText: !_showConfirm,
        decoration: _inputDecoration(
          hint: 'Repeat password',
          icon: Icons.lock_outline,
          suffix: IconButton(
            icon: Icon(_showConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey.shade400, size: 20),
            onPressed: () => setState(() => _showConfirm = !_showConfirm),
          ),
        ),
      ),
    ]),
    const SizedBox(height: 32),
    Row(children: [
      Expanded(
        child: OutlinedButton(
          onPressed: () => setState(() => _step = 3),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFcbd5e1), width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            minimumSize: const Size(0, 56),
          ),
          child: const Text('Back', style: TextStyle(color: Color(0xFF475569), fontSize: 15, fontWeight: FontWeight.w800)),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        flex: 2,
        child: ElevatedButton(
          onPressed: _loading ? null : _register,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kOrange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            minimumSize: const Size(0, 56),
            elevation: 0,
          ),
          child: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Complete Registration', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ),
      ),
    ]),
  ]);
}

