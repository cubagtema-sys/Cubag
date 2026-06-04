import 'package:flutter/material.dart';
import '../components/app_layout.dart';
import '../components/custom_dropdown.dart';
import '../services/api_service.dart';

const _kOrange = Color(0xFFf08232);
const _kGreen  = Color(0xFF10b981);

class AdminTasksPage extends StatefulWidget {
  const AdminTasksPage({super.key});
  @override State<AdminTasksPage> createState() => _State();
}

class _State extends State<AdminTasksPage> {
  final _api = ApiService();
  List<dynamic> _tasks = [];
  List<dynamic> _members = [];
  bool _loading = false;
  String _tab = 'create';
  String _message = '';
  dynamic _selectedAssignment;

  // Create form
  String _memberId = '';
  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  String _dueDate = '';

  // Verify state
  int? _verifyingId;
  final Map<int, String> _verifyNotes = {};
  final Map<int, TextEditingController> _verifyCtrl = {};

  @override void initState() { super.initState(); _fetchData(); }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    final memData  = await _api.fetchData('members');
    final taskData = await _api.fetchData('tasks/admin/all');
    if (mounted) {
      setState(() {
      _members = memData is List ? memData : [];
      _tasks   = taskData is List ? taskData : [];
      _loading = false;
    });
    }
  }

  Future<void> _assignTask() async {
    if (_titleCtrl.text.isEmpty || _dueDate.isEmpty) return;
    setState(() => _loading = true);
    await _api.postData('tasks/admin/create', {'title': _titleCtrl.text, 'description': _descCtrl.text, 'due_date': _dueDate, 'member_id': _memberId});
    _titleCtrl.clear(); _descCtrl.clear();
    setState(() { _dueDate = ''; _memberId = ''; _loading = false; _message = 'Task successfully assigned.'; });
    await _fetchData();
    Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _message = ''); });
  }

  Future<void> _verify(int submissionId) async {
    await _api.patchData('tasks/admin/$submissionId/verify', {'admin_notes': _verifyNotes[submissionId] ?? ''});
    setState(() => _verifyingId = null);
    await _fetchData();
  }

  List<dynamic> get _submissions => _tasks.where((t) => t['submission_id'] != null).toList();
  int get _pendingVerify => _submissions.where((t) => t['admin_verified'] != true).length;

  Map<String, Map<String, dynamic>> get _groupedTasks {
    final groups = <String, Map<String, dynamic>>{};
    for (final task in _tasks) {
      final key = '${task['title']}|${task['due_date']}';
      if (!groups.containsKey(key)) {
        groups[key] = {'title': task['title'], 'description': task['description'], 'due_date': task['due_date'], 'total': 0, 'completed': 0, 'members': []};
      }
      groups[key]!['total'] = (groups[key]!['total'] as int) + 1;
      if (task['done'] == true) groups[key]!['completed'] = (groups[key]!['completed'] as int) + 1;
      (groups[key]!['members'] as List).add(task);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      {'id': 'create',      'label': 'Assign'},
      {'id': 'history',     'label': 'History'},
      {'id': 'submissions', 'label': 'Submissions${_pendingVerify > 0 ? ' ($_pendingVerify)' : ''}'},
    ];
    return AppLayout(
      title: 'Compliance Control',
      child: Column(children: [
        // Tab bar
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
          child: Row(children: tabs.map((t) {
            final active = _tab == t['id'];
            return Expanded(child: GestureDetector(
              onTap: () => setState(() { _tab = t['id']!; _selectedAssignment = null; }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: active ? _kOrange : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center,
                child: Text(t['label']!, style: TextStyle(color: active ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.w700, fontSize: 11), textAlign: TextAlign.center),
              ),
            ));
          }).toList()),
        ),
        const SizedBox(height: 16),

        if (_message.isNotEmpty) Container(
          margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _kGreen.withAlpha(25), borderRadius: BorderRadius.circular(10)),
          child: Text(_message, style: const TextStyle(color: _kGreen, fontWeight: FontWeight.w700)),
        ),

        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator(color: _kOrange)))
        else ...[
          if (_tab == 'create')      _buildCreate(),
          if (_tab == 'history')     _buildHistory(),
          if (_tab == 'submissions') _buildSubmissions(),
        ],
      ]),
    );
  }

  Widget _buildCreate() => Container(
    constraints: const BoxConstraints(maxWidth: 600),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('New Assignment', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 16),
      const Text('Assign To', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), const SizedBox(height: 6),
      CustomDropdown<String>(
        value: _memberId,
        hint: 'Select a member...',
        items: [
          const DropdownItem(value: 'all', label: 'All Active Members'),
          ..._members.map((m) => DropdownItem<String>(value: m['id'].toString(), label: m['name'] ?? '')),
        ],
        onChanged: (v) => setState(() => _memberId = v),
      ),
      const SizedBox(height: 14),
      const Text('Task Title', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), const SizedBox(height: 6),
      TextField(controller: _titleCtrl, decoration: _deco(hint: 'Title...')),
      const SizedBox(height: 14),
      const Text('Due Date', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), const SizedBox(height: 6),
      GestureDetector(
        onTap: () async {
          final picked = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 1)), firstDate: DateTime.now(), lastDate: DateTime(2099));
          if (picked != null) setState(() => _dueDate = '${picked.year}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}');
        },
        child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(10)), child: Row(children: [const Icon(Icons.calendar_today, size: 16, color: Colors.grey), const SizedBox(width: 8), Text(_dueDate.isEmpty ? 'Pick date' : _dueDate, style: TextStyle(color: _dueDate.isEmpty ? Colors.grey : Colors.black))])),
      ),
      const SizedBox(height: 14),
      const Text('Instructions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), const SizedBox(height: 6),
      TextField(controller: _descCtrl, maxLines: 4, decoration: _deco(hint: 'Task details...')),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(
        onPressed: _loading ? null : _assignTask,
        icon: const Icon(Icons.send),
        label: const Text('Assign Now', style: TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(backgroundColor: _kOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      )),
    ]),
  );

  Widget _buildHistory() {
    final groups = _groupedTasks.values.toList();
    if (_selectedAssignment != null) {
      final grp = _selectedAssignment as Map<String, dynamic>;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextButton.icon(icon: const Icon(Icons.arrow_back, size: 16), label: const Text('Back to Assignments'), onPressed: () => setState(() => _selectedAssignment = null)),
        const SizedBox(height: 12),
        Text(grp['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        Text('Due: ${grp['due_date'] ?? ''}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 12),
        Text('${grp['completed']}/${grp['total']} Completed', style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ...(grp['members'] as List).map((m) => Container(
          margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
          child: Row(children: [
            Expanded(child: Text(m['member_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: (m['done'] == true ? _kGreen : Colors.orange).withAlpha(25), borderRadius: BorderRadius.circular(20)), child: Text(m['done'] == true ? 'Submitted' : 'Pending', style: TextStyle(color: m['done'] == true ? _kGreen : Colors.orange, fontSize: 11, fontWeight: FontWeight.w700))),
            const SizedBox(width: 8),
            Text(m['admin_verified'] == true ? '✅ Verified' : m['submission_id'] != null ? '⏳ Awaiting' : '—', style: const TextStyle(fontSize: 12)),
          ]),
        )),
      ]);
    }
    if (groups.isEmpty) return Container(padding: const EdgeInsets.all(48), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)), child: const Center(child: Text('No assignments found.', style: TextStyle(color: Colors.grey))));
    return Column(children: groups.map((g) {
      final total = g['total'] as int, done = g['completed'] as int;
      return Container(
        margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(g['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 4),
          Text('Due: ${g['due_date'] ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: LinearProgressIndicator(value: total > 0 ? done / total : 0, color: _kOrange, backgroundColor: Colors.grey.shade200, minHeight: 6)),
                const SizedBox(width: 8),
                Text('$done/$total', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ])),
            const SizedBox(width: 12),
            TextButton(onPressed: () => setState(() => _selectedAssignment = g), child: const Text('View', style: TextStyle(color: _kOrange))),
          ]),
        ]),
      );
    }).toList());
  }

  Widget _buildSubmissions() {
    if (_submissions.isEmpty) return Container(padding: const EdgeInsets.all(48), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)), child: const Center(child: Text('No submissions yet.', style: TextStyle(color: Colors.grey))));
    return Column(children: _submissions.map((task) {
      final sid = task['submission_id'] as int?;
      _verifyCtrl.putIfAbsent(sid ?? 0, () => TextEditingController());
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.all(14), color: task['admin_verified'] == true ? _kGreen.withAlpha(12) : _kOrange.withAlpha(8), child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(task['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Row(children: [const Icon(Icons.person_outline, size: 14, color: _kOrange), const SizedBox(width: 4), Text(task['member_name'] ?? '', style: const TextStyle(color: _kOrange, fontSize: 12, fontWeight: FontWeight.w600))]),
            ])),
            task['admin_verified'] == true
              ? Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: _kGreen.withAlpha(25), borderRadius: BorderRadius.circular(20)), child: const Text('Verified', style: TextStyle(color: _kGreen, fontWeight: FontWeight.w800, fontSize: 12)))
              : ElevatedButton(onPressed: () => setState(() => _verifyingId = _verifyingId == sid ? null : sid), style: ElevatedButton.styleFrom(backgroundColor: _kOrange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap), child: const Text('Mark Verified', style: TextStyle(fontSize: 12))),
          ])),
          if (task['completion_note'] != null) Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('MEMBER NOTE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey)), const SizedBox(height: 6), Text(task['completion_note'], style: const TextStyle(fontSize: 14, height: 1.5))])),
          if (_verifyingId == sid) Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Admin Notes (optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(controller: _verifyCtrl[sid ?? 0], maxLines: 2, onChanged: (v) => _verifyNotes[sid ?? 0] = v, decoration: InputDecoration(hintText: 'Any notes for the member...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.all(12))),
              const SizedBox(height: 10),
              Row(children: [
                ElevatedButton(onPressed: () => _verify(sid!), style: ElevatedButton.styleFrom(backgroundColor: _kGreen, foregroundColor: Colors.white), child: const Text('Confirm Verified')),
                const SizedBox(width: 10),
                TextButton(onPressed: () => setState(() => _verifyingId = null), child: const Text('Cancel')),
              ]),
            ]),
          ),
        ]),
      );
    }).toList());
  }

  InputDecoration _deco({String? hint}) => InputDecoration(hintText: hint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.all(12));
}
