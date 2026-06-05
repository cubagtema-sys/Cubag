import 'package:flutter/material.dart';
import '../components/app_layout.dart';
import '../components/custom_dropdown.dart';
import '../services/api_service.dart';

const _kOrange = Color(0xFFf08232);
const _kGreen  = Color(0xFF10b981);
const _kRed    = Color(0xFFef4444);

class AdminSurveysPage extends StatefulWidget {
  const AdminSurveysPage({super.key});
  @override State<AdminSurveysPage> createState() => _State();
}

class _State extends State<AdminSurveysPage> {
  final _api = ApiService();
  List<dynamic> _surveys = [];
  bool _loading = true, _submitting = false;
  String _tab = 'active';
  dynamic _viewingResults;
  Map<String, dynamic>? _resultsData;


  // Create form
  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  String _type = 'Survey', _method = 'Multiple Choice', _deadline = '';
  List<Map<String, String>> _options = [{'name': ''}];

  @override void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    if (_loading == false) setState(() => _loading = true);
    final data = await _api.fetchData('surveys/admin/all');
    if (mounted) setState(() { _surveys = data is List ? data : []; _loading = false; });
  }

  Future<void> _create() async {
    if (_titleCtrl.text.isEmpty || _descCtrl.text.isEmpty || _deadline.isEmpty) return;
    setState(() => _submitting = true);
    await _api.postData('surveys', {
      'title': _titleCtrl.text, 'description': _descCtrl.text,
      'type': _type, 'method': _method, 'deadline': _deadline,
      'options': _options,
    });
    _titleCtrl.clear(); _descCtrl.clear();
    setState(() { _submitting = false; _options = [{'name': ''}]; _deadline = ''; _tab = 'active'; });
    await _fetch();
  }

  Future<void> _delete(int id) async {
    await _api.deleteData('surveys/$id');

    await _fetch();
  }

  Future<void> _viewResults(dynamic survey) async {
    setState(() { _viewingResults = survey; _resultsData = null; });
    final data = await _api.fetchData('surveys/${survey['id']}/participation');
    if (mounted) setState(() => _resultsData = data is Map ? Map<String, dynamic>.from(data) : null);
  }

  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
  }

  List<dynamic> get _active => _surveys.where((s) {
    if (s['active'] == false) return false;
    if (s['deadline'] == null) return true;
    return s['deadline'].toString().compareTo(_today()) >= 0;
  }).toList();

  List<dynamic> get _past => _surveys.where((s) {
    return s['active'] == false || (s['deadline'] != null && s['deadline'].toString().compareTo(_today()) < 0);
  }).toList();

  @override
  Widget build(BuildContext context) {
    if (_viewingResults != null) return AppLayout(title: 'Survey Results', child: _buildResultsView());
    final tabs = [
      {'id': 'active',  'label': 'Active (${_active.length})'},
      {'id': 'history', 'label': 'History (${_past.length})'},
      {'id': 'create',  'label': 'New Poll'},
    ];
    return AppLayout(
      title: 'Surveys & Elections',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Tab bar
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
          child: Row(children: tabs.map((t) {
            final active = _tab == t['id'];
            return Expanded(child: GestureDetector(
              onTap: () => setState(() => _tab = t['id']!),
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
        const SizedBox(height: 16),
        if (_tab == 'create')  _buildCreateForm(),
        if (_tab == 'active')  _buildSurveyList(_active),
        if (_tab == 'history') _buildSurveyList(_past),
      ]),
    );
  }

  Widget _buildCreateForm() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Create New Poll / Election', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 16),
      _field('Title', _titleCtrl, hint: 'e.g. 2026 Presidential Election'),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Poll Type', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), const SizedBox(height: 6),
          CustomDropdown<String>(
            value: _type,
            items: const [
              DropdownItem(value: 'Survey', label: 'Survey'),
              DropdownItem(value: 'Election', label: 'Election'),
            ],
            onChanged: (v) => setState(() => _type = v),
          ),
        ])),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Response Method', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), const SizedBox(height: 6),
          CustomDropdown<String>(
            value: _method,
            items: const [
              DropdownItem(value: 'Multiple Choice', label: 'Multiple Choice'),
              DropdownItem(value: 'Yes/No', label: 'Yes/No'),
              DropdownItem(value: 'Star Rating', label: 'Star Rating'),
            ],
            onChanged: (v) {
              setState(() {
                _method = v;
                if (v == 'Yes/No') {
                  _options = [{'name': 'Yes'}, {'name': 'No'}];
                } else if (v == 'Star Rating') {
                  _options = [];
                } else {
                  _options = [{'name': ''}];
                }
              });
            },
          ),
        ])),
      ]),
      const SizedBox(height: 14),
      _field('Description', _descCtrl, hint: 'Instructions for the voters...', maxLines: 3),
      const SizedBox(height: 14),
      const Text('Deadline', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), const SizedBox(height: 6),
      GestureDetector(
        onTap: () async {
          final picked = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 1)), firstDate: DateTime.now(), lastDate: DateTime(2099));
          if (picked != null) setState(() => _deadline = '${picked.year}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                _deadline.isEmpty ? 'Pick deadline' : _deadline,
                style: TextStyle(color: _deadline.isEmpty ? Colors.grey.shade600 : Colors.black, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
      if (_method == 'Multiple Choice') ...[
        const SizedBox(height: 14),
        Row(children: [const Text('Options / Candidates', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), const Spacer(), TextButton.icon(icon: const Icon(Icons.add, size: 16), label: const Text('Add'), onPressed: () => setState(() => _options.add({'name': ''})))]),
        const SizedBox(height: 8),
        ..._options.asMap().entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Expanded(child: TextFormField(initialValue: e.value['name'], decoration: _deco(hint: 'Candidate name...'), onChanged: (v) => _options[e.key]['name'] = v)),
            if (_options.length > 1) IconButton(icon: const Icon(Icons.delete, color: _kRed), onPressed: () => setState(() => _options.removeAt(e.key))),
          ]),
        )),
      ],
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
        onPressed: _submitting ? null : _create,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kOrange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Text(_submitting ? 'Creating...' : 'Publish Poll', style: const TextStyle(fontWeight: FontWeight.bold)),
      )),
    ]),
  );

  Widget _buildSurveyList(List surveys) {
    if (_loading) return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: _kOrange)));
    if (surveys.isEmpty) return Container(padding: const EdgeInsets.all(48), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)), child: const Center(child: Text('No polls found.', style: TextStyle(color: Colors.grey))));
    return Column(children: surveys.map((s) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 6)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: _kOrange.withAlpha(25), borderRadius: BorderRadius.circular(20)), child: Text(s['type'] ?? 'Survey', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _kOrange))),
          const Spacer(),
          TextButton(onPressed: () => _viewResults(s), child: const Text('Results', style: TextStyle(color: _kOrange))),
          IconButton(icon: const Icon(Icons.delete_outline, color: _kRed, size: 20), onPressed: () { _delete(s['id']); }),
        ]),
        const SizedBox(height: 8),
        Text(s['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 4),
        Text('Deadline: ${s['deadline'] ?? 'No deadline'}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        if (s['description'] != null) ...[const SizedBox(height: 8), Text(s['description'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.grey))],
      ]),
    )).toList());
  }

  Widget _buildResultsView() {
    final s = _viewingResults;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextButton.icon(icon: const Icon(Icons.arrow_back, size: 16), label: const Text('Back to list'), onPressed: () => setState(() => _viewingResults = null)),
      Text(s['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
      const SizedBox(height: 4),
      Text('${s['type']} • Deadline: ${s['deadline'] ?? 'None'}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
      const SizedBox(height: 20),
      if (_resultsData == null) const Center(child: CircularProgressIndicator(color: _kOrange))
      else ...[
        Row(children: [
          _statCard('Responses', '${(_resultsData!['responded'] as List?)?.length ?? 0}/${_resultsData!['total'] ?? 0}', _kOrange),
          const SizedBox(width: 12),
          _statCard('Participation', '${_resultsData!['response_rate'] ?? 0}%', _kGreen),
        ]),
        const SizedBox(height: 20),
        if (_resultsData!['tallies'] != null && (_resultsData!['tallies'] as Map).isNotEmpty) ...[
          const Text('Voting Results', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 12),
          ...(_resultsData!['tallies'] as Map).entries.map((e) {
            final count = (_resultsData!['responded'] as List?)?.length ?? 0;
            final total = count > 0 ? count : 1;
            final pct = (((e.value as num?) ?? 0) / total).clamp(0, 1);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600))), Text(e.value.toString(), style: const TextStyle(fontWeight: FontWeight.w800))]),
                const SizedBox(height: 4),
                LinearProgressIndicator(value: pct.toDouble(), color: _kOrange, backgroundColor: Colors.grey.shade200, minHeight: 8),
              ]),
            );
          }),
        ],
      ],
    ]);
  }

  Widget _statCard(String label, String val, Color color) => Expanded(child: Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: color.withAlpha(15), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withAlpha(40))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color, textBaseline: TextBaseline.alphabetic)),
      const SizedBox(height: 6),
      Text(val, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
    ]),
  ));

  Widget _field(String label, TextEditingController ctrl, {String? hint, int maxLines = 1}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), const SizedBox(height: 6),
    TextField(controller: ctrl, maxLines: maxLines, decoration: _deco(hint: hint)),
  ]);

  InputDecoration _deco({String? hint}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748b)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kOrange, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 2)),
      );
}
