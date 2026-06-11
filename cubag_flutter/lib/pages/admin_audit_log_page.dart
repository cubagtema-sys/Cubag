import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../components/app_layout.dart';
import '../services/api_service.dart';

class AdminAuditLogPage extends StatefulWidget {
  const AdminAuditLogPage({super.key});
  @override
  State<AdminAuditLogPage> createState() => _AdminAuditLogPageState();
}

class _AdminAuditLogPageState extends State<AdminAuditLogPage> {
  bool _loading = true;
  List<dynamic> _logs = [];
  int _total = 0;
  int _offset = 0;
  final int _limit = 30;

  String _filterTargetType = '';
  String _filterActionType = '';
  String _filterDateFrom = '';
  String _filterDateTo = '';
  String _filterActorId = '';       // actor_id filter for sub-admin
  List<String> _targetTypeOptions = [];
  List<Map<String, dynamic>> _actorsOptions = [];  // [{id, name, role}]
  bool _filtersVisible = false;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  String _buildQueryParams() {
    final params = <String>['limit=$_limit', 'offset=$_offset'];
    if (_filterTargetType.isNotEmpty) params.add('target_type=$_filterTargetType');
    if (_filterActionType.isNotEmpty) params.add('action_type=$_filterActionType');
    if (_filterDateFrom.isNotEmpty)   params.add('date_from=$_filterDateFrom');
    if (_filterDateTo.isNotEmpty)     params.add('date_to=$_filterDateTo');
    if (_filterActorId.isNotEmpty)    params.add('actor_id=$_filterActorId');
    return params.join('&');
  }

  Future<void> _fetchLogs() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final res = await ApiService().get('/admin/audit-log?${_buildQueryParams()}');
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        setState(() {
          _logs = data['logs'] ?? [];
          _total = data['total'] ?? 0;
          final opts = data['filter_options'] as Map<String, dynamic>?;
          if (opts != null) {
            _targetTypeOptions = List<String>.from(opts['target_types'] ?? []);
            _actorsOptions = List<Map<String, dynamic>>.from(
              (opts['actors'] ?? []).map((a) => Map<String, dynamic>.from(a))
            );
          }
          _loading = false;
        });
        return;
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _nextPage() {
    if (_offset + _limit < _total) { _offset += _limit; _fetchLogs(); }
  }

  void _prevPage() {
    if (_offset > 0) { _offset = (_offset - _limit).clamp(0, _total); _fetchLogs(); }
  }

  void _resetFilters() {
    setState(() {
      _filterTargetType = '';
      _filterActionType = '';
      _filterDateFrom = '';
      _filterDateTo = '';
      _filterActorId = '';
      _offset = 0;
    });
    _fetchLogs();
  }

