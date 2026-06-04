import 'package:flutter/material.dart';
import '../components/app_layout.dart';
import '../services/api_service.dart';

const _kOrange = Color(0xFFf08232);
const _kGreen  = Color(0xFF10b981);
const _kBlue   = Color(0xFF3b82f6);

class AdminPaymentSettingsPage extends StatefulWidget {
  const AdminPaymentSettingsPage({super.key});
  @override State<AdminPaymentSettingsPage> createState() => _State();
}

class _State extends State<AdminPaymentSettingsPage> {
  final _api = ApiService();
  bool _loading = false, _success = false;
  bool _fetching = true;

  List<Map<String, dynamic>> _banks = [
    {'bankName': '', 'accountName': '', 'accountNumber': '', 'branch': ''}
  ];

  @override void initState() { super.initState(); _fetchSettings(); }

  Future<void> _fetchSettings() async {
    setState(() => _fetching = true);
    try {
      final data = await _api.getPublic('settings/cubag_payment_settings_v2');
      if (mounted && data is Map && data['bankAccounts'] is List) {
        setState(() => _banks = (data['bankAccounts'] as List).map((item) => Map<String, dynamic>.from(item as Map)).toList());
      }
    } catch (_) {}
    if (mounted) setState(() => _fetching = false);
  }

  void _addBank() => setState(() => _banks.add({'bankName': '', 'accountName': '', 'accountNumber': '', 'branch': ''}));
  void _removeBank(int i) => setState(() => _banks.removeAt(i));

  Future<void> _save() async {
    setState(() { _loading = true; _success = false; });
    await _api.postData('settings/cubag_payment_settings_v2', {'bankAccounts': _banks});
    setState(() { _loading = false; _success = true; });
    Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _success = false); });
  }

  @override
  Widget build(BuildContext context) => AppLayout(
    title: 'Regulations',
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Collection Settings', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          SizedBox(height: 4),
          Text('Manage MoMo and Bank details for renewals.', style: TextStyle(color: Colors.grey, fontSize: 13)),
        ])),
        ElevatedButton.icon(
          onPressed: _addBank,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Bank'),
          style: ElevatedButton.styleFrom(backgroundColor: _kBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        ),
      ]),
      const SizedBox(height: 16),

      if (_success) Container(
        margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _kGreen.withAlpha(25), borderRadius: BorderRadius.circular(10), border: Border.all(color: _kGreen.withAlpha(50))),
        child: Row(children: [const Icon(Icons.check_circle_outline, color: _kGreen, size: 18), const SizedBox(width: 8), const Text('Settings updated!', style: TextStyle(color: _kGreen, fontWeight: FontWeight.w700))]),
      ),

      if (_fetching)
        const Padding(
          padding: EdgeInsets.all(48),
          child: Center(child: CircularProgressIndicator(color: _kOrange)),
        )
      else ...[
        // Bank sections
        const Text('BANK DETAILS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _kBlue, letterSpacing: 1)),
        const SizedBox(height: 12),

        ..._banks.asMap().entries.map((e) {
          final i = e.key;
          final b = e.value;
          return Container(
            key: ObjectKey(b),
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 6)]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('Bank Account ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                const Spacer(),
                if (_banks.length > 1) IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _removeBank(i)),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _field('Bank Name', b['bankName'] ?? '', (v) => setState(() => _banks[i]['bankName'] = v))),
                const SizedBox(width: 12),
                Expanded(child: _field('Branch', b['branch'] ?? '', (v) => setState(() => _banks[i]['branch'] = v))),
              ]),
              const SizedBox(height: 12),
              _field('Account Name', b['accountName'] ?? '', (v) => setState(() => _banks[i]['accountName'] = v)),
              const SizedBox(height: 12),
              _field('Account Number', b['accountNumber'] ?? '', (v) => setState(() => _banks[i]['accountNumber'] = v), keyboardType: TextInputType.number),
            ]),
          );
        }),

        const SizedBox(height: 8),
        SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
          onPressed: _loading ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: _kOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26))),
          child: Text(_loading ? 'Saving...' : 'Save Settings', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        )),
      ],
    ]),
  );

  Widget _field(String label, String value, void Function(String) onChange, {TextInputType keyboardType = TextInputType.text}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Colors.grey)),
    const SizedBox(height: 6),
    TextFormField(
      initialValue: value,
      keyboardType: keyboardType,
      decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.all(12)),
      onChanged: onChange,
    ),
  ]);
}
