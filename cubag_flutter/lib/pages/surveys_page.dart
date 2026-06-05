import 'dart:convert';
import 'package:flutter/material.dart';
import '../components/app_layout.dart';
import '../services/api_service.dart';

class SurveysPage extends StatefulWidget {
  const SurveysPage({super.key});
  @override
  State<SurveysPage> createState() => _SurveysPageState();
}

class _SurveysPageState extends State<SurveysPage> {
  bool _loading = true;
  List<dynamic> _surveys = [];
  String _tab = 'active';
  Map<String, dynamic>? _answering;
  String _selected = '';
  bool _submitting = false;
  String? _toast;
  bool _toastSuccess = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().get('/surveys');
      if (res.statusCode == 200) setState(() => _surveys = res.data ?? []);
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _showToast(String msg, bool success) {
    setState(() { _toast = msg; _toastSuccess = success; });
    Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _toast = null); });
  }

  Future<void> _submit() async {
    if (_selected.isEmpty) { _showToast('Please select an option.', false); return; }
    setState(() => _submitting = true);
    try {
      await ApiService().post('/surveys/${_answering!['id']}/respond', data: {'answers': {'vote': _selected}});
      setState(() { _answering = null; _selected = ''; });
      _showToast('Your response has been submitted successfully!', true);
      _fetch();
    } catch (_) {
      _showToast('An error occurred while submitting.', false);
    }
    setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final today = DateTime.now();
    final active = _surveys.where((s) => s['active'] == true && (s['deadline'] == null || DateTime.tryParse(s['deadline'].toString())?.isAfter(today) == true)).toList();
    final past = _surveys.where((s) => s['active'] != true || (s['deadline'] != null && DateTime.tryParse(s['deadline'].toString())?.isBefore(today) == true)).toList();
    final shown = _tab == 'active' ? active : past;

    return AppLayout(
      title: 'Surveys',
      child: Stack(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Surveys & Elections', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Text('Participate in association polls and elections.', style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 16),

          if (_answering != null)
            _buildAnswerForm(primary)
          else ...[
            // Tabs
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Expanded(child: _tab == 'active' ? _activeTab('active', '🗳 Active (${active.length})', primary) : _inactiveTab('active', '🗳 Active (${active.length})', primary)),
                Expanded(child: _tab == 'history' ? _activeTab('history', '📋 Past (${past.length})', primary) : _inactiveTab('history', '📋 Past (${past.length})', primary)),
              ]),
            ),
            const SizedBox(height: 16),

            // Survey list
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            else if (shown.isEmpty)
              Container(padding: const EdgeInsets.all(60), alignment: Alignment.center, decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)), child: const Column(children: [Icon(Icons.ballot, size: 48, color: Colors.grey), SizedBox(height: 12), Text('No surveys found.', style: TextStyle(color: Colors.grey))]))
            else
              ...shown.map((s) => _surveyCard(s, primary)),
          ],
        ]),

        // Toast
        if (_toast != null)
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(child: Center(child: Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(color: _toastSuccess ? const Color(0xFF10b981) : Colors.red, borderRadius: BorderRadius.circular(12), boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 16)]),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_toastSuccess ? Icons.check_circle : Icons.error, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(_toast!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ]),
            ))),
          ),
      ]),
    );
  }

  Widget _activeTab(String id, String label, Color primary) => GestureDetector(
    onTap: () => setState(() => _tab = id),
    child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)]), alignment: Alignment.center, child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: primary))),
  );

  Widget _inactiveTab(String id, String label, Color primary) => GestureDetector(
    onTap: () => setState(() => _tab = id),
    child: Container(padding: const EdgeInsets.symmetric(vertical: 10), alignment: Alignment.center, child: Text(label, style: const TextStyle(color: Colors.grey))),
  );

  Widget _surveyCard(Map<String, dynamic> s, Color primary) {
    final isElection = s['type']?.toString() == 'Election';
    final color = isElection ? const Color(0xFF8b5cf6) : primary;
    final deadline = s['deadline'] != null ? DateTime.tryParse(s['deadline'].toString()) : null;
    final deadlineLabel = deadline != null ? '${deadline.day} ${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][deadline.month - 1]} ${deadline.year}' : 'None';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)), child: Text((s['type']?.toString() ?? 'Survey').toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color))),
        const SizedBox(height: 8),
        Text(s['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        Text(s['description']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Deadline: $deadlineLabel', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          if (_tab == 'active')
            s['has_responded'] == true
              ? const Row(children: [Icon(Icons.check_circle, color: Color(0xFF10b981), size: 18), SizedBox(width: 4), Text('Voted', style: TextStyle(color: Color(0xFF10b981), fontWeight: FontWeight.bold, fontSize: 13))])
              : ElevatedButton(
                  onPressed: () => setState(() { _answering = Map<String, dynamic>.from(s); _selected = ''; }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Participate', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                )
          else
            const Text('Closed', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
      ]),
    );
  }

  Widget _buildAnswerForm(Color primary) {
    final s = _answering!;
    final isElection = s['type']?.toString() == 'Election';
    final color = isElection ? const Color(0xFF8b5cf6) : primary;
    List<dynamic> options = [];
    try {
      final rawOptions = s['options'];
      if (rawOptions is List) {
        options = rawOptions;
      } else if (rawOptions is String && rawOptions.isNotEmpty) {
        options = jsonDecode(rawOptions) as List;
      }
    } catch (_) {}

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextButton.icon(onPressed: () => setState(() => _answering = null), icon: const Icon(Icons.arrow_back), label: const Text('Back'), style: TextButton.styleFrom(foregroundColor: Colors.grey)),
      const SizedBox(height: 8),
      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)), child: Text((s['type']?.toString() ?? 'Survey').toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color))),
      const SizedBox(height: 10),
      Text(s['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
      const SizedBox(height: 6),
      Text(s['description']?.toString() ?? '', style: const TextStyle(color: Colors.grey, fontSize: 14)),
      const SizedBox(height: 24),

      // Star Rating
      if (options.isEmpty) ...[
        const Text('Rate experience:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) {
          final star = i + 1;
          final filled = int.tryParse(_selected) != null && int.parse(_selected) >= star;
          return IconButton(icon: Icon(filled ? Icons.star : Icons.star_border, color: const Color(0xFFf59e0b), size: 36), onPressed: () => setState(() => _selected = '$star'));
        })),
      ] else ...[
        const Text('Select choice:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        RadioGroup<String>(
          groupValue: _selected,
          onChanged: (v) => setState(() => _selected = v!),
          child: Wrap(spacing: 12, runSpacing: 12, children: options.map((opt) {
            final name = opt['name']?.toString() ?? opt.toString();
            final sel = _selected == name;
            return GestureDetector(
              onTap: () => setState(() => _selected = name),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                width: 140,
                decoration: BoxDecoration(border: Border.all(color: sel ? primary : Colors.grey.shade300, width: sel ? 2.5 : 1.5), borderRadius: BorderRadius.circular(12), color: sel ? primary.withValues(alpha: 0.05) : null),
                child: Column(children: [
                  CircleAvatar(radius: 28, backgroundColor: Colors.grey.shade100, child: const Icon(Icons.person, color: Colors.grey, size: 28)),
                  const SizedBox(height: 8),
                  Text(name, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: sel ? primary : null)),
                  const SizedBox(height: 6),
                  Radio<String>(value: name, activeColor: primary),
                ]),
              ),
            );
          }).toList()),
        ),
      ],
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
        onPressed: _submitting || _selected.isEmpty ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _submitting ? const CircularProgressIndicator(color: Colors.white) : const Text('Submit Response', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      )),
    ]);
  }
}