  bool get _hasActiveFilters =>
      _filterTargetType.isNotEmpty || _filterActionType.isNotEmpty ||
      _filterDateFrom.isNotEmpty || _filterDateTo.isNotEmpty ||
      _filterActorId.isNotEmpty;

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      final f = '${picked.year}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}';
      setState(() { if (isFrom) {
        _filterDateFrom = f;
      } else {
        _filterDateTo = f;
      } _offset = 0; });
      _fetchLogs();
    }
  }

  Future<void> _exportCsv() async {
    try {
      final params = <String>[];
      if (_filterTargetType.isNotEmpty) params.add('target_type=$_filterTargetType');
      if (_filterActionType.isNotEmpty) params.add('action_type=$_filterActionType');
      if (_filterDateFrom.isNotEmpty) params.add('date_from=$_filterDateFrom');
      if (_filterDateTo.isNotEmpty) params.add('date_to=$_filterDateTo');
      final qs = params.isNotEmpty ? '?${params.join('&')}' : '';
      final res = await ApiService().get('/admin/audit-log/export$qs');
      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('CSV export initiated — check your browser downloads', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF10b981),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e', style: GoogleFonts.outfit())));
      }
    }
  }

  void _showDetail(Map<String, dynamic> log, Color cardBg, Color borderColor, Color textColor, Color subTextColor) {
    final primary = Theme.of(context).primaryColor;
    final action = log['action']?.toString() ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 40),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 48, height: 6, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(3)))),
          const SizedBox(height: 20),
          Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _actionColor(action).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(_actionIcon(action), color: _actionColor(action), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text('Audit Entry Details', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: textColor))),
            IconButton(icon: Icon(Icons.close_rounded, size: 24, color: subTextColor), onPressed: () => Navigator.of(ctx).pop()),
          ]),
          const SizedBox(height: 16),
          Divider(height: 1, color: borderColor),
          const SizedBox(height: 16),
          ...[
            ['Action',       action],
            ['Target Type',  (log['target_type']?.toString() ?? '—').toUpperCase()],
            ['Target',       log['target_name']?.toString() ?? '—'],
            ['Details',      log['details']?.toString() ?? '—'],
            ['Performed By', log['admin_name']?.toString() ?? 'System'],
            ['Role',         (log['admin_role']?.toString() ?? 'admin').replaceAll('_', ' ').toUpperCase()],
            ['Actor Email',  log['admin_email']?.toString() ?? '—'],
            ['Timestamp',    _formatFull(log['created_at']?.toString() ?? '')],
          ].map((r) => _DetailRow(label: r[0], value: r[1], textColor: textColor, subTextColor: subTextColor)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text('Close', style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1e293b) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0);
    final textColor = isDark ? const Color(0xFFf8fafc) : const Color(0xFF0f172a);
    final subTextColor = isDark ? const Color(0xFF94a3b8) : const Color(0xFF475569);

    final currentPage = (_offset ~/ _limit) + 1;
    final totalPages = (_total / _limit).ceil().clamp(1, 999);

    return AppLayout(
      title: 'Audit Log',
      hideSearch: false,
      scrollable: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header banner ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [primary, primary.withValues(alpha: isDark ? 0.5 : 0.8)]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.history_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Activity Audit Trail', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Text('$_total total actions recorded', style: GoogleFonts.outfit(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
            ])),
            IconButton(
              icon: Icon(_filtersVisible ? Icons.filter_list_off_rounded : Icons.filter_list_rounded,
                  color: _hasActiveFilters ? (isDark ? _kOrange : Colors.white) : Colors.white70, size: 24),
              tooltip: 'Filters',
              onPressed: () => setState(() => _filtersVisible = !_filtersVisible),
            ),
            IconButton(
              icon: const Icon(Icons.download_rounded, color: Colors.white70, size: 24),
              tooltip: 'Export CSV',
              onPressed: _exportCsv,
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 24),
              onPressed: _fetchLogs,
            ),
          ]),
        ),

        // ── What is an audit log? info card ────────────────────────────
        if (_logs.isEmpty && !_loading && !_hasActiveFilters) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primary.withValues(alpha: 0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.info_outline_rounded, color: primary, size: 20),
                const SizedBox(width: 10),
                Text('How the Audit Log works', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: primary, fontSize: 15)),
              ]),
              const SizedBox(height: 10),
              Text(
                'Every admin action is automatically recorded here — member status changes, payment approvals, '
                'announcements, ticket replies, event management, and more. '
                'Entries will appear as you use the admin panel.',
                style: GoogleFonts.outfit(fontSize: 14, color: isDark ? Colors.white70 : const Color(0xFF475569), height: 1.5),
              ),
            ]),
          ),
        ],

        // ── Filters ────────────────────────────────────────────────────
        if (_filtersVisible) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('Filter Logs', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                const Spacer(),
                if (_hasActiveFilters) TextButton.icon(
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  label: Text('Clear all', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(foregroundColor: Colors.red, padding: EdgeInsets.zero),
                ),
              ]),
              const SizedBox(height: 16),
              Wrap(spacing: 12, runSpacing: 12, children: [
                _FilterChip(
                  label: _filterTargetType.isEmpty ? 'All Types' : _filterTargetType,
                  active: _filterTargetType.isNotEmpty,
                  borderColor: borderColor,
                  subTextColor: subTextColor,
                  onTap: () => _showPicker('Target Type', ['', ..._targetTypeOptions], _filterTargetType, cardBg, borderColor, textColor, (v) {
                    setState(() { _filterTargetType = v; _offset = 0; });
                    _fetchLogs();
                  }),
                ),
                _FilterChip(
                  label: _filterActionType.isEmpty ? 'All Actions' : _filterActionType,
                  active: _filterActionType.isNotEmpty,
                  borderColor: borderColor,
                  subTextColor: subTextColor,
                  onTap: () => _showPicker('Action', [
                    '', 'activated', 'suspended', 'approved', 'Updated', 'Created',
                    'Replied', 'Archived', 'Deleted', 'Marked payment',
                  ], _filterActionType, cardBg, borderColor, textColor, (v) {
                    setState(() { _filterActionType = v; _offset = 0; });
                    _fetchLogs();
                  }),
                ),
                _FilterChip(
                  label: _filterDateFrom.isEmpty ? 'From Date' : _filterDateFrom,
                  active: _filterDateFrom.isNotEmpty,
                  icon: Icons.calendar_today_rounded,
                  borderColor: borderColor,
                  subTextColor: subTextColor,
                  onTap: () => _pickDate(true),
                ),
                _FilterChip(
                  label: _filterDateTo.isEmpty ? 'To Date' : _filterDateTo,
                  active: _filterDateTo.isNotEmpty,
                  icon: Icons.calendar_today_rounded,
                  borderColor: borderColor,
                  subTextColor: subTextColor,
                  onTap: () => _pickDate(false),
                ),
                if (_actorsOptions.isNotEmpty)
                  _FilterChip(
                    label: _filterActorId.isEmpty
                        ? 'All Actors'
                        : (_actorsOptions.firstWhere(
                              (a) => a['id'].toString() == _filterActorId,
                              orElse: () => {'name': _filterActorId},
                            )['name'] ?? _filterActorId),
                    active: _filterActorId.isNotEmpty,
                    icon: Icons.manage_accounts_outlined,
                    borderColor: borderColor,
                    subTextColor: subTextColor,
                    onTap: () {
                      final opts = [{'id': '', 'name': 'All Actors', 'role': ''}, ..._actorsOptions];
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: cardBg,
                        builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Padding(padding: const EdgeInsets.all(20), child: Text('Filter by Actor', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: textColor))),
                          ...opts.map((a) {
                            final isSelected = a['id'].toString() == _filterActorId;
                            final roleLabel = (a['role']?.toString() ?? '').isNotEmpty
                                ? ' · ${a['role'].toString().replaceAll('_', ' ')}'
                                : '';
                            return ListTile(
                              leading: Icon(
                                a['role'] == 'sub_admin' ? Icons.badge_outlined : Icons.admin_panel_settings_rounded,
                                size: 20,
                                color: isSelected ? Theme.of(context).primaryColor : subTextColor,
                              ),
                              title: Text('${a['name']}$roleLabel', style: GoogleFonts.outfit(fontSize: 14, color: isSelected ? primary : textColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                              selected: isSelected,
                              onTap: () {
                                setState(() { _filterActorId = a['id'].toString(); _offset = 0; });
                                Navigator.pop(context);
                                _fetchLogs();
                              },
                            );
                          }),
                        ])),
                      );
                    },
                  ),
              ]),
            ]),
          ),
        ],

        const SizedBox(height: 24),

        // ── Log entries ────────────────────────────────────────────────
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator(color: Color(0xFFf08232))))
        else if (_logs.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(children: [
              Icon(Icons.history_toggle_off_rounded, size: 56, color: subTextColor.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text(_hasActiveFilters ? 'No entries match your filters.' : 'No audit entries yet.\nUse the admin panel to generate activity.', textAlign: TextAlign.center, style: GoogleFonts.outfit(color: subTextColor, fontSize: 14)),
              if (_hasActiveFilters) ...[const SizedBox(height: 12), TextButton(onPressed: _resetFilters, child: Text('Clear filters', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)))],
            ]),
          ))
        else
          // Timeline list
          Column(children: List.generate(_logs.length, (i) {
            final log = _logs[i] as Map<String, dynamic>;
            final action = log['action']?.toString() ?? '';
            final color = _actionColor(action);
            final isLast = i == _logs.length - 1;
            return IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Timeline rail
                SizedBox(width: 48, child: Column(children: [
                  Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: Icon(_actionIcon(action), color: color, size: 18)),
                  if (!isLast) Expanded(child: Container(width: 2, color: borderColor)),
                ])),
                const SizedBox(width: 12),
                // Card
                Expanded(child: Container(
                  margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02), blurRadius: 6, offset: const Offset(0, 4))],
                  ),
                  child: InkWell(
                    onTap: () => _showDetail(Map<String, dynamic>.from(log), cardBg, borderColor, textColor, subTextColor),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.3))),
                            child: Text(_targetLabel(log['target_type']?.toString() ?? ''),
                              style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
                          ),
                          const Spacer(),
                          Text(_formatRelative(log['created_at']?.toString() ?? ''),
                            style: GoogleFonts.outfit(fontSize: 11, color: subTextColor, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 6),
                          Icon(Icons.chevron_right_rounded, size: 16, color: subTextColor),
                        ]),
                        const SizedBox(height: 10),
                        Text(action, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: textColor)),
                        if ((log['target_name']?.toString() ?? '').isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(log['target_name'].toString(), style: GoogleFonts.outfit(fontSize: 13, color: subTextColor), overflow: TextOverflow.ellipsis),
                        ],
                        if ((log['details']?.toString() ?? '').isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(log['details'].toString(), style: GoogleFonts.outfit(fontSize: 12, color: subTextColor), overflow: TextOverflow.ellipsis),
                        ],
                        const SizedBox(height: 12),
                        Row(children: [
                          // Actor role badge
                          Builder(builder: (_) {
                            final role = log['admin_role']?.toString() ?? 'admin';
                            final isSubAdmin = role == 'sub_admin';
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: isSubAdmin ? const Color(0xFF8b5cf6).withValues(alpha: 0.1) : const Color(0xFF10b981).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: isSubAdmin ? const Color(0xFF8b5cf6).withValues(alpha: 0.3) : const Color(0xFF10b981).withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                isSubAdmin ? 'Sub-Admin' : 'Admin',
                                style: GoogleFonts.outfit(
                                  fontSize: 10, fontWeight: FontWeight.w800,
                                  color: isSubAdmin ? const Color(0xFF8b5cf6) : const Color(0xFF10b981),
                                ),
                              ),
                            );
                          }),
                          Icon(Icons.person_outline_rounded, size: 14, color: subTextColor),
                          const SizedBox(width: 6),
                          Text(log['admin_name']?.toString() ?? 'System',
                            style: GoogleFonts.outfit(fontSize: 12, color: subTextColor, fontWeight: FontWeight.bold)),
                        ]),
                      ]),
                    ),
                  ),
                )),
              ]),
            );
          })),

        // ── Pagination ─────────────────────────────────────────────────
        if (!_loading && _total > _limit)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              TextButton.icon(
                onPressed: _offset > 0 ? _prevPage : null,
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                label: Text('Previous', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Text('Page $currentPage of $totalPages',
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: primary)),
              ),
              TextButton.icon(
                onPressed: _offset + _limit < _total ? _nextPage : null,
                icon: Text('Next', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold)),
                label: const Icon(Icons.chevron_right_rounded, size: 20),
              ),
            ]),
          ),
      ]),
    );
  }

  void _showPicker(String title, List<String> options, String current, Color cardBg, Color borderColor, Color textColor, Function(String) onSelected) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.all(20), child: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: textColor))),
        ...options.map((opt) => ListTile(
          title: Text(opt.isEmpty ? 'All' : opt, style: GoogleFonts.outfit(color: textColor, fontSize: 15, fontWeight: opt == current ? FontWeight.bold : FontWeight.normal)),
          trailing: opt == current ? const Icon(Icons.check_rounded, color: Color(0xFFf08232), size: 22) : null,
          onTap: () { Navigator.pop(context); onSelected(opt); },
        )),
        const SizedBox(height: 16),
      ])),
    );
  }

  String _targetLabel(String t) {
    const map = {'member': 'MEMBER', 'payment': 'PAYMENT', 'ticket': 'TICKET', 'announcement': 'ANNOUNCEMENT', 'schedule': 'SCHEDULE', 'event': 'EVENT', 'survey': 'SURVEY', 'task': 'TASK', 'material': 'MATERIAL', 'admin': 'ADMIN', 'system': 'SYSTEM'};
    return map[t.toLowerCase()] ?? t.toUpperCase();
  }

  Color _actionColor(String action) {
    final a = action.toLowerCase();
    if (a.contains('activat') || a.contains('approv') || a.contains('paid') || a.contains('verified') || a.contains('restor') || a.contains('login')) return const Color(0xFF10b981);
    if (a.contains('suspend') || a.contains('deactivat') || a.contains('archiv') || a.contains('delet')) return const Color(0xFFef4444);
    if (a.contains('creat') || a.contains('assign') || a.contains('upload') || a.contains('reply') || a.contains('replied')) return const Color(0xFF3b82f6);
    if (a.contains('updat') || a.contains('mark') || a.contains('status')) return const Color(0xFFf59e0b);
    return const Color(0xFF6366f1);
  }

  IconData _actionIcon(String action) {
    final a = action.toLowerCase();
    if (a.contains('activat') || a.contains('approv') || a.contains('verified')) return Icons.check_circle_outline_rounded;
    if (a.contains('suspend') || a.contains('archiv')) return Icons.block_rounded;
    if (a.contains('delet')) return Icons.cancel_outlined;
    if (a.contains('paid') || a.contains('payment')) return Icons.payments_outlined;
    if (a.contains('creat') || a.contains('upload')) return Icons.add_circle_outline_rounded;
    if (a.contains('updat') || a.contains('mark') || a.contains('status')) return Icons.edit_outlined;
    if (a.contains('reply') || a.contains('replied')) return Icons.reply_rounded;
    if (a.contains('restor')) return Icons.restore_rounded;
    if (a.contains('login')) return Icons.login_rounded;
    return Icons.info_outline_rounded;
  }

  String _formatRelative(String isoStr) {
    try {
      final dt = DateTime.parse(isoStr).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return isoStr; }
  }

  String _formatFull(String isoStr) {
    try {
      final dt = DateTime.parse(isoStr).toLocal();
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) { return isoStr; }
  }
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  final Color textColor;
  final Color subTextColor;
  const _DetailRow({required this.label, required this.value, required this.textColor, required this.subTextColor});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 120, child: Text(label, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: subTextColor))),
      Expanded(child: Text(value, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w500, color: textColor))),
    ]),
  );
}

const _kOrange = Color(0xFFf08232);

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final IconData? icon;
  final Color borderColor;
  final Color subTextColor;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.active, this.icon, required this.borderColor, required this.subTextColor, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _kOrange.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? _kOrange.withValues(alpha: 0.5) : borderColor),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 15, color: active ? _kOrange : subTextColor), const SizedBox(width: 6)],
          Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: active ? _kOrange : subTextColor)),
          const SizedBox(width: 6),
          Icon(Icons.arrow_drop_down_rounded, size: 18, color: active ? _kOrange : subTextColor),
        ]),
      ),
    );
  }
}
