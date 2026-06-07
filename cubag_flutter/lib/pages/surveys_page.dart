import 'dart:convert';
import 'package:flutter/material.dart';
import '../components/app_layout.dart';
import '../services/api_service.dart';

const _kOrange = Color(0xFFf08232);
const _kGreen  = Color(0xFF10b981);
const _kPurple = Color(0xFF8b5cf6);
const _kBlue   = Color(0xFF3b82f6);
const _kAmber  = Color(0xFFf59e0b);
const _kRed    = Color(0xFFef4444);

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
      if (res.statusCode == 200) setState(() => _surveys = ApiService.ensureList(res.data));
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _showToast(String msg, bool success) {
    setState(() { _toast = msg; _toastSuccess = success; });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  Future<void> _submit() async {
    if (_selected.isEmpty) { _showToast('Please select an option first.', false); return; }
    setState(() => _submitting = true);
    try {
      final res = await ApiService().post(
        '/surveys/${_answering!['id']}/respond',
        data: {'answers': {'vote': _selected}},
      );
      if (res.statusCode == 200) {
        setState(() { _answering = null; _selected = ''; });
        _showToast('Your response was submitted successfully! 🎉', true);
        _fetch();
      } else {
        _showToast(res.data?['message'] ?? 'Submission failed.', false);
      }
    } catch (_) {
      _showToast('An error occurred. Please try again.', false);
    }
    setState(() => _submitting = false);
  }

  // ── Helpers ─────────────────────────────────────────────────

  Color _typeColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'election': return _kPurple;
      case 'poll':     return _kBlue;
      default:         return _kOrange;
    }
  }

  IconData _typeIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'election': return Icons.how_to_vote_outlined;
      case 'poll':     return Icons.bar_chart_outlined;
      default:         return Icons.assignment_outlined;
    }
  }

  String _typeEmoji(String? type) {
    switch (type?.toLowerCase()) {
      case 'election': return '🗳️';
      case 'poll':     return '📊';
      default:         return '📋';
    }
  }

  String _deadlineLabel(dynamic deadline) {
    if (deadline == null) return 'No deadline';
    final d = DateTime.tryParse(deadline.toString());
    if (d == null) return deadline.toString();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  List<dynamic> get _active {
    final today = DateTime.now();
    return _surveys.where((s) =>
      s['active'] == true &&
      (s['deadline'] == null || DateTime.tryParse(s['deadline'].toString())?.isAfter(today) == true)
    ).toList();
  }

  List<dynamic> get _past {
    final today = DateTime.now();
    return _surveys.where((s) =>
      s['active'] != true ||
      (s['deadline'] != null && DateTime.tryParse(s['deadline'].toString())?.isBefore(today) == true)
    ).toList();
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final shown = _tab == 'active' ? _active : _past;

    return AppLayout(
      title: 'Surveys & Elections',
      child: Stack(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Page header
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: _kOrange.withAlpha(20), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.how_to_vote_rounded, color: _kOrange, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Surveys & Elections', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0f172a))),
            ])),
          ]),
          const SizedBox(height: 20),

          if (_answering != null)
            _buildAnswerForm()
          else ...[
            // Tabs
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: const Color(0xFFf1f5f9), borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                _tabBtn('active',  '🗳 Active (${_active.length})'),
                _tabBtn('history', '📋 Past (${_past.length})'),
              ]),
            ),
            const SizedBox(height: 16),

            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator(color: _kOrange)))
            else if (shown.isEmpty)
              _emptyState()
            else
              ...shown.map((s) => _surveyCard(Map<String, dynamic>.from(s))),
          ],
        ]),

        // Toast notification
        if (_toast != null)
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(child: Center(child: Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: _toastSuccess ? _kGreen : _kRed,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16)],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_toastSuccess ? Icons.check_circle : Icons.error, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Flexible(child: Text(_toast!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              ]),
            ))),
          ),
      ]),
    );
  }

  Widget _tabBtn(String id, String label) => Expanded(child: GestureDetector(
    onTap: () => setState(() => _tab = id),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: _tab == id ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        boxShadow: _tab == id ? [BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 8, offset: const Offset(0, 2))] : [],
      ),
      alignment: Alignment.center,
      child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: _tab == id ? _kOrange : const Color(0xFF64748b))),
    ),
  ));

  Widget _emptyState() => Container(
    padding: const EdgeInsets.all(48),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFe2e8f0))),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(color: Color(0xFFf1f5f9), shape: BoxShape.circle), child: const Icon(Icons.ballot_outlined, size: 40, color: Color(0xFF94a3b8))),
      const SizedBox(height: 16),
      const Text('No surveys here', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF475569))),
      const SizedBox(height: 4),
      const Text('Check back later for new polls and elections.', style: TextStyle(fontSize: 13, color: Color(0xFF94a3b8))),
    ]),
  );

  // ── Survey Card ────────────────────────────────────────────

  Widget _surveyCard(Map<String, dynamic> s) {
    final type       = s['type']?.toString();
    final color      = _typeColor(type);
    final icon       = _typeIcon(type);
    final emoji      = _typeEmoji(type);
    final hasVoted   = s['has_responded'] == true;
    final isActive   = _tab == 'active';
    final coverImage = s['cover_image']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hasVoted ? _kGreen.withAlpha(50) : const Color(0xFFe2e8f0)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Cover image banner
        if (coverImage != null && coverImage.isNotEmpty)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.network(
              coverImage, width: double.infinity, height: 120, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        // Type strip
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: color.withAlpha(10),
            borderRadius: (coverImage != null && coverImage.isNotEmpty)
                ? BorderRadius.zero
                : const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(bottom: BorderSide(color: color.withAlpha(25))),
          ),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 14, color: color)),
            const SizedBox(width: 8),
            Text('$emoji ${(type ?? 'Survey').toUpperCase()}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.8)),
            const Spacer(),
            if (hasVoted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _kGreen.withAlpha(20), borderRadius: BorderRadius.circular(20)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_circle, color: _kGreen, size: 12),
                  SizedBox(width: 4),
                  Text('Voted', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _kGreen)),
                ]),
              ),
          ]),
        ),
        // Body
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF0f172a))),
            const SizedBox(height: 4),
            Text(s['description']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF64748b), fontSize: 13)),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.calendar_today, size: 13, color: Color(0xFF94a3b8)),
              const SizedBox(width: 4),
              Text('Closes: ${_deadlineLabel(s['deadline'])}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748b))),
            ]),
            const SizedBox(height: 14),
            if (isActive && !hasVoted)
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => setState(() { _answering = s; _selected = ''; }),
                  icon: Icon(icon, size: 18),
                  label: const Text('Participate Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0,
                  ),
                ),
              )
            else if (hasVoted)
              Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: _kGreen.withAlpha(10), borderRadius: BorderRadius.circular(12), border: Border.all(color: _kGreen.withAlpha(40))),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.verified, color: _kGreen, size: 18),
                  SizedBox(width: 8),
                  Text('Your response has been recorded', style: TextStyle(color: _kGreen, fontWeight: FontWeight.w700, fontSize: 13)),
                ]),
              )
            else
              Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: const Color(0xFFf1f5f9), borderRadius: BorderRadius.circular(12)),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.lock_outline, color: Color(0xFF94a3b8), size: 16),
                  SizedBox(width: 8),
                  Text('This poll is now closed', style: TextStyle(color: Color(0xFF94a3b8), fontWeight: FontWeight.w600, fontSize: 13)),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }

  // ── Voting Form ────────────────────────────────────────────

  Widget _buildAnswerForm() {
    final s     = _answering!;
    final type  = s['type']?.toString();
    final color = _typeColor(type);
    final icon  = _typeIcon(type);

    List<dynamic> options = [];
    try {
      final rawOptions = s['options'];
      if (rawOptions is List) {
        options = rawOptions;
      } else if (rawOptions is String && rawOptions.isNotEmpty) {
        options = jsonDecode(rawOptions) as List;
      }
    } catch (_) {}

    final isYesNo      = options.length == 2 && options.any((o) => o['name']?.toString().toLowerCase() == 'yes');
    final isStarRating = options.isEmpty;
    final isMultiple   = !isYesNo && !isStarRating;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Back button
      TextButton.icon(
        onPressed: () => setState(() { _answering = null; _selected = ''; }),
        icon: const Icon(Icons.arrow_back, size: 16),
        label: const Text('Back to list'),
        style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748b)),
      ),
      const SizedBox(height: 8),

      // Survey header card
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color.withAlpha(20), color.withAlpha(8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 16, color: color)),
            const SizedBox(width: 8),
            Text((type ?? 'Survey').toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.8)),
          ]),
          const SizedBox(height: 10),
          Text(s['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF0f172a))),
          const SizedBox(height: 4),
          Text(s['description']?.toString() ?? '', style: const TextStyle(color: Color(0xFF475569), fontSize: 13)),
        ]),
      ),
      const SizedBox(height: 24),

      // Voting UI
      if (isYesNo)       _buildYesNo(color)
      else if (isStarRating) _buildStarRating()
      else if (isMultiple)   _buildMultipleChoice(options, color),

      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity, height: 52,
        child: ElevatedButton.icon(
          onPressed: (_submitting || _selected.isEmpty) ? null : _submit,
          icon: _submitting
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.send_rounded, size: 18),
          label: Text(_submitting ? 'Submitting...' : 'Submit Response', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _selected.isEmpty ? const Color(0xFFcbd5e1) : color,
            foregroundColor: Colors.white, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    ]);
  }

  // ── Yes / No ───────────────────────────────────────────────

  Widget _buildYesNo(Color color) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Cast your vote', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
    const SizedBox(height: 14),
    Row(children: [
      Expanded(child: _voteBtn('Yes', Icons.thumb_up_rounded, _kGreen)),
      const SizedBox(width: 14),
      Expanded(child: _voteBtn('No', Icons.thumb_down_rounded, _kRed)),
    ]),
  ]);

  Widget _voteBtn(String label, IconData icon, Color color) {
    final sel = _selected == label;
    return GestureDetector(
      onTap: () => setState(() => _selected = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 80,
        decoration: BoxDecoration(
          color: sel ? color : color.withAlpha(10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sel ? color : color.withAlpha(60), width: sel ? 2.5 : 1.5),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: sel ? Colors.white : color, size: 26),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: sel ? Colors.white : color)),
        ]),
      ),
    );
  }

  // ── Star Rating ────────────────────────────────────────────

  Widget _buildStarRating() {
    final rating = int.tryParse(_selected) ?? 0;
    const labels = ['', 'Poor', 'Fair', 'Good', 'Very Good', 'Excellent'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Rate your experience', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 16),
      Center(child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) {
          final star   = i + 1;
          final filled = rating >= star;
          return GestureDetector(
            onTap: () => setState(() => _selected = '$star'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(filled ? Icons.star_rounded : Icons.star_outline_rounded, color: _kAmber, size: filled ? 48 : 42),
            ),
          );
        })),
        const SizedBox(height: 10),
        if (rating > 0)
          Text(labels[rating], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kAmber))
        else
          const Text('Tap a star to rate', style: TextStyle(color: Color(0xFF94a3b8), fontSize: 14)),
      ])),
    ]);
  }

  // ── Multiple Choice / Election ─────────────────────────────

  Widget _buildMultipleChoice(List<dynamic> options, Color color) {
    final isElection = _answering?['type']?.toString().toLowerCase() == 'election';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(isElection ? 'Select a candidate' : 'Select your answer', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 14),
      if (isElection)
        Wrap(
          spacing: 12, runSpacing: 12,
          children: options.map((opt) {
            final name     = opt['name']?.toString() ?? opt.toString();
            final photoUrl = opt['photo']?.toString();
            final sel      = _selected == name;
            return GestureDetector(
              onTap: () => setState(() => _selected = name),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 130,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: sel ? color.withAlpha(15) : Colors.white,
                  border: Border.all(color: sel ? color : const Color(0xFFe2e8f0), width: sel ? 2.5 : 1.5),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: sel ? [BoxShadow(color: color.withAlpha(30), blurRadius: 12)] : [],
                ),
                child: Column(children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: sel ? color.withAlpha(25) : const Color(0xFFf1f5f9),
                      border: sel ? Border.all(color: color, width: 2.5) : null,
                      image: (photoUrl != null && photoUrl.isNotEmpty)
                        ? DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover)
                        : null,
                    ),
                    child: (photoUrl == null || photoUrl.isEmpty)
                      ? Icon(Icons.person, color: sel ? color : const Color(0xFF94a3b8), size: 28)
                      : null,
                  ),
                  const SizedBox(height: 8),
                  Text(name, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: sel ? color : const Color(0xFF0f172a))),
                  const SizedBox(height: 6),
                  Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: sel ? color : Colors.transparent,
                      border: Border.all(color: sel ? color : const Color(0xFF94a3b8), width: 2),
                    ),
                    child: sel ? const Icon(Icons.check, color: Colors.white, size: 12) : null,
                  ),
                ]),
              ),
            );
          }).toList(),
        )
      else
        Column(children: options.map((opt) {
          final name = opt['name']?.toString() ?? opt.toString();
          final sel  = _selected == name;
          return GestureDetector(
            onTap: () => setState(() => _selected = name),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: sel ? color.withAlpha(10) : Colors.white,
                border: Border.all(color: sel ? color : const Color(0xFFe2e8f0), width: sel ? 2 : 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: sel ? color : Colors.transparent,
                    border: Border.all(color: sel ? color : const Color(0xFF94a3b8), width: 2),
                  ),
                  child: sel ? const Icon(Icons.check, color: Colors.white, size: 13) : null,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: sel ? color : const Color(0xFF0f172a)))),
              ]),
            ),
          );
        }).toList()),
    ]);
  }
}
