import 'package:flutter/material.dart';
import '../components/app_layout.dart';
import '../components/custom_dropdown.dart';
import '../components/shimmer_loader.dart';
import '../services/api_service.dart';

class PaymentHistoryPage extends StatefulWidget {
  const PaymentHistoryPage({super.key});
  @override
  State<PaymentHistoryPage> createState() => _PaymentHistoryPageState();
}

class _PaymentHistoryPageState extends State<PaymentHistoryPage> {
  bool _loading = true;
  List<dynamic> _payments = [];
  String _filter = 'all';
  int _page = 1;
  static const int _pageSize = 10;
  dynamic _verifyingId;

  final Map<String, Map<String, dynamic>> _statusColors = {
    'paid':    {'color': const Color(0xFF10b981), 'bg': const Color(0x1910b981), 'icon': Icons.check_circle},
    'pending': {'color': const Color(0xFFf59e0b), 'bg': const Color(0x19f59e0b), 'icon': Icons.pending_actions},
    'failed':  {'color': const Color(0xFFef4444), 'bg': const Color(0x19ef4444), 'icon': Icons.cancel},
    'overdue': {'color': const Color(0xFFef4444), 'bg': const Color(0x19ef4444), 'icon': Icons.cancel},
  };

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (!_loading) setState(() => _loading = true);
    await ApiService().fetchDataWithCache('/payments', (data, isCached, {bool hasError = false}) {
      if (mounted && data != null) {
        setState(() {
          _payments = ApiService.ensureList(data);
          _loading = false;
        });
      }
    });
  }

  String _fmt(double n) => n.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final filtered = _filter == 'all' ? _payments : _payments.where((p) => p['status'] == _filter).toList();
    final totalPages = (filtered.length / _pageSize).ceil().clamp(1, 999);
    final paginated = filtered.skip((_page - 1) * _pageSize).take(_pageSize).toList();

    final paidTotal = _payments.where((p) => p['status'] == 'paid').fold(0.0, (s, p) => s + (double.tryParse(p['amount'].toString()) ?? 0));
    final pendingTotal = _payments.where((p) => p['status'] == 'pending').fold(0.0, (s, p) => s + (double.tryParse(p['amount'].toString()) ?? 0));
    final failedTotal = _payments.where((p) => p['status'] == 'failed' || p['status'] == 'overdue').fold(0.0, (s, p) => s + (double.tryParse(p['amount'].toString()) ?? 0));

    return AppLayout(
      title: 'Payment Records',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Align(alignment: Alignment.centerRight, child: IconButton(icon: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh), onPressed: _fetch)),
        const SizedBox(height: 4),

        // KPI Cards
        _kpiCard(Icons.check_circle, const Color(0xFF10b981), 'Total Paid', 'GH₵ ${_fmt(paidTotal)}'),
        const SizedBox(height: 10),
        _kpiCard(Icons.pending_actions, const Color(0xFFf59e0b), 'Pending Approval', 'GH₵ ${_fmt(pendingTotal)}'),
        const SizedBox(height: 10),
        _kpiCard(Icons.cancel, const Color(0xFFef4444), 'Failed Actions', 'GH₵ ${_fmt(failedTotal)}'),
        const SizedBox(height: 10),
        _kpiCard(Icons.receipt_long, primary, 'Total Transactions', '${_payments.length} txns'),
        const SizedBox(height: 16),

        // Filter
        CustomDropdown<String>(
          value: _filter,
          items: const [
            DropdownItem(value: 'all', label: 'All Transactions'),
            DropdownItem(value: 'paid', label: 'Paid'),
            DropdownItem(value: 'pending', label: 'Pending'),
            DropdownItem(value: 'failed', label: 'Failed'),
            DropdownItem(value: 'overdue', label: 'Overdue'),
          ],
          onChanged: (v) => setState(() { _filter = v; _page = 1; }),
          prefixIcon: const Icon(Icons.filter_list),
        ),
        const SizedBox(height: 16),

        // Transaction List
        if (_loading && paginated.isEmpty)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            separatorBuilder: (ctx, i) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) => const ShimmerListTile(),
          )
        else if (paginated.isEmpty)
          Container(padding: const EdgeInsets.all(60), alignment: Alignment.center, decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)), child: Column(children: [const Icon(Icons.receipt_long, size: 48, color: Colors.grey), const SizedBox(height: 12), Text(_filter == 'all' ? 'Your payment history is currently empty.' : 'No $_filter payments found.', style: const TextStyle(color: Colors.grey))]))
        else
          Column(children: paginated.map((pay) {
            final s = _statusColors[pay['status']] ?? _statusColors['pending']!;
            final color = s['color'] as Color;
            final bg = s['bg'] as Color;
            final icon = s['icon'] as IconData;
            final amount = double.tryParse(pay['amount'].toString()) ?? 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
              child: Row(children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 22)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(pay['description']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis)),
                    Text('GH₵ ${_fmt(amount)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text(pay['created_at'] != null ? DateTime.tryParse(pay['created_at'].toString())?.toLocal().toString().split(' ').first ?? '' : '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(width: 8),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)), child: Text((pay['status']?.toString() ?? '').toUpperCase(), style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold))),
                    const Spacer(),
                    if (pay['status'] == 'pending')
                      InkWell(
                        onTap: _verifyingId == pay['id'] ? null : () async {
                          setState(() => _verifyingId = pay['id']);
                          try {
                            final res = await ApiService().get('/payments/verify/${pay['payment_ref']}');
                            if (res.data['status'] == 'success') _fetch();
                          } catch (_) {}
                          setState(() => _verifyingId = null);
                        },
                        child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(6)), child: _verifyingId == pay['id'] ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)) : Text('Check Status', style: TextStyle(fontSize: 11, color: primary, fontWeight: FontWeight.bold))),
                      ),
                  ]),
                ])),
              ]),
            );
          }).toList()),

        // Pagination
        if (totalPages > 1) ...[
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(icon: const Icon(Icons.arrow_back), onPressed: _page > 1 ? () => setState(() => _page--) : null),
            ...List.generate(totalPages, (i) => i + 1).map((n) => GestureDetector(
              onTap: () => setState(() => _page = n),
              child: Container(margin: const EdgeInsets.symmetric(horizontal: 4), width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: _page == n ? primary : Theme.of(context).cardColor, borderRadius: BorderRadius.circular(8)), child: Text('$n', style: TextStyle(color: _page == n ? Colors.white : null, fontWeight: FontWeight.bold))),
            )),
            IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _page < totalPages ? () => setState(() => _page++) : null),
          ]),
        ],
      ]),
    );
  }

  Widget _kpiCard(IconData icon, Color color, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, border: Border.all(color: color.withValues(alpha: 0.25)), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 24)),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        ]),
      ]),
    );
  }
}
