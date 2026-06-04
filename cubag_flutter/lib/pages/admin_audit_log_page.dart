import 'package:flutter/material.dart';
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
      setState(() { if (isFrom) _filterDateFrom = f; else _filterDateTo = f; _offset = 0; });
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('CSV export initiated — check your browser downloads'),
          backgroundColor: Color(0xFF10b981),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  void _showDetail(Map<String, dynamic> log) {
    final primary = Theme.of(context).primaryColor;
    final action = log['action']?.toString() ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 40),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: _actionColor(action).withAlpha(20), borderRadius: BorderRadius.circular(10)),
              child: Icon(_actionIcon(action), color: _actionColor(action), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('Audit Entry Details', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
            IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.of(ctx).pop()),
          ]),
          const Divider(height: 24),
          ...[
            ['Action',       action],
            ['Target Type',  (log['target_type']?.toString() ?? '—').toUpperCase()],
            ['Target',       log['target_name']?.toString() ?? '—'],
            ['Details',      log['details']?.toString() ?? '—'],
            ['Performed By', log['admin_name']?.toString() ?? 'System'],
            ['Role',         (log['admin_role']?.toString() ?? 'admin').replaceAll('_', ' ').toUpperCase()],
            ['Actor Email',  log['admin_email']?.toString() ?? '—'],
            ['Timestamp',    _formatFull(log['created_at']?.toString() ?? '')],
          ].map((r) => _DetailRow(label: r[0], value: r[1])),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(backgroundColor: primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Close', style: TextStyle(color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final currentPage = (_offset ~/ _limit) + 1;
    final totalPages = (_total / _limit).ceil().clamp(1, 999);

    return AppLayout(
      title: 'Audit Log',
      hideSearch: false,
      scrollable: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header banner ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF0f172a), Color(0xFF1e293b)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: primary.withAlpha(40), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.history, color: primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Activity Audit Trail', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              Text('$_total total actions recorded', style: const TextStyle(color: Color(0xFF94a3b8), fontSize: 12)),
            ])),
            IconButton(
              icon: Icon(_filtersVisible ? Icons.filter_list_off : Icons.filter_list,
                  color: _hasActiveFilters ? primary : const Color(0xFF94a3b8), size: 20),
              tooltip: 'Filters',
              onPressed: () => setState(() => _filtersVisible = !_filtersVisible),
            ),
            IconButton(
              icon: const Icon(Icons.download_outlined, color: Color(0xFF94a3b8), size: 20),
              tooltip: 'Export CSV',
              onPressed: _exportCsv,
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF94a3b8), size: 20),
              onPressed: _fetchLogs,
            ),
          ]),
        ),

        // ── What is an audit log? info card ────────────────────────────
        if (_logs.isEmpty && !_loading && !_hasActiveFilters) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primary.withAlpha(10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primary.withAlpha(40)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.info_outline, color: primary, size: 18),
                const SizedBox(width: 8),
                Text('How the Audit Log works', style: TextStyle(fontWeight: FontWeight.w700, color: primary, fontSize: 14)),
              ]),
              const SizedBox(height: 8),
              const Text(
                'Every admin action is automatically recorded here — member status changes, payment approvals, '
                'announcements, ticket replies, event management, and more. '
                'Entries will appear as you use the admin panel.',
                style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.5),
              ),
            ]),
          ),
        ],

        // ── Filters ────────────────────────────────────────────────────
        if (_filtersVisible) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFe2e8f0))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('Filter Logs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const Spacer(),
                if (_hasActiveFilters) TextButton.icon(
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.clear, size: 14),
                  label: const Text('Clear all', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(foregroundColor: Colors.red, padding: EdgeInsets.zero),
                ),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _FilterChip(
                  label: _filterTargetType.isEmpty ? 'All Types' : _filterTargetType,
                  active: _filterTargetType.isNotEmpty,
                  onTap: () => _showPicker('Target Type', ['', ..._targetTypeOptions], _filterTargetType, (v) {
                    setState(() { _filterTargetType = v; _offset = 0; });
                    _fetchLogs();
                  }),
                ),
                _FilterChip(
                  label: _filterActionType.isEmpty ? 'All Actions' : _filterActionType,
                  active: _filterActionType.isNotEmpty,
                  onTap: () => _showPicker('Action', [
                    '', 'activated', 'suspended', 'approved', 'Updated', 'Created',
                    'Replied', 'Archived', 'Deleted', 'Marked payment',
                  ], _filterActionType, (v) {
                    setState(() { _filterActionType = v; _offset = 0; });
                    _fetchLogs();
                  }),
                ),
                _FilterChip(
                  label: _filterDateFrom.isEmpty ? 'From Date' : _filterDateFrom,
                  active: _filterDateFrom.isNotEmpty,
                  icon: Icons.calendar_today,
                  onTap: () => _pickDate(true),
                ),
                _FilterChip(
                  label: _filterDateTo.isEmpty ? 'To Date' : _filterDateTo,
                  active: _filterDateTo.isNotEmpty,
                  icon: Icons.calendar_today,
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
                    onTap: () {
                      final opts = [{'id': '', 'name': 'All Actors', 'role': ''}, ..._actorsOptions];
                      showModalBottomSheet(
                        context: context,
                        builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Padding(padding: EdgeInsets.all(16), child: Text('Filter by Actor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                          ...opts.map((a) {
                            final isSelected = a['id'].toString() == _filterActorId;
                            final roleLabel = (a['role']?.toString() ?? '').isNotEmpty
                                ? ' · ${a['role'].toString().replaceAll('_', ' ')}'
                                : '';
                            return ListTile(
                              leading: Icon(
                                a['role'] == 'sub_admin' ? Icons.badge_outlined : Icons.admin_panel_settings_outlined,
                                size: 18,
                                color: isSelected ? Theme.of(context).primaryColor : const Color(0xFF94a3b8),
                              ),
                              title: Text('${a['name']}$roleLabel', style: const TextStyle(fontSize: 13)),
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

        const SizedBox(height: 16),

        // ── Log entries ────────────────────────────────────────────────
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator(color: Color(0xFFf08232))))
        else if (_logs.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(children: [
              Icon(Icons.history_toggle_off, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(_hasActiveFilters ? 'No entries match your filters.' : 'No audit entries yet.\nUse the admin panel to generate activity.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              if (_hasActiveFilters) ...[const SizedBox(height: 8), TextButton(onPressed: _resetFilters, child: const Text('Clear filters'))],
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
                SizedBox(width: 40, child: Column(children: [
                  Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withAlpha(20), shape: BoxShape.circle),
                    child: Icon(_actionIcon(action), color: color, size: 16)),
                  if (!isLast) Expanded(child: Container(width: 2, color: const Color(0xFFe2e8f0))),
                ])),
                const SizedBox(width: 12),
                // Card
                Expanded(child: Container(
                  margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: InkWell(
                    onTap: () => _showDetail(Map<String, dynamic>.from(log)),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(20)),
                            child: Text(_targetLabel(log['target_type']?.toString() ?? ''),
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
                          ),
                          const Spacer(),
                          Text(_formatRelative(log['created_at']?.toString() ?? ''),
                            style: const TextStyle(fontSize: 10, color: Color(0xFF94a3b8), fontWeight: FontWeight.w600)),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right, size: 14, color: Color(0xFFcbd5e1)),
                        ]),
                        const SizedBox(height: 6),
                        Text(action, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0f172a))),
                        if ((log['target_name']?.toString() ?? '').isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(log['target_name'].toString(), style: const TextStyle(fontSize: 12, color: Color(0xFF64748b)), overflow: TextOverflow.ellipsis),
                        ],
                        if ((log['details']?.toString() ?? '').isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(log['details'].toString(), style: const TextStyle(fontSize: 11, color: Color(0xFF94a3b8)), overflow: TextOverflow.ellipsis),
                        ],
                        const SizedBox(height: 4),
                        Row(children: [
                          // Actor role badge
                          Builder(builder: (_) {
                            final role = log['admin_role']?.toString() ?? 'admin';
                            final isSubAdmin = role == 'sub_admin';
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: isSubAdmin ? const Color(0xFF8b5cf6).withAlpha(18) : const Color(0xFF10b981).withAlpha(18),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isSubAdmin ? 'Sub-Admin' : 'Admin',
                                style: TextStyle(
                                  fontSize: 9, fontWeight: FontWeight.w800,
                                  color: isSubAdmin ? const Color(0xFF8b5cf6) : const Color(0xFF10b981),
                                ),
                              ),
                            );
                          }),
                          const Icon(Icons.person_outline, size: 12, color: Color(0xFF94a3b8)),
                          const SizedBox(width: 4),
                          Text(log['admin_name']?.toString() ?? 'System',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF94a3b8), fontWeight: FontWeight.w600)),
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
            padding: const EdgeInsets.only(top: 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              TextButton.icon(
                onPressed: _offset > 0 ? _prevPage : null,
                icon: const Icon(Icons.chevron_left, size: 18),
                label: const Text('Previous', style: TextStyle(fontSize: 12)),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: primary.withAlpha(12), borderRadius: BorderRadius.circular(8)),
                child: Text('Page $currentPage of $totalPages',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primary)),
              ),
              TextButton.icon(
                onPressed: _offset + _limit < _total ? _nextPage : null,
                icon: const Text('Next', style: TextStyle(fontSize: 12)),
                label: const Icon(Icons.chevron_right, size: 18),
              ),
            ]),
          ),
      ]),
    );
  }

  void _showPicker(String title, List<String> options, String current, Function(String) onSelected) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.all(16), child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
        ...options.map((opt) => ListTile(
          title: Text(opt.isEmpty ? 'All' : opt, style: TextStyle(fontWeight: opt == current ? FontWeight.bold : FontWeight.normal)),
          trailing: opt == current ? const Icon(Icons.check, color: Color(0xFFf08232), size: 18) : null,
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
    if (a.contains('activat') || a.contains('approv') || a.contains('verified')) return Icons.check_circle_outline;
    if (a.contains('suspend') || a.contains('archiv')) return Icons.block;
    if (a.contains('delet')) return Icons.cancel_outlined;
    if (a.contains('paid') || a.contains('payment')) return Icons.payments_outlined;
    if (a.contains('creat') || a.contains('upload')) return Icons.add_circle_outline;
    if (a.contains('updat') || a.contains('mark') || a.contains('status')) return Icons.edit_outlined;
    if (a.contains('reply') || a.contains('replied')) return Icons.reply;
    if (a.contains('restor')) return Icons.restore;
    if (a.contains('login')) return Icons.login;
    return Icons.info_outline;
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
  const _DetailRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF94a3b8)))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF0f172a)))),
    ]),
  );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final IconData? icon;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.active, this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFf08232).withAlpha(15) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? const Color(0xFFf08232).withAlpha(60) : const Color(0xFFe2e8f0)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 13, color: active ? const Color(0xFFf08232) : const Color(0xFF94a3b8)), const SizedBox(width: 4)],
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? const Color(0xFFf08232) : const Color(0xFF64748b))),
          const SizedBox(width: 4),
          Icon(Icons.arrow_drop_down, size: 16, color: active ? const Color(0xFFf08232) : const Color(0xFF94a3b8)),
        ]),
      ),
    );
  }
}
