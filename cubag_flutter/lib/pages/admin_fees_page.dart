import 'package:flutter/material.dart';
import '../components/app_layout.dart';
import '../services/api_service.dart';

const _kOrange = Color(0xFFf08232);
const _kGreen  = Color(0xFF10b981);
const _kRed    = Color(0xFFef4444);

class AdminFeesPage extends StatefulWidget {
  const AdminFeesPage({super.key});
  @override State<AdminFeesPage> createState() => _State();
}

class _State extends State<AdminFeesPage> {
  final _api = ApiService();
  List<Map<String, dynamic>> _fees = [];
  bool _loading = false;
  bool _success = false;
  bool _fetching = true;
  String _error = '';

  @override void initState() { super.initState(); _fetchFees(); }

  Future<void> _fetchFees() async {
    setState(() => _fetching = true);
    try {
      final data = await _api.getPublic('settings/cubag_fees_v2');
      if (mounted && data is List) {
        setState(() => _fees = data.map((item) => Map<String, dynamic>.from(item as Map)).toList());
      }
    } catch (_) {}
    if (mounted) setState(() => _fetching = false);
  }

  void _addFee() => setState(() => _fees.add({'id': DateTime.now().millisecondsSinceEpoch, 'label': '', 'amount': '0.00'}));
  void _removeFee(int id) => setState(() => _fees.removeWhere((f) => f['id'] == id));

  Future<void> _save() async {
    if (_fees.any((f) => (f['label'] as String).trim().isEmpty)) {
      setState(() => _error = 'All fees must have a name.'); return;
    }
    setState(() { _loading = true; _success = false; _error = ''; });
    await _api.postData('settings/cubag_fees_v2', _fees);
    setState(() { _loading = false; _success = true; });
    Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _success = false); });
  }

  @override
  Widget build(BuildContext context) => AppLayout(
    title: 'Platform Fees',
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Spacer(),
        ElevatedButton.icon(
          onPressed: _addFee,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Fee'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kOrange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
            minimumSize: const Size(0, 40),
          ),
        ),
      ]),
      const SizedBox(height: 16),

      if (_success) _banner('Fee configuration saved!', _kGreen),
      if (_error.isNotEmpty) _banner(_error, _kRed),

      if (_fetching)
        const Padding(
          padding: EdgeInsets.all(48),
          child: Center(child: CircularProgressIndicator(color: _kOrange)),
        )
      else if (_fees.isEmpty) Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid), borderRadius: BorderRadius.circular(16), color: Colors.grey.shade50),
        child: const Center(child: Column(children: [Icon(Icons.payments_outlined, size: 48, color: Colors.grey), SizedBox(height: 12), Text('No fees configured yet. Click "Add Fee" to start.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600))])),
      ),

      ...List.generate(_fees.length, (i) {
        final fee = _fees[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 6)]),
          child: Column(children: [
            Row(children: [
              Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Fee Name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey)),
                const SizedBox(height: 6),
                TextFormField(
                  initialValue: fee['label'],
                  decoration: InputDecoration(
                    hintText: 'e.g. Annual Subscription',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748b)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kOrange, width: 2)),
                  ),
                  onChanged: (v) => _fees[i]['label'] = v,
                ),
              ])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Amount (GH₵)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey)),
                const SizedBox(height: 6),
                TextFormField(
                  initialValue: fee['amount'].toString(),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kOrange, width: 2)),
                  ),
                  style: const TextStyle(color: _kOrange, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.right,
                  onChanged: (v) => _fees[i]['amount'] = v,
                ),
              ])),
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.delete_outline, color: _kRed), onPressed: () => _removeFee(fee['id'])),
            ]),
          ]),
        );
      }),

      if (_fees.isNotEmpty) ...[
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
          onPressed: _loading ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kOrange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: Text(_loading ? 'Saving Changes...' : 'Save All Fees', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        )),
      ],
    ]),
  );

  Widget _banner(String msg, Color color) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withAlpha(50))),
    child: Row(children: [Icon(Icons.check_circle_outline, color: color, size: 18), const SizedBox(width: 8), Text(msg, style: TextStyle(color: color, fontWeight: FontWeight.w700))]),
  );
}
