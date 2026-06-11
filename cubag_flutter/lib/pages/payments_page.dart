import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../components/app_layout.dart';
import '../components/custom_dropdown.dart';
import '../services/api_service.dart';

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
  // Polling state
  int _pollAttempt = 0;
  final int _pollMax = 60; // 60 × 5s = 5 minutes
  bool _manualChecking = false;
  int? _currentPaymentId;
  String _currentTxRef = '';

  // Repeating pulse animation for MoMo waiting screen
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
      if (_currentPaymentId != paymentId) {
        // Active payment changed or cancelled, abort polling
        return;
      }

      try {
        final res = await api.post('/payments/verify-code', data: {
          'payment_id': paymentId,
          'transaction_ref': txRef,
          'whitsun_ref': txRef,
        });

        if (_currentPaymentId != paymentId) return; // double check

        if (res.statusCode == 200) {
          final status = res.data['status']?.toString().toLowerCase() ?? '';
          if (status == 'success' || status == 'successful' || status == 'completed') {
            isComplete = true;
            if (mounted) setState(() { _showSuccess = true; _step = 1; _amountCtrl.clear(); _reason = ''; });
          } else if (status == 'failed' || status == 'declined' || status == 'cancelled' || status == 'reversed') {
            isComplete = true;
            if (mounted) setState(() { _errorMsg = res.data['message'] ?? 'Payment was declined or cancelled.'; _showError = true; _step = 1; });
          }
          // 'pending' or anything else → keep polling
        }
      } catch (e) {
        // continue polling
      }

      if (_currentPaymentId != paymentId) return; // double check before state update
      if (mounted) setState(() => _pollAttempt++);
    }

    // Timed out
    if (!isComplete && _currentPaymentId == paymentId && mounted) {
      setState(() {
        // Stop auto-polling, but keep user on step 4 so they can click the check button manually
      });
    }
  }

  /// Manual one-shot check — triggered by "I've Approved" button
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
            backgroundColor: Theme.of(context).primaryColor,
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

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final bank = (_paySettings['bankAccounts'] as List?)?.firstOrNull ?? {};

    return AppLayout(
      title: 'Payment',
      child: Stack(children: [
        Column(children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              // Step Indicator
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Theme.of(context).cardColor.withValues(alpha: 0.5), borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
                child: Row(
                  children: List.generate(4, (i) {
                    final n = i + 1;
                    final labels = ['Type', 'Method', 'Review', 'Verify'];
                    final active = _step >= n;
                    final current = _step == n;
                    
                    return Expanded(
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(child: Divider(thickness: 2, color: i == 0 ? Colors.transparent : (_step >= i ? primary : Colors.grey.shade200))),
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: active ? primary : Colors.grey.shade200,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: _step > n 
                                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                                    : Text('$n', style: TextStyle(color: active ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 11)),
                                ),
                              ),
                              Expanded(child: Divider(thickness: 2, color: i == 3 ? Colors.transparent : (_step > n ? primary : Colors.grey.shade200))),
                            ],
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              labels[i], 
                              style: TextStyle(
                                fontSize: 10, 
                                color: current ? primary : Colors.grey, 
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),

              Padding(padding: const EdgeInsets.all(24), child: _buildStepContent(primary, bank)),
            ]),
          ),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.verified_user, size: 14, color: Colors.grey),
            const SizedBox(width: 6),
            const Flexible(child: Text('Secured by WhitsunPay PCI-DSS Compliance', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600))),
          ]),
        ]),

        // Success Overlay
        if (_showSuccess) _overlay(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 70, height: 70, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF10b981), Color(0xFF059669)]), shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white, size: 36)),
            const SizedBox(height: 16),
            const Text('Payment Confirmed!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Your transaction has been successfully processed.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
            if (_confirmedAmount.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0x1410b981), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0x3310b981))),
                child: Column(children: [
                  const Text('AMOUNT PAID', style: TextStyle(fontSize: 10, color: Color(0xFF10b981), fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text('GH₵ ${double.tryParse(_confirmedAmount)?.toStringAsFixed(2) ?? _confirmedAmount}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                ]),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10b981), padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: () { setState(() => _showSuccess = false); context.go('/payment-history'); },
              child: const Text('View Payment History', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )),
            TextButton(onPressed: () => setState(() => _showSuccess = false), child: const Text('Close')),
          ]),
        ),

        // Error Overlay
        if (_showError) _overlay(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 90, height: 90, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFef4444), Color(0xFFdc2626)]), shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 48)),
            const SizedBox(height: 24),
            const Text('Transaction Failed', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_errorMsg, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: () => setState(() => _showError = false),
              child: const Text('Try Again', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )),
          ]),
        ),
      ]),
    );
  }

  Widget _overlay({required Widget child}) {
    return Positioned.fill(child: Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 60)]),
        child: SingleChildScrollView(child: child),
      )),
    ));
  }

  Widget _buildStepContent(Color primary, dynamic bank) {
    if (_step == 1) {
      if (_loadingData) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: CircularProgressIndicator(),
          ),
        );
      }
      return Column(children: [
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
        const SizedBox(height: 16),
        TextField(
          controller: _amountCtrl,
          onChanged: (v) => setState(() {}), // Trigger rebuild to enable button
          keyboardType: TextInputType.number,
          readOnly: _reason.isNotEmpty && _reason != 'Other',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            labelText: 'Amount to Pay',
            prefixText: '₵ ',
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primary, width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
          onPressed: _reason.isEmpty || _amountCtrl.text.isEmpty ? null : () => setState(() => _step = 2),
          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Continue to Methods ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), Icon(Icons.arrow_forward, color: Colors.white)]),
        )),
      ]);
    }

    if (_step == 2) {
      return Column(children: [
        const Text('PREFERRED METHOD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _methodCard('momo', Icons.smartphone, 'Mobile Money', primary)),
          const SizedBox(width: 14),
          Expanded(child: _methodCard('bank', Icons.account_balance, 'Bank Transfer', primary)),
        ]),
        const SizedBox(height: 20),
        if (_method == 'momo') ...[
          CustomDropdown<String>(
            value: _momoNetwork,
            hint: 'Please select your mobile money network',
            items: const [
              DropdownItem(value: 'MTN', label: 'MTN MoMo'),
              DropdownItem(value: 'Vodafone', label: 'Telecel (Vodafone)'),
              DropdownItem(value: 'AirtelTigo', label: 'AT (AirtelTigo)'),
            ],
            onChanged: (v) => setState(() => _momoNetwork = v),
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) { _momoPhone = v; setState(() {}); },
            keyboardType: TextInputType.phone,
            maxLength: 10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'MoMo Phone Number',
              hintText: '024XXXXXXX',
              counterText: "",
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primary, width: 2)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ],
        if (_method == 'bank') ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).dividerColor)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('CUBAG OFFICIAL BANK ACCOUNT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primary)),
              const SizedBox(height: 8),
              _bankRow('Bank', bank['bankName']?.toString() ?? '—'),
              _bankRow('A/C Number', bank['accountNumber']?.toString() ?? '—'),
              _bankRow('Branch', bank['branch']?.toString() ?? '—'),
            ]),
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) { _bankTxId = v; setState(() {}); },
            decoration: InputDecoration(
              labelText: 'Transaction ID / Ref',
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primary, width: 2)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = 1), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Back'))),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: ElevatedButton(
            onPressed: (_method == 'momo' && (_momoNetwork.isEmpty || _momoPhone.trim().length != 10)) ||
                       (_method == 'bank' && _bankTxId.trim().isEmpty)
                ? null
                : () => setState(() => _step = 3),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, minimumSize: const Size(0, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
            child: const Text('Review Summary', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          )),
        ]),
      ]);
    }

    if (_step == 3) {
      final methodLabel = _method == 'momo' ? (_momoNetwork.isNotEmpty ? 'Mobile Money ($_momoNetwork)' : 'Mobile Money') : 'Bank Transfer';
      return Column(children: [
        Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).dividerColor)),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(gradient: LinearGradient(colors: [primary, primary.withValues(alpha: 0.75)]), borderRadius: const BorderRadius.vertical(top: Radius.circular(15))),
              child: const Text('ORDER SUMMARY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            ...[
              {'label': 'Category', 'value': _reason, 'highlight': false},
              {'label': 'Payment Method', 'value': methodLabel, 'highlight': false},
              {'label': 'Total Payable', 'value': 'GH₵ ${double.tryParse(_amountCtrl.text)?.toStringAsFixed(2) ?? _amountCtrl.text}', 'highlight': true},
            ].map((row) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(row['label']! as String, style: const TextStyle(color: Colors.grey)),
                Text(row['value']! as String, style: TextStyle(fontWeight: (row['highlight'] as bool) ? FontWeight.bold : FontWeight.w600, color: (row['highlight'] as bool) ? primary : null, fontSize: (row['highlight'] as bool) ? 18 : 14)),
              ]),
            )),
          ]),
        ),
        const SizedBox(height: 20),
        Row(children: [
          OutlinedButton(onPressed: () => setState(() => _step = 2), style: OutlinedButton.styleFrom(minimumSize: const Size(52, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Icon(Icons.arrow_back)),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton(
            onPressed: _loading ? null : _submitPayment,
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, minimumSize: const Size(0, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
            child: _loading ? const CircularProgressIndicator(color: Colors.white) : Text(_method == 'momo' ? 'Initiate Payment' : 'Confirm Payment', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          )),
        ]),
      ]);
    }

    // Step 4 — Waiting for MoMo PIN approval
    final remaining = (_pollMax - _pollAttempt) * 5;
    final progressVal = _pollMax > 0 ? _pollAttempt / _pollMax : 0.0;

    return Column(children: [
      // Repeating pulsing icon
      AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, child) => Transform.scale(scale: _pulseAnim.value, child: child),
        child: Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [primary.withValues(alpha: 0.6), primary]),
          ),
          child: const Icon(Icons.phone_android, color: Colors.white, size: 36),
        ),
      ),
      const SizedBox(height: 20),
      const Text('Awaiting Approval', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(
        'A MoMo prompt has been sent to $_momoPhone.\nOpen your phone and enter your PIN to approve.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.grey, height: 1.5),
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primary.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.info, color: primary, size: 14),
            SizedBox(width: 6),
            Text('MTN MoMo Approval Notice', style: TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.bold)),
          ]),
          SizedBox(height: 4),
          Text(
            'If the prompt does not popup, please dial *170# -> Option 6 (My Wallet) -> Option 3 (My Approvals) on your phone to approve.',
            style: TextStyle(color: Colors.black87, fontSize: 11, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ]),
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

      // Progress bar
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: progressVal,
          minHeight: 6,
          backgroundColor: primary.withValues(alpha: 0.1),
          valueColor: AlwaysStoppedAnimation<Color>(primary),
        ),
      ),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Checking... (attempt ${_pollAttempt + 1}/$_pollMax)', style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text('~${remaining}s left', style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ]),

      const SizedBox(height: 24),

      // Manual check button
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _manualChecking ? null : _manualStatusCheck,
          icon: _manualChecking
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_circle_outline, color: Colors.white),
          label: Text(_manualChecking ? 'Checking...' : "I've Approved — Check Now",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      ),
      const SizedBox(height: 10),
      TextButton(
        onPressed: () => setState(() { _step = 2; _pollAttempt = 0; _currentTxRef = ''; }),
        child: const Text('Cancel & Change Method', style: TextStyle(color: Colors.grey)),
      ),
    ]);
  }

  Widget _methodCard(String id, IconData icon, String label, Color primary) {
    final selected = _method == id;
    return GestureDetector(
      onTap: () => setState(() => _method = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(border: Border.all(color: selected ? primary : Colors.grey.shade300, width: selected ? 2.5 : 1.5), borderRadius: BorderRadius.circular(16), color: selected ? primary.withValues(alpha: 0.05) : null),
        child: Column(children: [
          Icon(icon, size: 32, color: selected ? primary : Colors.grey),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: selected ? primary : Colors.grey.shade700)),
        ]),
      ),
    );
  }

  Widget _bankRow(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: Colors.grey)), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]));
  }
}
