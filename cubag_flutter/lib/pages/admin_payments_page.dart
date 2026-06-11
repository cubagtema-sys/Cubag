import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../components/app_layout.dart';
import '../components/custom_dropdown.dart';
import '../services/api_service.dart';
import '../components/fetch_error_view.dart';
import '../components/shimmer_loader.dart';

const _kOrange = Color(0xFFf08232);
const _kGreen  = Color(0xFF10b981);
const _kAmber  = Color(0xFFf59e0b);
const _kRed    = Color(0xFFef4444);

class AdminPaymentsPage extends StatefulWidget {
  const AdminPaymentsPage({super.key});
  @override
  State<AdminPaymentsPage> createState() => _AdminPaymentsPageState();
}

class _AdminPaymentsPageState extends State<AdminPaymentsPage> {
  bool _loading = true;
  bool _hasError = false;
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
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetch({bool refresh = false, int? page}) async {
    if (!mounted) return;
    if (page != null) {
      _page = page;
    } else if (refresh) _page = 1;

    setState(() { 
      _loading = true; 
      _hasError = false; 
      if (refresh || page != null) {
        _transactions = []; 
      }
    });
    
    await ApiService().fetchDataWithCache('/payments/admin/all?page=$_page&limit=20&search=$_search&status=$_filterStatus', (data, isCached, {bool hasError = false}) {
      if (!mounted) return;
      if (hasError && _transactions.isEmpty) {
        setState(() { _loading = false; _hasError = true; });
        return;
      }
      if (data == null) { setState(() => _loading = false); return; }
      final d = data as Map<String, dynamic>;
      setState(() { 
        _loading = false;
        _kpis = d['kpis'] ?? _kpis; 
        _transactions = ApiService.ensureList(d);
        if (d.containsKey('total')) {
          _total = d['total'];
          _hasMore = (_page * 20) < _total;
        } else {
          _hasMore = false;
        }
      });
    });
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
        content: Text(msg, style: GoogleFonts.outfit(fontWeight: FontWeight.w500)),
        backgroundColor: _kGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  void _showConfirmDialog(dynamic txId, double amount, String memberName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1e293b) : Colors.white;
    final textColor = isDark ? const Color(0xFFf8fafc) : const Color(0xFF0f172a);
    final subTextColor = isDark ? const Color(0xFF94a3b8) : const Color(0xFF475569);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: _kGreen.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded, color: _kGreen, size: 28),
          ),
          const SizedBox(height: 16),
          Text('Confirm Payment', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
          const SizedBox(height: 8),
          Text(
            'Mark ₵${amount.toStringAsFixed(2)} from $memberName as RECEIVED?\nThis will update the member\'s balance.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: subTextColor, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  side: BorderSide(color: subTextColor.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Cancel', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor)),
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
                  backgroundColor: _kGreen,
                  elevation: 0,
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Confirm', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  void _showDetailSheet(Map<String, dynamic> tx) {
    final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0;
    final status = tx['status']?.toString() ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1e293b) : Colors.white;
    final textColor = isDark ? const Color(0xFFf8fafc) : const Color(0xFF0f172a);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, -4))],
        ),
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 40),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Handle bar
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 16),

          // Header
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: _kOrange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.receipt_long_rounded, color: _kOrange, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('Transaction Details', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: textColor))),
            IconButton(icon: Icon(Icons.close_rounded, size: 20, color: textColor), onPressed: () => Navigator.of(ctx).pop()),
          ]),
          const SizedBox(height: 12),
          Divider(color: borderColor),
          const SizedBox(height: 12),

          // Amount + Status hero
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark ? [const Color(0xFF1e293b), const Color(0xFF0f172a)] : [_kOrange, const Color(0xFFea580c)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: isDark ? Border.all(color: borderColor) : null,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('AMOUNT', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text('₵${amount.toStringAsFixed(2)}', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
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

          const SizedBox(height: 24),

          // Close button
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kOrange,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Close', style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':    return _kGreen;
      case 'pending': return _kAmber;
      default:        return _kRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1e293b) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0);
    final textColor = isDark ? const Color(0xFFf8fafc) : const Color(0xFF0f172a);
    final subTextColor = isDark ? const Color(0xFF94a3b8) : const Color(0xFF475569);

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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark ? [const Color(0xFF1e293b), const Color(0xFF0f172a)] : [_kOrange, const Color(0xFFea580c)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: isDark ? Border.all(color: borderColor) : null,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 4))
              ],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('TOTAL REVENUE', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 1)),
              const SizedBox(height: 6),
              Text('₵${revenue.toStringAsFixed(2)}', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 12),
              Row(children: [
                _KpiChip(label: 'Pending', value: _kpis['pending']?.toString() ?? '0', color: _kAmber),
                const SizedBox(width: 10),
                _KpiChip(label: 'Failed', value: _kpis['failed']?.toString() ?? '0', color: _kRed),
              ]),
            ]),
          ),
          const SizedBox(height: 20),

          // Search + Filter row
          Row(children: [
            Expanded(
              flex: 3,
              child: TextField(
                onChanged: _onSearchChanged,
                style: GoogleFonts.outfit(fontSize: 13, color: textColor),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded, color: subTextColor, size: 18),
                  hintText: 'Search by name or description...',
                  hintStyle: GoogleFonts.outfit(fontSize: 13, color: subTextColor),
                  filled: true,
                  fillColor: cardBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderColor)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _kOrange, width: 2)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: CustomDropdown<String>(
                value: _filterStatus,
                prefixIcon: Icon(Icons.payments_outlined, size: 16, color: subTextColor),
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
          const SizedBox(height: 20),

          // Transaction Cards
          if (_loading)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 8,
              separatorBuilder: (ctx, i) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) => const ShimmerListTile(),
            )
          else if (_hasError && _transactions.isEmpty)
            FetchErrorView(onRetry: () => _fetch(refresh: true))
          else if (_transactions.isEmpty)
            Container(
              padding: const EdgeInsets.all(48),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(children: [
                Icon(Icons.payments_outlined, size: 48, color: subTextColor.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                Text('No payment records found.', style: GoogleFonts.outfit(color: subTextColor, fontWeight: FontWeight.bold)),
              ]),
            )
          else
            ..._transactions.map((tx) {
              final status = tx['status']?.toString() ?? '';
              final color = _statusColor(status);
              final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    // Avatar initials
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: _kOrange.withValues(alpha: 0.15), shape: BoxShape.circle),
                      child: Center(child: Text(
                        (tx['member_name']?.toString() ?? '?').substring(0, 1).toUpperCase(),
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: _kOrange, fontSize: 18),
                      )),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tx['member_name']?.toString() ?? '', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: textColor), overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('ID: ${tx['tx_id']?.toString() ?? ''}', style: GoogleFonts.outfit(fontSize: 11, color: subTextColor, fontWeight: FontWeight.w500)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('₵${amount.toStringAsFixed(2)}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                        child: Text(status.toUpperCase(), style: GoogleFonts.outfit(fontSize: 10, color: color, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      ),
                    ]),
                  ]),
                  if ((tx['description']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      width: double.infinity,
                      decoration: BoxDecoration(color: isDark ? const Color(0xFF0f172a).withValues(alpha: 0.4) : const Color(0xFFf8fafc), borderRadius: BorderRadius.circular(8)),
                      child: Text(tx['description'].toString(), style: GoogleFonts.outfit(fontSize: 12, color: subTextColor)),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(children: [
                    if (status == 'pending')
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _actionLoading ? null : () => _showConfirmDialog(tx['tx_id'], amount, tx['member_name']?.toString() ?? ''),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kGreen,
                            elevation: 0,
                            minimumSize: const Size(0, 44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
                          label: Text('Approve', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    if (status == 'pending') const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showDetailSheet(Map<String, dynamic>.from(tx)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          side: BorderSide(color: borderColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: Icon(Icons.open_in_new_rounded, size: 16, color: textColor),
                        label: Text('View Details', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor)),
                      ),
                    ),
                  ]),
                ]),
              );
            }),
            
            // Pagination Controls
            if (!_loading && (_page > 1 || _hasMore))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: _page > 1 ? cardBg : Colors.transparent,
                        border: Border.all(color: _page > 1 ? borderColor : borderColor.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        onPressed: _page > 1 ? () => _fetch(page: _page - 1) : null,
                        icon: const Icon(Icons.chevron_left_rounded, size: 20),
                        color: _kOrange,
                        disabledColor: subTextColor.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: cardBg,
                        border: Border.all(color: borderColor),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.01), blurRadius: 4),
                        ],
                      ),
                      child: Text(
                        'Page $_page', 
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: _hasMore ? cardBg : Colors.transparent,
                        border: Border.all(color: _hasMore ? borderColor : borderColor.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        onPressed: _hasMore ? () => _fetch(page: _page + 1) : null,
                        icon: const Icon(Icons.chevron_right_rounded, size: 20),
                        color: _kOrange,
                        disabledColor: subTextColor.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              
            if (!_loading && _transactions.isNotEmpty) 
              Center(child: Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Text(
                  'Showing ${_transactions.length} payments${_total > 0 ? " of $_total" : ""}', 
                  style: GoogleFonts.outfit(fontSize: 12, color: subTextColor, fontWeight: FontWeight.w500),
                ),
              )),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(status.toUpperCase(), style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFf8fafc) : const Color(0xFF0f172a);
    final subTextColor = isDark ? const Color(0xFF94a3b8) : const Color(0xFF475569);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 110,
          child: Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: subTextColor)),
        ),
        Expanded(child: Text(value, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: textColor))),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('$value $label', style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}
