import 'package:flutter/material.dart';
import '../components/app_layout.dart';
import '../components/custom_dropdown.dart';
import '../services/api_service.dart';

const _kOrange = Color(0xFFf08232);
const _kGreen  = Color(0xFF10b981);

const _kAmber  = Color(0xFFf59e0b);
const _kSlate  = Color(0xFF94a3b8);

class AdminTicketsPage extends StatefulWidget {
  const AdminTicketsPage({super.key});
  @override State<AdminTicketsPage> createState() => _State();
}

class _State extends State<AdminTicketsPage> {
  final _api = ApiService();
  List<dynamic> _tickets = [];
  dynamic _selected;

  String _tab = 'inbox';
  bool _sending = false;
  bool _loading = true;

  final _replyCtrl = TextEditingController();

  @override void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final data = await _api.fetchData('tickets/admin/all');
      if (mounted && data is List) {
        setState(() {
          _tickets = data;
          if (_selected != null) {
            _selected = data.firstWhere((t) => t['id'] == _selected['id'], orElse: () => null);
          }
        });
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(String status) async {
    if (_selected == null) return;
    await _api.putData('tickets/admin/${_selected['id']}/status', {'status': status});
    if (status == 'archived') setState(() => _selected = null);
    await _fetch();
  }

  Future<void> _sendReply() async {
    if (_replyCtrl.text.trim().isEmpty || _selected == null) return;
    setState(() => _sending = true);
    await _api.postData('tickets/admin/${_selected['id']}/reply', {'message': _replyCtrl.text.trim()});
    _replyCtrl.clear();
    setState(() { _sending = false; });
    await _fetch();
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'open':     return _kOrange;
      case 'pending':  return _kAmber;
      case 'resolved': return _kGreen;
      default:         return _kSlate;
    }
  }

  String _statusLabel(String s) => s[0].toUpperCase() + s.substring(1);

  List<dynamic> get _inbox    => _tickets.where((t) => t['status'] != 'archived').toList();
  List<dynamic> get _archived => _tickets.where((t) => t['status'] == 'archived').toList();
  List<dynamic> get _displayed => _tab == 'inbox' ? _inbox : _archived;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      {'id': 'inbox',    'label': 'Inbox (${_inbox.length})'},
      {'id': 'archived', 'label': 'Archived (${_archived.length})'},
    ];
    return AppLayout(
      title: 'Support Tickets',
      child: _selected != null ? _buildReplyPanel() : Column(children: [
        // Tab bar
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
          child: Row(children: tabs.map((t) {
            final active = _tab == t['id'];
            return Expanded(child: GestureDetector(
              onTap: () => setState(() { _tab = t['id']!; _selected = null; }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: active ? _kOrange : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center,
                child: Text(t['label']!, style: TextStyle(color: active ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ));
          }).toList()),
        ),
        const SizedBox(height: 12),
        _buildTicketList(),
      ]),
    );
  }

  Widget _buildTicketList() {
    if (_loading) {
      return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: _kOrange)));
    }
    if (_displayed.isEmpty) {
      return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
      child: Center(child: Text(_tab == 'inbox' ? 'No open tickets.' : 'No archived tickets.', style: const TextStyle(color: Colors.grey))),
    );
    }
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: List.generate(_displayed.length, (i) {
        final ticket = _displayed[i];
        final color  = _statusColor(ticket['status'] ?? 'open');
        return InkWell(
          onTap: () => setState(() => _selected = ticket),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: color, width: 3),
                bottom: BorderSide(color: Colors.grey.shade100),
              ),
            ),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('#${ticket['id'].toString().length > 6 ? ticket['id'].toString().substring(ticket['id'].toString().length - 6) : ticket['id']}', style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(12)), child: Text(_statusLabel(ticket['status'] ?? 'open'), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color))),
                ]),
                const SizedBox(height: 4),
                Text(ticket['member_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, color: _kOrange, fontSize: 14)),
                const SizedBox(height: 2),
                Text(ticket['subject'] ?? '', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Opened: ${ticket['date'] ?? ''}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ])),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ]),
          ),
        );
      })),
    );
  }

  Widget _buildReplyPanel() {
    final t = _selected!;
    final statusOptions = ['open', 'pending', 'resolved', 'archived'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        TextButton.icon(icon: const Icon(Icons.arrow_back, size: 16), label: const Text('Back'), onPressed: () => setState(() => _selected = null)),
        const Spacer(),
        CustomDropdown<String>(
          value: t['status'] ?? 'open',
          width: 140,
          dense: true,
          items: statusOptions.map((s) => DropdownItem<String>(value: s, label: _statusLabel(s))).toList(),
          onChanged: (v) => _updateStatus(v),
        ),
      ]),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
        child: Row(children: [
          Expanded(child: _meta('From', t['member_name'] ?? '')),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: _meta('Subject', t['subject'] ?? '')),
          const SizedBox(width: 8),
          Expanded(child: _meta('Date', t['date'] ?? '')),
        ]),
      ),
      const SizedBox(height: 12),

      // Original message
      _bubble(t['message'] ?? '', 'MEMBER MESSAGE', isAdmin: false),

      // Replies
      if (t['replies'] != null) ...List<Widget>.from((t['replies'] as List).map((r) => _bubble(
        r['message'] ?? '',
        '${(r['author'] ?? 'User').toString().toUpperCase()} (${r['date'] ?? ''})',
        isAdmin: r['author']?.toString().toLowerCase() == 'admin',
      ))),

      const SizedBox(height: 16),
      // Archive button
      if (t['status'] != 'archived') Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton.icon(icon: const Icon(Icons.archive_outlined, size: 16), label: const Text('Move to Archive'), onPressed: () => _updateStatus('archived'), style: OutlinedButton.styleFrom(foregroundColor: Colors.grey)),
      ),
      const SizedBox(height: 12),

      // Reply form
      TextField(controller: _replyCtrl, maxLines: 4, decoration: InputDecoration(hintText: 'Type your reply...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.all(14))),
      const SizedBox(height: 10),
      SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(
        onPressed: _sending ? null : _sendReply,
        icon: const Icon(Icons.send),
        label: const Text('Send Reply', style: TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(backgroundColor: _kOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      )),
    ]);
  }

  Widget _meta(String label, String val) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey)),
    Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
  ]);

  Widget _bubble(String msg, String header, {required bool isAdmin}) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isAdmin ? _kOrange.withAlpha(12) : Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: isAdmin ? _kOrange.withAlpha(40) : Colors.grey.shade200),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(header, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isAdmin ? _kOrange : Colors.grey)),
      const SizedBox(height: 6),
      Text(msg, style: const TextStyle(fontSize: 14, height: 1.5)),
    ]),
  );
}
