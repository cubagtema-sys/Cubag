import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1e293b) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0);
    final textColor = isDark ? const Color(0xFFf8fafc) : const Color(0xFF0f172a);
    final subTextColor = isDark ? const Color(0xFF94a3b8) : const Color(0xFF475569);

    return AppLayout(
      title: 'Platform Fees',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _addFee,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text('Add Fee', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ]),
        const SizedBox(height: 20),

        if (_success) _banner('Fee configuration saved!', _kGreen, isDark, borderColor),
        if (_error.isNotEmpty) _banner(_error, _kRed, isDark, borderColor),

        if (_fetching)
          const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator(color: _kOrange)),
          )
        else if (_fees.isEmpty) 
          Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              color: cardBg,
              border: Border.all(color: borderColor), 
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(child: Column(children: [
              Icon(Icons.payments_outlined, size: 48, color: subTextColor.withValues(alpha: 0.5)), 
              const SizedBox(height: 12), 
              Text(
                'No fees configured yet. Click "Add Fee" to start.', 
                style: GoogleFonts.outfit(color: subTextColor, fontWeight: FontWeight.bold),
              ),
            ])),
          ),

        ...List.generate(_fees.length, (i) {
          final fee = _fees[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg, 
              borderRadius: BorderRadius.circular(16), 
              border: Border.all(color: borderColor), 
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02), blurRadius: 10, offset: const Offset(0, 4))
              ]
            ),
            child: Column(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Fee Name', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: subTextColor)),
                  const SizedBox(height: 6),
                  TextFormField(
                    initialValue: fee['label'],
                    style: GoogleFonts.outfit(fontSize: 14, color: textColor),
                    decoration: InputDecoration(
                      hintText: 'e.g. Annual Subscription',
                      hintStyle: GoogleFonts.outfit(fontSize: 13, color: subTextColor),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0f172a).withValues(alpha: 0.4) : const Color(0xFFf8fafc),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kOrange, width: 2)),
                    ),
                    onChanged: (v) => _fees[i]['label'] = v,
                  ),
                ])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Amount (GH₵)', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: subTextColor)),
                  const SizedBox(height: 6),
                  TextFormField(
                    initialValue: fee['amount'].toString(),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.outfit(color: _kOrange, fontWeight: FontWeight.bold, fontSize: 14),
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0f172a).withValues(alpha: 0.4) : const Color(0xFFf8fafc),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kOrange, width: 2)),
                    ),
                    onChanged: (v) => _fees[i]['amount'] = v,
                  ),
                ])),
                const SizedBox(width: 12),
                Container(
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(
                    color: _kRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: _kRed, size: 20), 
                    onPressed: () => _removeFee(fee['id']),
                    tooltip: 'Remove Fee',
                  ),
                ),
              ]),
            ]),
          );
        }),

        if (_fees.isNotEmpty) ...[
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(
            onPressed: _loading ? null : _save,
            icon: _loading 
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                : const Icon(Icons.save_rounded, size: 18),
            label: Text(_loading ? 'Saving Changes...' : 'Save All Fees', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          )),
        ],
        const SizedBox(height: 40),
      ]),
    );
  }

  Widget _banner(String msg, Color color, bool isDark, Color borderColor) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1), 
      borderRadius: BorderRadius.circular(12), 
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Row(children: [
      Icon(Icons.info_outline_rounded, color: color, size: 20), 
      const SizedBox(width: 10), 
      Expanded(child: Text(msg, style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.bold))),
    ]),
  );
}
