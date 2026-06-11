import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../components/app_layout.dart';
import '../components/custom_dropdown.dart';
import '../services/api_service.dart';

const _kOrange = Color(0xFFf08232);

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});
  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage>
    with SingleTickerProviderStateMixin {
  int _step = 1;
  final _amountCtrl = TextEditingController();
  String _reason = '';
  String _method = 'momo';
  String _momoNetwork = '';
  String _momoPhone = '';
  String _bankTxId = '';
  bool _loading = false;
  bool _showSuccess = false;
  bool _showError = false;
  String _errorMsg = '';
  String _confirmedAmount = '';
  List<dynamic> _fees = [];
  Map<String, dynamic> _paySettings = {};
  bool _loadingData = true;
  int _pollAttempt = 0;
  final int _pollMax = 60; // 60 × 5s = 5 minutes
  bool _manualChecking = false;
  int? _currentPaymentId;
  String _currentTxRef = '';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.90, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loadingData = true);
    try {
      final api = ApiService();
      final results = await Future.wait([
        api.getPublic('settings/cubag_fees_v2'),
        api.getPublic('settings/cubag_payment_settings_v2'),
      ]);
      
      final feesData = results[0];
      final payData = results[1];

      if (mounted) {
        setState(() {
          if (feesData is List) _fees = feesData;
          if (payData is Map<String, dynamic>) _paySettings = payData;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingData = false);
  }

  Future<void> _submitPayment() async {
    setState(() => _loading = true);
    try {
      final api = ApiService();
      final res = await api.post('/payments', data: {
        'amount': double.tryParse(_amountCtrl.text) ?? 0,
        'description': _reason,
        'method': _method,
        'network': _momoNetwork,
        'phone': _momoPhone,
        'bank_tx_id': _bankTxId,
      });
      
      if (res.statusCode == 200 || res.statusCode == 201) {
        if (_method == 'momo') {
          final paymentId = res.data['payment_id'];
          final txRef = res.data['transaction_ref'] ?? res.data['whitsun_ref'] ?? '';
          setState(() {
            _step = 4;
            _confirmedAmount = _amountCtrl.text;
            _currentPaymentId = paymentId;
            _currentTxRef = txRef;
            _pollAttempt = 0;
          });
          _pollWhitsunPayStatus(paymentId, txRef);
        } else {
          setState(() { _confirmedAmount = _amountCtrl.text; _showSuccess = true; _step = 1; _amountCtrl.clear(); _reason = ''; });
        }
      } else {
        setState(() { _errorMsg = res.data['message'] ?? 'Payment failed.'; _showError = true; });
      }
    } catch (e) {
      setState(() { _errorMsg = 'Network error. Please try again.'; _showError = true; });
    }
    setState(() => _loading = false);
  }

  Future<void> _pollWhitsunPayStatus(int paymentId, String txRef) async {
    final api = ApiService();
    bool isComplete = false;

    while (!isComplete && _pollAttempt < _pollMax && mounted) {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return;
      if (_currentPaymentId != paymentId) return;

      try {
        final res = await api.post('/payments/verify-code', data: {
          'payment_id': paymentId,
          'transaction_ref': txRef,
          'whitsun_ref': txRef,
        });

        if (_currentPaymentId != paymentId) return;

        if (res.statusCode == 200) {
          final status = res.data['status']?.toString().toLowerCase() ?? '';
          if (status == 'success' || status == 'successful' || status == 'completed') {
            isComplete = true;
            if (mounted) setState(() { _showSuccess = true; _step = 1; _amountCtrl.clear(); _reason = ''; });
          } else if (status == 'failed' || status == 'declined' || status == 'cancelled' || status == 'reversed') {
            isComplete = true;
            if (mounted) setState(() { _errorMsg = res.data['message'] ?? 'Payment was declined or cancelled.'; _showError = true; _step = 1; });
          }
        }
      } catch (e) {
        // continue
      }

      if (_currentPaymentId != paymentId) return;
      if (mounted) setState(() => _pollAttempt++);
    }
  }

  Future<void> _manualStatusCheck() async {
    if (_currentTxRef.isEmpty || _manualChecking) return;
    setState(() => _manualChecking = true);
    try {
      final api = ApiService();
      final res = await api.post('/payments/verify-code', data: {
        'payment_id': _currentPaymentId,
        'transaction_ref': _currentTxRef,
        'whitsun_ref': _currentTxRef,
      });
      if (!mounted) return;
      final status = res.data['status']?.toString().toLowerCase() ?? '';
      if (status == 'success' || status == 'successful' || status == 'completed') {
        setState(() { _showSuccess = true; _step = 1; _amountCtrl.clear(); _reason = ''; });
      } else if (status == 'failed' || status == 'declined' || status == 'cancelled') {
        setState(() { _errorMsg = res.data['message'] ?? 'Payment declined.'; _showError = true; _step = 1; });
      } else {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Still pending: ${res.data['message'] ?? 'Please wait for the MoMo prompt.'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height - 120,
              left: 24,
              right: 24,
            ),
            dismissDirection: DismissDirection.up,
            backgroundColor: _kOrange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Check failed — please try again.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height - 120,
              left: 24,
              right: 24,
            ),
            dismissDirection: DismissDirection.up,
            backgroundColor: Colors.red.shade800,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
    if (mounted) setState(() => _manualChecking = false);
  }

  Widget _overlay({required Widget child}) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withAlpha(160),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(40),
                  blurRadius: 40,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: SingleChildScrollView(child: child),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bank = (_paySettings['bankAccounts'] as List?)?.firstOrNull ?? {};

    return AppLayout(
      title: 'Payment',
      scrollable: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Stack(
              children: [
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      Card(
                        color: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: const Color(0xFFcbd5e1).withAlpha(120), width: 1.5),
                        ),
                        child: Column(
                          children: [
                            // Stepper indicator
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFf8fafc),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                border: Border(bottom: BorderSide(color: const Color(0xFFcbd5e1).withAlpha(80), width: 1.5)),
                              ),
                              child: Row(
                                children: List.generate(4, (i) {
                                  final n = i + 1;
                                  final labels = ['Type', 'Method', 'Review', 'Verify'];
                                  final isCompleted = _step > n;
                                  final isActive = _step == n;
                                  
                                  return Expanded(
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Divider(
                                                thickness: 2.5,
                                                color: i == 0
                                                    ? Colors.transparent
                                                    : (_step >= i + 1 ? _kOrange : const Color(0xFFe2e8f0)),
                                              ),
                                            ),
                                            AnimatedContainer(
                                              duration: const Duration(milliseconds: 200),
                                              width: 28,
                                              height: 28,
                                              decoration: BoxDecoration(
                                                color: isCompleted
                                                    ? const Color(0xFF10b981)
                                                    : (isActive ? _kOrange : Colors.white),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: isCompleted
                                                      ? const Color(0xFF10b981)
                                                      : (isActive ? _kOrange : const Color(0xFFcbd5e1)),
                                                  width: 2,
                                                ),
                                                boxShadow: isActive
                                                    ? [BoxShadow(color: _kOrange.withAlpha(50), blurRadius: 6, offset: const Offset(0, 2))]
                                                    : null,
                                              ),
                                              child: Center(
                                                child: isCompleted
                                                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                                                    : Text(
                                                        '$n',
                                                        style: GoogleFonts.outfit(
                                                          color: isActive ? Colors.white : const Color(0xFF64748b),
                                                          fontWeight: FontWeight.w800,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Divider(
                                                thickness: 2.5,
                                                color: i == 3
                                                    ? Colors.transparent
                                                    : (_step > n ? _kOrange : const Color(0xFFe2e8f0)),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          labels[i],
                                          style: GoogleFonts.outfit(
                                            fontSize: 10,
                                            color: isActive ? _kOrange : const Color(0xFF64748b),
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                            ),
                            
                            // Step Form content
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: _buildStepContent(_kOrange, bank),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.verified_user_outlined, size: 14, color: Color(0xFF94a3b8)),
                          const SizedBox(width: 6),
                          Text(
                            'Secured by WhitsunPay PCI-DSS Compliance',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: const Color(0xFF64748b),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Success Modal Overlay
                if (_showSuccess)
                  _overlay(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [Color(0xFF10b981), Color(0xFF059669)]),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded, color: Colors.white, size: 32),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Payment Confirmed!',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0f172a),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Your transaction has been successfully processed.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF64748b), fontSize: 13, height: 1.4),
                        ),
                        if (_confirmedAmount.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFf0fdf4),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFbbf7d0)),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'AMOUNT PAID',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    color: const Color(0xFF16a34a),
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'GH₵ ${double.tryParse(_confirmedAmount)?.toStringAsFixed(2) ?? _confirmedAmount}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF15803d),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10b981),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              setState(() => _showSuccess = false);
                              context.go('/payment-history');
                            },
                            child: Text(
                              'View Payment History',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => setState(() => _showSuccess = false),
                          style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748b)),
                          child: Text(
                            'Close',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Error Modal Overlay
                if (_showError)
                  _overlay(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [Color(0xFFef4444), Color(0xFFdc2626)]),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Transaction Failed',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0f172a),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _errorMsg,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF64748b), fontSize: 13, height: 1.4),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0f172a),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => setState(() => _showError = false),
                            child: Text(
                              'Try Again',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent(Color primary, dynamic bank) {
    if (_step == 1) {
      if (_loadingData) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(40.0),
            child: CircularProgressIndicator(color: _kOrange),
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PAYMENT CATEGORY',
            style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748b), fontWeight: FontWeight.w800, letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          CustomDropdown<String>(
            value: _reason,
            hint: 'Select Payment Category',
            items: [
              ..._fees.map((f) => DropdownItem<String>(value: f['label'].toString(), label: f['label'].toString())),
              const DropdownItem<String>(value: 'Other', label: 'Other / Miscellaneous'),
            ],
            onChanged: (v) {
              setState(() {
                _reason = v;
                if (v == 'Other') {
                  _amountCtrl.clear();
                } else {
                  final fee = _fees.firstWhere((f) => f['label'] == v, orElse: () => null);
                  _amountCtrl.text = fee != null ? fee['amount'].toString() : '';
                }
              });
            },
          ),
          const SizedBox(height: 20),
          Text(
            'AMOUNT TO PAY',
            style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748b), fontWeight: FontWeight.w800, letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFf8fafc),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFcbd5e1).withAlpha(120), width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFe2e8f0),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                    border: Border(right: BorderSide(color: const Color(0xFFcbd5e1).withAlpha(120), width: 1.5)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'GH₵',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _amountCtrl,
                    onChanged: (v) => setState(() {}),
                    keyboardType: TextInputType.number,
                    readOnly: _reason.isNotEmpty && _reason != 'Other',
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF0f172a)),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      hintText: '0.00',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _reason.isEmpty || _amountCtrl.text.isEmpty ? null : () => setState(() => _step = 2),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: const Text('Continue to Methods', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              label: const Icon(Icons.arrow_forward_rounded, size: 16),
            ),
          ),
        ],
      );
    }

    if (_step == 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PREFERRED PAYMENT METHOD',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, color: const Color(0xFF64748b), letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _methodCard('momo', Icons.smartphone_rounded, 'Mobile Money', primary)),
              const SizedBox(width: 14),
              Expanded(child: _methodCard('bank', Icons.account_balance_rounded, 'Bank Transfer', primary)),
            ],
          ),
          const SizedBox(height: 24),
          if (_method == 'momo') ...[
            Text(
              'MOBILE NETWORK',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, color: const Color(0xFF64748b), letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            CustomDropdown<String>(
              value: _momoNetwork,
              hint: 'Select Mobile Money Network',
              items: const [
                DropdownItem(value: 'MTN', label: 'MTN MoMo'),
                DropdownItem(value: 'Vodafone', label: 'Telecel (Vodafone)'),
                DropdownItem(value: 'AirtelTigo', label: 'AT (AirtelTigo)'),
              ],
              onChanged: (v) => setState(() => _momoNetwork = v),
            ),
            const SizedBox(height: 20),
            Text(
              'MOMO PHONE NUMBER',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, color: const Color(0xFF64748b), letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFf8fafc),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFcbd5e1).withAlpha(120), width: 1.5),
              ),
              child: TextFormField(
                initialValue: _momoPhone,
                onChanged: (v) { _momoPhone = v; setState(() {}); },
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1e293b)),
                decoration: const InputDecoration(
                  labelText: null,
                  hintText: 'e.g. 024XXXXXXX',
                  hintStyle: TextStyle(color: Color(0xFF94a3b8), fontSize: 14),
                  counterText: "",
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ],
          if (_method == 'bank') ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFf8fafc),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFcbd5e1).withAlpha(120), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CUBAG OFFICIAL BANK ACCOUNT',
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: primary, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 12),
                  _bankRow('Bank Name', bank['bankName']?.toString() ?? '—'),
                  _bankRow('Account Number', bank['accountNumber']?.toString() ?? '—'),
                  _bankRow('Branch Name', bank['branch']?.toString() ?? '—'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'TRANSACTION ID / REFERENCE',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, color: const Color(0xFF64748b), letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFf8fafc),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFcbd5e1).withAlpha(120), width: 1.5),
              ),
              child: TextFormField(
                initialValue: _bankTxId,
                onChanged: (v) { _bankTxId = v; setState(() {}); },
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1e293b)),
                decoration: const InputDecoration(
                  hintText: 'Enter bank transfer transaction reference ID...',
                  hintStyle: TextStyle(color: Color(0xFF94a3b8), fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _step = 1),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                    side: const BorderSide(color: Color(0xFFcbd5e1), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    foregroundColor: const Color(0xFF475569),
                  ),
                  child: Text(
                    'Back',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: (_method == 'momo' && (_momoNetwork.isEmpty || _momoPhone.trim().length != 10)) ||
                             (_method == 'bank' && _bankTxId.trim().isEmpty)
                      ? null
                      : () => setState(() => _step = 3),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    'Review Summary',
                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (_step == 3) {
      final methodLabel = _method == 'momo' ? (_momoNetwork.isNotEmpty ? 'Mobile Money ($_momoNetwork)' : 'Mobile Money') : 'Bank Transfer';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFcbd5e1).withAlpha(120), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [_kOrange, const Color(0xFFea580c)]),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  ),
                  child: Text(
                    'DIGITAL INVOICE SUMMARY',
                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5),
                  ),
                ),
                ...[
                  {'label': 'Payment Category', 'value': _reason, 'highlight': false},
                  {'label': 'Selected Method', 'value': methodLabel, 'highlight': false},
                  {'label': 'Total Payable Amount', 'value': 'GH₵ ${double.tryParse(_amountCtrl.text)?.toStringAsFixed(2) ?? _amountCtrl.text}', 'highlight': true},
                ].map((row) {
                  final isHighlight = row['highlight'] as bool;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFf1f5f9), width: 1.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          row['label']! as String,
                          style: TextStyle(
                            color: isHighlight ? const Color(0xFF475569) : Colors.grey.shade500,
                            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          row['value']! as String,
                          style: GoogleFonts.outfit(
                            fontWeight: isHighlight ? FontWeight.w900 : FontWeight.w700,
                            color: isHighlight ? _kOrange : const Color(0xFF1e293b),
                            fontSize: isHighlight ? 18 : 13.5,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => setState(() => _step = 2),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(50, 50),
                  side: const BorderSide(color: Color(0xFFcbd5e1), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  foregroundColor: const Color(0xFF475569),
                ),
                child: const Icon(Icons.arrow_back_rounded, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _loading ? null : _submitPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          _method == 'momo' ? 'Initiate Mobile Payment' : 'Confirm & Submit Payment',
                          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Step 4 — Waiting for MoMo PIN approval
    final remaining = (_pollMax - _pollAttempt) * 5;
    final progressVal = _pollMax > 0 ? _pollAttempt / _pollMax : 0.0;

    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, child) => Transform.scale(scale: _pulseAnim.value, child: child),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [primary.withAlpha(140), primary]),
              boxShadow: [
                BoxShadow(
                  color: primary.withAlpha(60),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: const Icon(Icons.phone_android_rounded, color: Colors.white, size: 36),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Awaiting Approval',
          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF0f172a)),
        ),
        const SizedBox(height: 8),
        Text(
          'A Mobile Money prompt has been sent to $_momoPhone.\nOpen your phone and enter your PIN to approve.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF64748b), fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: primary.withAlpha(12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primary.withAlpha(30)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline_rounded, color: primary, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'MTN MoMo Approval Notice',
                    style: GoogleFonts.outfit(color: primary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.3),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'If the prompt does not popup, please dial *170# -> Option 6 (My Wallet) -> Option 3 (My Approvals) on your phone to approve.',
                style: TextStyle(color: Color(0xFF334155), fontSize: 11, height: 1.4),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (_pollAttempt >= _pollMax) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: const Text(
              'Auto-checking timed out. If you have approved the payment on your phone, click "I\'ve Approved — Check Now" below to complete.',
              style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progressVal,
            minHeight: 6,
            backgroundColor: primary.withAlpha(30),
            valueColor: AlwaysStoppedAnimation<Color>(primary),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Checking status... (attempt ${_pollAttempt + 1}/$_pollMax)', style: const TextStyle(fontSize: 10, color: Color(0xFF94a3b8))),
            Text('~${remaining}s left', style: const TextStyle(fontSize: 10, color: Color(0xFF94a3b8))),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _manualChecking ? null : _manualStatusCheck,
            icon: _manualChecking
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
            label: Text(
              _manualChecking ? 'Verifying...' : "I've Approved — Check Now",
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10b981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => setState(() { _step = 2; _pollAttempt = 0; _currentTxRef = ''; }),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748b)),
          child: Text(
            'Cancel & Change Method',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _methodCard(String id, IconData icon, String label, Color primary) {
    final selected = _method == id;
    return GestureDetector(
      onTap: () => setState(() => _method = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? primary : const Color(0xFFe2e8f0),
            width: selected ? 2.5 : 1.5,
          ),
          borderRadius: BorderRadius.circular(16),
          color: selected ? primary.withAlpha(12) : Colors.white,
          boxShadow: selected
              ? [BoxShadow(color: primary.withAlpha(15), blurRadius: 6, offset: const Offset(0, 3))]
              : null,
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: selected ? primary : const Color(0xFF94a3b8)),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                color: selected ? primary : const Color(0xFF475569),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bankRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5, fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF1e293b))),
        ],
      ),
    );
  }
}
