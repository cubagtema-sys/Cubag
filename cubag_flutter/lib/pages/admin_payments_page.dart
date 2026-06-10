import 'dart:async';
import 'package:flutter/material.dart';
import '../components/app_layout.dart';
import '../components/custom_dropdown.dart';
import '../services/api_service.dart';
import '../components/shimmer_loader.dart';

class AdminPaymentsPage extends StatefulWidget {
  const AdminPaymentsPage({super.key});
  @override
  State<AdminPaymentsPage> createState() => _AdminPaymentsPageState();
}

class _AdminPaymentsPageState extends State<AdminPaymentsPage> {
  bool _loading = true;
  bool _loadingMore = false;
  Map<String, dynamic> _kpis = {'revenue': 0, 'pending': 0, 'failed': 0};
  List<dynamic> _transactions = [];
  String _search = '';
  String _filterStatus = 'all';
  int _page = 1;
  int _total = 0;
  bool _hasMore = true;
  bool _actionLoading = false;

  Timer? _debounce;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() { 
    super.initState(); 
    _fetch(); 
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_loading && !_loadingMore && _hasMore) {
        _fetchMore();
      }
    }
  }

  Future<void> _fetch({bool refresh = false}) async {
    if (!mounted) return;
    if (refresh) {
      setState(() { _page = 1; _hasMore = true; _loading = true; _transactions = []; });
    } else {
      if (!_loading) setState(() => _loading = true);
    }
    
    await ApiService().fetchDataWithCache('/payments/admin/all?page=$_page&limit=20&search=$_search&status=$_filterStatus', (data, isCached) {
      if (mounted && data != null) {
        final d = data as Map<String, dynamic>;
        setState(() { 
          _loading = false;
          _kpis = d['kpis'] ?? _kpis; 
          _transactions = ApiService.ensureList(d);
          if (d.containsKey('total')) {
            _total = d['total'];
            _hasMore = _transactions.length < _total;
          } else {
            _hasMore = false;
          }
        });
      }
    });
  }

  Future<void> _fetchMore() async {
    setState(() => _loadingMore = true);
    _page++;
    try {
      final res = await ApiService().get('/payments/admin/all?page=$_page&limit=20&search=$_search&status=$_filterStatus');
      if (res.statusCode == 200) {
        final d = res.data as Map<String, dynamic>;
        final newItems = ApiService.ensureList(d);
        setState(() {
          _transactions.addAll(newItems);
          if (d.containsKey('total')) {
            _hasMore = _transactions.length < d['total'];
          } else {
            _hasMore = newItems.isNotEmpty;
          }
        });
      }
    } catch (_) { _page--; }
    if (mounted) setState(() => _loadingMore = false);
  }

  void _onSearchChanged(String v) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _search = v);
        _fetch(refresh: true);
      }
    });
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF10b981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _markPaid(dynamic id) async {
    setState(() => _actionLoading = true);
    // Optimistic Update
    final index = _transactions.indexWhere((t) => t['tx_id'] == id);
    if (index != -1) {
      setState(() {
        _transactions[index]['status'] = 'paid';
      });
    }

    try {
      final res = await ApiService().post('/payments/admin/mark-paid/$id');
      if (res.statusCode == 200) {
        _showToast('Payment confirmed successfully.');
        _fetch(refresh: true); // fetch again to update KPIs
      }
    } catch (_) {
      // Revert Optimistic
      if (index != -1) setState(() => _transactions[index]['status'] = 'pending');
      _showToast('Network error. Try again.');
    }
    if (mounted) setState(() => _actionLoading = false);
  }

  /// Show confirmation dialog using Navigator overlay (not inline Stack).
  void _showConfirmDialog(dynamic txId, double amount, String memberName) {
    final primary = Theme.of(context).primaryColor;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 56, height: 56,
            decoration: const BoxDecoration(color: Color(0x1910b981), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle, color: Color(0xFF10b981), size: 28),
          ),
          const SizedBox(height: 16),
          const Text('Confirm Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          Text(
            'Mark ₵${amount.toStringAsFixed(2)} from $memberName as RECEIVED?\nThis will update the member\'s balance.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _actionLoading ? null : () {
                  Navigator.of(ctx).pop();
                  _markPaid(txId);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  elevation: 0,
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Confirm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  /// Show transaction details as a proper bottom sheet (renders above scroll view).
  void _showDetailSheet(Map<String, dynamic> tx) {
    final primary = Theme.of(context).primaryColor;
    final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0;
    final status = tx['status']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 20, offset: const Offset(0, -4))],
        ),
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 40),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Handle bar
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 16),

          // Header
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: primary.withAlpha(20), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.receipt_long, color: primary, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Transaction Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
            IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.of(ctx).pop()),
          ]),
          const SizedBox(height: 4),
          const Divider(),
          const SizedBox(height: 8),

          // Amount + Status hero
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [primary, primary.withValues(alpha: 0.7)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('AMOUNT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text('₵${amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'monospace')),
              const SizedBox(height: 8),
              _StatusBadge(status: status),
            ]),
          ),
          const SizedBox(height: 16),

          // Detail rows
          ...[
            ['Transaction ID', tx['tx_id']?.toString() ?? '—'],
            ['Member Name',    tx['member_name']?.toString() ?? '—'],
            ['Reference',      tx['payment_ref']?.toString() ?? 'N/A'],
            ['Description',    tx['description']?.toString() ?? '—'],
            ['Date',           tx['date']?.toString() ?? '—'],
          ].map((row) => _DetailRow(label: row[0], value: row[1])),

          const SizedBox(height: 16),

          // Close button
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Close', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }

  Map<String, dynamic> _statusMeta(String status) {
    switch (status) {
      case 'paid':    return {'color': const Color(0xFF10b981), 'bg': const Color(0x1910b981)};
      case 'pending': return {'color': const Color(0xFFf59e0b), 'bg': const Color(0x19f59e0b)};
      default:        return {'color': const Color(0xFFef4444), 'bg': const Color(0x19ef4444)};
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final revenue = double.tryParse(_kpis['revenue']?.toString() ?? '0') ?? 0;

    return AppLayout(
      title: 'Financial Center',
      scrollable: false,
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Revenue Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [primary, primary.withValues(alpha: 0.7)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('TOTAL REVENUE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text('₵${revenue.toStringAsFixed(2)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'monospace')),
              const SizedBox(height: 6),
              Row(children: [
                _KpiChip(label: 'Pending', value: _kpis['pending']?.toString() ?? '0', color: const Color(0xFFf59e0b)),
                const SizedBox(width: 10),
                _KpiChip(label: 'Failed', value: _kpis['failed']?.toString() ?? '0', color: const Color(0xFFef4444)),
              ]),
            ]),
          ),
          const SizedBox(height: 16),

          // Search + Filter row
          Row(children: [
            Expanded(
              flex: 3,
              child: TextField(
                onChanged: _onSearchChanged,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 18),
                  hintText: 'Search by name or description...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748b)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primary, width: 2)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: CustomDropdown<String>(
                value: _filterStatus,
                prefixIcon: const Icon(Icons.payments_outlined, size: 16, color: Color(0xFF64748b)),
                items: const [
                  DropdownItem(value: 'all',     label: 'All Statuses'),
                  DropdownItem(value: 'paid',    label: 'Paid'),
                  DropdownItem(value: 'pending', label: 'Pending'),
                  DropdownItem(value: 'overdue', label: 'Overdue'),
                ],
                onChanged: (v) => setState(() { _filterStatus = v; _fetch(refresh: true); }),
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // Transaction Cards
          if (_loading)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 8,
              separatorBuilder: (ctx, i) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) => const ShimmerListTile(),
            )
          else if (_transactions.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              child: Column(children: [
                Icon(Icons.payments_outlined, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                const Text('No payment records found.', style: TextStyle(color: Colors.grey)),
              ]),
            )
          else
            ..._transactions.map((tx) {
              final sm     = _statusMeta(tx['status']?.toString() ?? '');
              final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    // Avatar initials
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: primary.withAlpha(20), shape: BoxShape.circle),
                      child: Center(child: Text(
                        (tx['member_name']?.toString() ?? '?').substring(0, 1).toUpperCase(),
                        style: TextStyle(fontWeight: FontWeight.bold, color: primary, fontSize: 16),
                      )),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tx['member_name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
                      Text('ID: ${tx['tx_id']?.toString() ?? ''}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('₵${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: sm['bg'] as Color, borderRadius: BorderRadius.circular(4)),
                        child: Text((tx['status']?.toString() ?? '').toUpperCase(), style: TextStyle(fontSize: 9, color: sm['color'] as Color, fontWeight: FontWeight.bold)),
                      ),
                    ]),
                  ]),
                  if ((tx['description']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.circular(8)),
                      child: Text(tx['description'].toString(), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(children: [
                    if (tx['status'] == 'pending')
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _actionLoading ? null : () => _showConfirmDialog(tx['tx_id'], amount, tx['member_name']?.toString() ?? ''),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            elevation: 0,
                            minimumSize: const Size(0, 40),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
                          label: const Text('Approve', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    if (tx['status'] == 'pending') const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showDetailSheet(Map<String, dynamic>.from(tx)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.open_in_new, size: 15),
                        label: const Text('View Details', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ]),
                ]),
              );
            }),
            if (_loadingMore) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
            if (!_loading) Center(child: Text('${_transactions.length} payments shown${_total > 0 ? " of $_total" : ""}', style: const TextStyle(fontSize: 12, color: Colors.grey))),
        ]),
      )
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    Color bg;
    switch (status) {
      case 'paid':    color = const Color(0xFF10b981); bg = const Color(0x4010b981); break;
      case 'pending': color = const Color(0xFFf59e0b); bg = const Color(0x40f59e0b); break;
      default:        color = const Color(0xFFef4444); bg = const Color(0x40ef4444);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5)),
    );
  }
}

// ── Detail row ────────────────────────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF94a3b8))),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF0f172a)))),
      ]),
    );
  }
}

// ── KPI chip on banner ────────────────────────────────────────────────────────
class _KpiChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _KpiChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text('$value $label', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}pha(30), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text('$value $label', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
