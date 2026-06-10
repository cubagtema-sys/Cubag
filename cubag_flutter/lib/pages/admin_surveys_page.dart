import 'dart:async';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../components/app_layout.dart';
import '../components/custom_dropdown.dart';
import '../services/api_service.dart';
import '../components/shimmer_loader.dart';

const _kOrange = Color(0xFFf08232);
const _kGreen  = Color(0xFF10b981);
const _kRed    = Color(0xFFef4444);
const _kPurple = Color(0xFF8b5cf6);
const _kBlue   = Color(0xFF3b82f6);
const _kAmber  = Color(0xFFf59e0b);

class AdminSurveysPage extends StatefulWidget {
  const AdminSurveysPage({super.key});
  @override State<AdminSurveysPage> createState() => _State();
}

class _State extends State<AdminSurveysPage> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  List<dynamic> _surveys = [];
  bool _loading = true, _submitting = false;
  bool _loadingMore = false;
  String _tab = 'active';
  dynamic _viewingResults;
  Map<String, dynamic>? _resultsData;
  bool _resultsLoading = false;
  Timer? _refreshTimer;
  int _countdown = 15;
  
  int _page = 1;
  int _total = 0;
  bool _hasMore = true;

  final ScrollController _scrollController = ScrollController();

  // Create form
  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  String _type = 'Survey', _method = 'Multiple Choice', _deadline = '';

  // Cover image
  String? _coverImageUrl;
  bool _uploadingCover = false;

  // Options: each entry has 'name' (String) and 'photo' (String?)
  List<Map<String, String?>> _options = [{'name': '', 'photo': null}];
  // Track which option index is uploading its photo
  Set<int> _uploadingOptionIdx = {};

  @override
  void initState() { 
    super.initState(); 
    _fetch(); 
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _refreshTimer?.cancel();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_viewingResults != null) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_loading && !_loadingMore && _hasMore && _tab != 'create') {
        _fetchMore();
      }
    }
  }

  void _onTabChanged(String newTab) {
    if (_tab == newTab) return;
    setState(() => _tab = newTab);
    if (newTab != 'create') {
      _fetch(refresh: true);
    }
  }

  // ── Data ──────────────────────────────────────────────────────

  Future<void> _fetch({bool refresh = false}) async {
    if (!mounted) return;
    if (refresh) {
      setState(() { _page = 1; _hasMore = true; _loading = true; _surveys = []; });
    } else {
      if (!_loading) setState(() => _loading = true);
    }
    await _api.fetchDataWithCache('surveys/admin/all?page=$_page&per_page=20&status=$_tab', (data, isCached) {
      if (mounted && data != null) {
        setState(() {
          final raw = data is Map ? (data['data'] ?? data['items'] ?? data) : data;
          _surveys = raw is List ? raw : [];
          if (data is Map && data.containsKey('total')) {
            _total = data['total'];
            _hasMore = _surveys.length < _total;
          } else {
            _hasMore = false;
          }
          _loading = false;
        });
      }
    });
  }

  Future<void> _fetchMore() async {
    setState(() => _loadingMore = true);
    _page++;
    try {
      final data = await _api.fetchData('surveys/admin/all?page=$_page&per_page=20&status=$_tab');
      if (mounted) {
        final raw = data is Map ? (data['data'] ?? data['items'] ?? data) : data;
        final newItems = raw is List ? raw : [];
        setState(() {
          _surveys.addAll(newItems);
          if (data is Map && data.containsKey('total')) {
            _hasMore = _surveys.length < data['total'];
          } else {
            _hasMore = newItems.isNotEmpty;
          }
        });
      }
    } catch (_) { _page--; }
    if (mounted) setState(() => _loadingMore = false);
  }

  Future<void> _loadResults(dynamic survey) async {
    setState(() { _viewingResults = survey; _resultsData = null; _resultsLoading = true; });
    _startAutoRefresh(survey['id']);
    await _refreshResults(survey['id']);
  }

  Future<void> _refreshResults(int surveyId) async {
    final data = await _api.fetchData('surveys/$surveyId/participation');
    if (mounted) setState(() {
      _resultsData = data is Map ? Map<String, dynamic>.from(data) : null;
      _resultsLoading = false;
      _countdown = 15;
    });
  }

  void _startAutoRefresh(int surveyId) {
    _refreshTimer?.cancel();
    _countdown = 15;
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _countdown--);
      if (_countdown <= 0) { _countdown = 15; _refreshResults(surveyId); }
    });
  }

  void _closeResults() {
    _refreshTimer?.cancel();
    setState(() { _viewingResults = null; _resultsData = null; });
  }

  // ── Image Upload ───────────────────────────────────────────────

  /// Upload any image to /uploads/image and return its public URL (or null).
  Future<String?> _uploadImage({String fieldName = 'image'}) async {
    final result = await FilePicker.pickFiles(
      type: FileType.image, allowMultiple: false, withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    if (file.bytes == null && file.path == null) return null;

    late MultipartFile mpFile;
    if (file.bytes != null) {
      mpFile = MultipartFile.fromBytes(file.bytes!, filename: file.name);
    } else {
      mpFile = await MultipartFile.fromFile(file.path!, filename: file.name);
    }

    try {
      final res = await _api.upload('/uploads/image', FormData.fromMap({'image': mpFile}));
      if (res.statusCode == 201 && res.data['url'] != null) {
        return res.data['url'].toString();
      }
      _showSnack('Upload failed: ${res.data['message'] ?? 'Unknown error'}', isError: true);
      return null;
    } catch (e) {
      _showSnack('Upload error: $e', isError: true);
      return null;
    }
  }

  Future<void> _pickCoverImage() async {
    setState(() => _uploadingCover = true);
    final url = await _uploadImage();
    setState(() { _coverImageUrl = url ?? _coverImageUrl; _uploadingCover = false; });
    if (url != null) _showSnack('Cover image uploaded ✓');
  }

  Future<void> _pickOptionPhoto(int idx) async {
    setState(() => _uploadingOptionIdx = {..._uploadingOptionIdx, idx});
    final url = await _uploadImage();
    if (url != null) setState(() { _options[idx] = {..._options[idx], 'photo': url}; });
    setState(() { final s = Set<int>.from(_uploadingOptionIdx); s.remove(idx); _uploadingOptionIdx = s; });
    if (url != null) _showSnack('Candidate photo uploaded ✓');
  }

  // ── CRUD ───────────────────────────────────────────────────────

  Future<void> _create() async {
    if (_titleCtrl.text.isEmpty || _descCtrl.text.isEmpty || _deadline.isEmpty) {
      _showSnack('Please fill in all required fields.', isError: true);
      return;
    }
    setState(() => _submitting = true);
    final res = await _api.post('/surveys', data: {
      'title':       _titleCtrl.text,
      'description': _descCtrl.text,
      'type':        _type,
      'method':      _method,
      'deadline':    _deadline,
      'cover_image': _coverImageUrl,
      'options':     _options
          .where((o) => (o['name'] ?? '').isNotEmpty)
          .map((o) => {'name': o['name'], 'photo': o['photo']})
          .toList(),
    });
    if (res.statusCode == 201) {
      _titleCtrl.clear(); _descCtrl.clear();
      setState(() {
        _submitting = false;
        _options = [{'name': '', 'photo': null}];
        _deadline = '';
        _coverImageUrl = null;
        _tab = 'active';
      });
      _showSnack('Poll published successfully!');
      await _fetch(refresh: true);
    } else {
      setState(() => _submitting = false);
      _showSnack('Failed to create poll.', isError: true);
    }
  }

  Future<void> _delete(int id) async {
    await _api.deleteData('surveys/$id');
    if (_viewingResults != null && _viewingResults['id'] == id) _closeResults();
    await _fetch(refresh: true);
  }

  Future<void> _toggleActive(dynamic survey) async {
    final res = await _api.put('/surveys/${survey['id']}/toggle-active');
    if (res.statusCode == 200) {
      _showSnack(res.data['message'] ?? 'Status updated');
      await _fetch(refresh: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? _kRed : _kGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Helpers ─────────────────────────────────────────────────

  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
  }

  Color _typeColor(String? t) { switch (t?.toLowerCase()) { case 'election': return _kPurple; case 'poll': return _kBlue; default: return _kOrange; } }
  IconData _typeIcon(String? t) { switch (t?.toLowerCase()) { case 'election': return Icons.how_to_vote_outlined; case 'poll': return Icons.bar_chart_outlined; default: return Icons.assignment_outlined; } }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_viewingResults != null) return AppLayout(title: 'Live Results', child: _buildResultsView());
    final tabs = [
      {'id': 'active',  'label': 'Active'},
      {'id': 'history', 'label': 'History'},
      {'id': 'create',  'label': 'New Poll'},
    ];
    return AppLayout(
      title: 'Surveys & Elections',
      scrollable: false,
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: const Color(0xFFf1f5f9), borderRadius: BorderRadius.circular(14)),
            child: Row(children: tabs.map((t) {
              final isActive = _tab == t['id'];
              return Expanded(child: GestureDetector(
                onTap: () => _onTabChanged(t['id']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isActive ? [BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 8, offset: const Offset(0, 2))] : [],
                  ),
                  alignment: Alignment.center,
                  child: Text(t['label']!, style: TextStyle(color: isActive ? _kOrange : const Color(0xFF64748b), fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ));
            }).toList()),
          ),
          const SizedBox(height: 20),
          if (_tab == 'create')  _buildCreateForm(),
          if (_tab != 'create')  _buildSurveyList(),
        ]),
      ),
    );
  }

  // ── Survey Card List ─────────────────────────────────────────

  Widget _buildSurveyList() {
    return LayoutBuilder(builder: (context, constraints) {
      double cardWidth = constraints.maxWidth;
      if (constraints.maxWidth > 1200) {
        cardWidth = (constraints.maxWidth - 48) / 4;
      } else if (constraints.maxWidth > 800) {
        cardWidth = (constraints.maxWidth - 32) / 3;
      } else if (constraints.maxWidth > 600) {
        cardWidth = (constraints.maxWidth - 16) / 2;
      }

      if (_loading) {
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: List.generate(8, (_) => SizedBox(
            width: cardWidth,
            height: 240,
            child: const ShimmerGridCard(),
          )),
        );
      }

      if (_surveys.isEmpty) return _emptyState();

      return Column(children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: _surveys.map((s) => SizedBox(
            width: cardWidth,
            child: _surveyCard(s),
          )).toList(),
        ),
        if (_loadingMore) const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: _kOrange)),
        if (!_loading && _total > 0) Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Text('${_surveys.length} of $_total polls shown', style: const TextStyle(fontSize: 12, color: Colors.grey))),
      ]);
    });
  }

  Widget _emptyState() => Container(
    padding: const EdgeInsets.all(48),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFe2e8f0))),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(color: Color(0xFFf1f5f9), shape: BoxShape.circle), child: const Icon(Icons.ballot_outlined, size: 40, color: Color(0xFF94a3b8))),
      const SizedBox(height: 16),
      const Text('No polls found', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF475569))),
      const SizedBox(height: 4),
      const Text('Create a new poll using the "New Poll" tab.', style: TextStyle(fontSize: 13, color: Color(0xFF94a3b8))),
    ]),
  );

  Widget _surveyCard(dynamic s) {
    final type = s['type']?.toString() ?? 'Survey';
    final color = _typeColor(type);
    final icon  = _typeIcon(type);
    final isActive = s['active'] != false;
    final deadline = s['deadline']?.toString();
    final isExpired = deadline != null && deadline.compareTo(_today()) < 0;
    final statusLabel = !isActive ? 'Closed' : isExpired ? 'Expired' : 'Active';
    final statusColor = !isActive ? _kRed : isExpired ? _kAmber : _kGreen;
    final coverImage = s['cover_image']?.toString();

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFe2e8f0)), boxShadow: [BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 10, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Cover image if present
        if (coverImage != null && coverImage.isNotEmpty)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.network(coverImage, width: double.infinity, height: 120, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          ),
        // Header strip
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: color.withAlpha(10),
            borderRadius: coverImage != null && coverImage.isNotEmpty ? BorderRadius.zero : const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(bottom: BorderSide(color: color.withAlpha(30))),
          ),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 16, color: color)),
            const SizedBox(width: 8),
            Text(type.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.8)),
            const Spacer(),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: statusColor.withAlpha(20), borderRadius: BorderRadius.circular(20)), child: Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0f172a))),
            const SizedBox(height: 4),
            if (s['description'] != null) Text(s['description'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Color(0xFF64748b))),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.calendar_today, size: 13, color: Color(0xFF94a3b8)),
              const SizedBox(width: 4),
              Text(deadline != null ? 'Deadline: $deadline' : 'No deadline', style: const TextStyle(fontSize: 12, color: Color(0xFF64748b))),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () => _loadResults(s),
                icon: const Icon(Icons.bar_chart, size: 15),
                label: const Text('Live Results', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color.withAlpha(80)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 10)),
              )),
              const SizedBox(width: 8),
              _iconBtn(icon: isActive ? Icons.pause_circle_outlined : Icons.play_circle_outlined, color: isActive ? _kAmber : _kGreen, tooltip: isActive ? 'Close Poll' : 'Reopen Poll', onTap: () => _toggleActive(s)),
              const SizedBox(width: 6),
              _iconBtn(icon: Icons.delete_outline, color: _kRed, tooltip: 'Delete', onTap: () => _confirmDelete(s)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _iconBtn({required IconData icon, required Color color, required String tooltip, required VoidCallback onTap}) =>
    Tooltip(message: tooltip, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10), child: Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: color.withAlpha(15), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withAlpha(40))), child: Icon(icon, size: 18, color: color))));

  void _confirmDelete(dynamic s) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Delete Poll', style: TextStyle(fontWeight: FontWeight.w800)),
      content: Text('Are you sure you want to permanently delete "${s['title']}"? All responses will also be deleted.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
        ElevatedButton(onPressed: () { Navigator.pop(ctx); _delete(s['id']); }, style: ElevatedButton.styleFrom(backgroundColor: _kRed, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0), child: const Text('Delete')),
      ],
    ));
  }

  // ── Live Results View ────────────────────────────────────────

  Widget _buildResultsView() {
    final s = _viewingResults;
    final type = s['type']?.toString() ?? 'Survey';
    final color = _typeColor(type);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        InkWell(onTap: _closeResults, borderRadius: BorderRadius.circular(10), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: const Color(0xFFf1f5f9), borderRadius: BorderRadius.circular(10)), child: const Row(children: [Icon(Icons.arrow_back, size: 16, color: Color(0xFF475569)), SizedBox(width: 6), Text('Back', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569)))]))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0f172a)), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('$type • Deadline: ${s['deadline'] ?? 'None'}', style: const TextStyle(color: Color(0xFF64748b), fontSize: 12)),
        ])),
      ]),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: color.withAlpha(10), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withAlpha(30))),
        child: Row(children: [
          _resultsLoading ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: color, strokeWidth: 2)) : Icon(Icons.sync, size: 14, color: color),
          const SizedBox(width: 8),
          Text(_resultsLoading ? 'Refreshing...' : 'Auto-refresh in ${_countdown}s', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          const Spacer(),
          GestureDetector(onTap: () { setState(() => _resultsLoading = true); _refreshResults(s['id']); }, child: Text('Refresh Now', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color, decoration: TextDecoration.underline))),
        ]),
      ),
      const SizedBox(height: 16),
      if (_resultsLoading && _resultsData == null)
        const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator(color: _kOrange)))
      else if (_resultsData == null)
        const Center(child: Text('Could not load results.', style: TextStyle(color: Colors.grey)))
      else
        _buildResultsContent(color),
    ]);
  }

  Widget _buildResultsContent(Color color) {
    final responded    = _resultsData!['responded']     as List? ?? [];
    final notResponded = _resultsData!['not_responded'] as List? ?? [];
    final total        = _resultsData!['total']         as int? ?? 0;
    final rate         = (_resultsData!['response_rate'] as num?)?.toDouble() ?? 0.0;
    final tallies      = _resultsData!['tallies']       as Map? ?? {};
    final avgStars     = (_resultsData!['average_stars'] as num?)?.toDouble() ?? 0.0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _kpiCard('Total Members', '$total', Icons.group, _kBlue),
        const SizedBox(width: 10),
        _kpiCard('Responded', '${responded.length}', Icons.check_circle_outline, _kGreen),
        const SizedBox(width: 10),
        _kpiCard('Pending', '${notResponded.length}', Icons.hourglass_empty, _kAmber),
      ]),
      const SizedBox(height: 16),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFe2e8f0))),
          child: Column(children: [
            SizedBox(
              width: 110, height: 110,
              child: CustomPaint(
                painter: _RingPainter(rate / 100, color),
                child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('${rate.toStringAsFixed(0)}%', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
                  const Text('responded', style: TextStyle(fontSize: 9, color: Color(0xFF94a3b8), fontWeight: FontWeight.w600)),
                ])),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Participation Rate', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFe2e8f0))),
          child: tallies.isNotEmpty
            ? _buildTallyBars(tallies, responded.length, color)
            : avgStars > 0
              ? _buildStarResult(avgStars)
              : const Center(child: Padding(padding: EdgeInsets.all(20), child: Column(children: [Icon(Icons.pending_actions, size: 32, color: Color(0xFFcbd5e1)), SizedBox(height: 8), Text('No votes recorded yet', style: TextStyle(color: Color(0xFF94a3b8), fontSize: 13))]))),
        )),
      ]),
      const SizedBox(height: 16),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _memberList('✅ Responded', responded, _kGreen)),
        const SizedBox(width: 12),
        Expanded(child: _memberList('⏳ Pending', notResponded, _kAmber)),
      ]),
    ]);
  }

  Widget _buildTallyBars(Map tallies, int total, Color color) {
    final maxVotes = tallies.values.fold<int>(0, (m, v) => math.max(m, (v as num).toInt()));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Voting Results', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      const SizedBox(height: 12),
      ...tallies.entries.map((e) {
        final votes  = (e.value as num).toInt();
        final pct    = total > 0 ? (votes / total).clamp(0.0, 1.0) : 0.0;
        final barPct = maxVotes > 0 ? (votes / maxVotes).clamp(0.0, 1.0) : 0.0;
        final isLeader = votes == maxVotes && votes > 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (isLeader) const Icon(Icons.emoji_events, size: 14, color: _kAmber),
              if (isLeader) const SizedBox(width: 4),
              Expanded(child: Text(e.key, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isLeader ? color : const Color(0xFF0f172a)))),
              Text('$votes votes', style: const TextStyle(fontSize: 11, color: Color(0xFF64748b))),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(20)), child: Text('${(pct * 100).toStringAsFixed(1)}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color))),
            ]),
            const SizedBox(height: 5),
            ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: barPct.toDouble(), color: isLeader ? color : color.withAlpha(140), backgroundColor: const Color(0xFFf1f5f9), minHeight: 8)),
          ]),
        );
      }),
    ]);
  }

  Widget _buildStarResult(double avg) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Text('Average Rating', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
    const SizedBox(height: 12),
    Text(avg.toStringAsFixed(1), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: _kAmber)),
    Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) {
      final filled = i < avg; final half = !filled && i < avg.ceil() && avg % 1 >= 0.5;
      return Icon(filled ? Icons.star_rounded : half ? Icons.star_half_rounded : Icons.star_outline_rounded, color: _kAmber, size: 24);
    })),
    const SizedBox(height: 4),
    const Text('out of 5.0', style: TextStyle(fontSize: 12, color: Color(0xFF94a3b8))),
  ]);

  Widget _kpiCard(String label, String value, IconData icon, Color color) => Expanded(child: Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: color.withAlpha(12), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withAlpha(40))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(height: 8),
      Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
      const SizedBox(height: 2),
      Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF94a3b8), letterSpacing: 0.5)),
    ]),
  ));

  Widget _memberList(String title, List members, Color color) => Container(
    constraints: const BoxConstraints(maxHeight: 220),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFe2e8f0))),
    child: Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: color.withAlpha(10), borderRadius: const BorderRadius.vertical(top: Radius.circular(14)), border: Border(bottom: BorderSide(color: color.withAlpha(30)))),
        child: Row(children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: color)),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)), child: Text('${members.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800))),
        ]),
      ),
      Flexible(child: members.isEmpty
        ? const Padding(padding: EdgeInsets.all(20), child: Text('None', style: TextStyle(color: Color(0xFF94a3b8), fontSize: 12)))
        : ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: members.length,
            itemBuilder: (_, i) {
              final m = members[i];
              final vote = m['vote']?.toString();
              return ListTile(
                dense: true,
                leading: CircleAvatar(radius: 14, backgroundColor: color.withAlpha(20), child: Text((m['name']?.toString() ?? '?').substring(0, 1), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color))),
                title: Text(m['name']?.toString() ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                subtitle: Text(m['company']?.toString() ?? m['email']?.toString() ?? '', style: const TextStyle(fontSize: 10, color: Color(0xFF94a3b8))),
                trailing: vote != null ? Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(20)), child: Text(vote, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color))) : null,
              );
            },
          )),
    ]),
  );

  // ── Create Form ──────────────────────────────────────────────

  Widget _buildCreateForm() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFe2e8f0)), boxShadow: [BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 10)]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _kOrange.withAlpha(20), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.add_chart, color: _kOrange, size: 20)),
        const SizedBox(width: 10),
        const Text('Create New Poll / Election', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ]),
      const SizedBox(height: 20),

      // ── Cover / Banner Image ──────────────────────────────
      _labeledWidget('Cover Image (optional)', _buildCoverImagePicker()),
      const SizedBox(height: 14),

      _field('Poll Title *', _titleCtrl, hint: 'e.g. 2026 Board of Directors Election'),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _labeledWidget('Poll Type', CustomDropdown<String>(
          value: _type,
          items: const [
            DropdownItem(value: 'Survey',   label: 'Survey'),
            DropdownItem(value: 'Election', label: 'Election'),
            DropdownItem(value: 'Poll',     label: 'Quick Poll'),
          ],
          onChanged: (v) => setState(() => _type = v),
        ))),
        const SizedBox(width: 12),
        Expanded(child: _labeledWidget('Response Method', CustomDropdown<String>(
          value: _method,
          items: const [
            DropdownItem(value: 'Multiple Choice', label: 'Multiple Choice'),
            DropdownItem(value: 'Yes/No',          label: 'Yes / No'),
            DropdownItem(value: 'Star Rating',     label: 'Star Rating'),
          ],
          onChanged: (v) {
            setState(() {
              _method = v;
              if (v == 'Yes/No')           _options = [{'name': 'Yes', 'photo': null}, {'name': 'No', 'photo': null}];
              else if (v == 'Star Rating') _options = [];
              else                         _options = [{'name': '', 'photo': null}];
            });
          },
        ))),
      ]),
      const SizedBox(height: 14),
      _field('Description *', _descCtrl, hint: 'Provide instructions or context for voters...', maxLines: 3),
      const SizedBox(height: 14),
      _labeledWidget('Deadline *', GestureDetector(
        onTap: () async {
          final picked = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 1)), firstDate: DateTime.now(), lastDate: DateTime(2099));
          if (picked != null) setState(() => _deadline = '${picked.year}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFe2e8f0), width: 1.5), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(Icons.calendar_today, size: 16, color: Color(0xFF94a3b8)),
            const SizedBox(width: 8),
            Text(_deadline.isEmpty ? 'Pick a deadline date' : _deadline, style: TextStyle(color: _deadline.isEmpty ? const Color(0xFF94a3b8) : const Color(0xFF0f172a), fontSize: 13)),
          ]),
        ),
      )),

      if (_method == 'Multiple Choice') ...[
        const SizedBox(height: 14),
        Row(children: [
          const Text('Options / Candidates *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          const Spacer(),
          TextButton.icon(icon: const Icon(Icons.add, size: 16), label: const Text('Add', style: TextStyle(fontSize: 12)), onPressed: () => setState(() => _options.add({'name': '', 'photo': null}))),
        ]),
        const SizedBox(height: 8),
        ..._options.asMap().entries.map((e) => _buildOptionRow(e.key, e.value)),
      ],

      if (_method == 'Yes/No') ...[
        const SizedBox(height: 14),
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _kBlue.withAlpha(10), borderRadius: BorderRadius.circular(12), border: Border.all(color: _kBlue.withAlpha(30))), child: const Row(children: [Icon(Icons.info_outline, size: 16, color: _kBlue), SizedBox(width: 8), Expanded(child: Text('Members will vote with a "Yes" or "No" button.', style: TextStyle(fontSize: 12, color: _kBlue, fontWeight: FontWeight.w600)))])),
      ],
      if (_method == 'Star Rating') ...[
        const SizedBox(height: 14),
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _kAmber.withAlpha(10), borderRadius: BorderRadius.circular(12), border: Border.all(color: _kAmber.withAlpha(30))), child: const Row(children: [Icon(Icons.star, size: 16, color: _kAmber), SizedBox(width: 8), Expanded(child: Text('Members will submit a rating from 1 to 5 stars.', style: TextStyle(fontSize: 12, color: _kAmber, fontWeight: FontWeight.w600)))])),
      ],

      const SizedBox(height: 20),
      SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(
        onPressed: _submitting ? null : _create,
        icon: _submitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.publish_rounded, size: 18),
        label: Text(_submitting ? 'Publishing...' : 'Publish Poll', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        style: ElevatedButton.styleFrom(backgroundColor: _kOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
      )),
    ]),
  );

  // ── Cover Image Picker Widget ─────────────────────────────────

  Widget _buildCoverImagePicker() {
    return GestureDetector(
      onTap: _uploadingCover ? null : _pickCoverImage,
      child: Container(
        width: double.infinity,
        height: 130,
        decoration: BoxDecoration(
          color: const Color(0xFFf8fafc),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _coverImageUrl != null ? _kGreen.withAlpha(80) : const Color(0xFFe2e8f0), width: 1.5),
          image: _coverImageUrl != null
            ? DecorationImage(image: NetworkImage(_coverImageUrl!), fit: BoxFit.cover)
            : null,
        ),
        child: _coverImageUrl != null
          ? Stack(children: [
              // Semi-transparent overlay
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.black.withAlpha(40),
                ),
              ),
              Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.edit, color: Colors.white, size: 22),
                const SizedBox(height: 4),
                const Text('Tap to change', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              ])),
              // Green tick
              Positioned(top: 8, right: 8, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: _kGreen, shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white, size: 12))),
            ])
          : _uploadingCover
            ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: _kOrange, strokeWidth: 2), SizedBox(height: 8), Text('Uploading...', style: TextStyle(color: Color(0xFF64748b), fontSize: 12))]))
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _kOrange.withAlpha(15), shape: BoxShape.circle), child: const Icon(Icons.add_photo_alternate_outlined, color: _kOrange, size: 28)),
                const SizedBox(height: 8),
                const Text('Upload Cover Image', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF475569))),
                const SizedBox(height: 2),
                const Text('PNG, JPG, WEBP — up to 10 MB', style: TextStyle(fontSize: 11, color: Color(0xFF94a3b8))),
              ]),
      ),
    );
  }

  // ── Option Row with Photo Upload ─────────────────────────────

  Widget _buildOptionRow(int idx, Map<String, String?> opt) {
    final photoUrl = opt['photo'];
    final isUploading = _uploadingOptionIdx.contains(idx);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Number badge
        Container(width: 28, height: 28, alignment: Alignment.center, decoration: BoxDecoration(color: _kOrange.withAlpha(20), shape: BoxShape.circle), child: Text('${idx + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _kOrange))),
        const SizedBox(width: 8),

        // Photo avatar (tap to upload)
        GestureDetector(
          onTap: isUploading ? null : () => _pickOptionPhoto(idx),
          child: Stack(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: photoUrl != null ? null : const Color(0xFFf1f5f9),
                border: Border.all(color: photoUrl != null ? _kGreen.withAlpha(80) : const Color(0xFFe2e8f0), width: 1.5),
                image: photoUrl != null
                  ? DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover)
                  : null,
              ),
              child: isUploading
                ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: _kOrange))
                : photoUrl == null
                  ? const Icon(Icons.add_a_photo_outlined, color: Color(0xFF94a3b8), size: 20)
                  : null,
            ),
            if (photoUrl != null && !isUploading)
              Positioned(bottom: 0, right: 0, child: Container(width: 16, height: 16, decoration: const BoxDecoration(color: _kOrange, shape: BoxShape.circle), child: const Icon(Icons.edit, color: Colors.white, size: 9))),
          ]),
        ),
        const SizedBox(width: 8),

        // Name text field
        Expanded(child: TextFormField(
          initialValue: opt['name'],
          decoration: _deco(hint: idx == 0 && _type == 'Election' ? 'Candidate name...' : 'Option label...'),
          onChanged: (v) => setState(() => _options[idx] = {..._options[idx], 'name': v}),
        )),

        // Remove btn
        if (_options.length > 1)
          IconButton(icon: const Icon(Icons.delete_outline, color: _kRed, size: 18), onPressed: () => setState(() => _options.removeAt(idx))),
      ]),
    );
  }

  Widget _labeledWidget(String label, Widget child) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF374151))), const SizedBox(height: 6), child,
  ]);

  Widget _field(String label, TextEditingController ctrl, {String? hint, int maxLines = 1}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF374151))), const SizedBox(height: 6),
    TextField(controller: ctrl, maxLines: maxLines, decoration: _deco(hint: hint)),
  ]);

  InputDecoration _deco({String? hint}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94a3b8)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFe2e8f0), width: 1.5)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kOrange, width: 2)),
  );
}

// ── Ring Painter ─────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _RingPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = math.min(cx, cy) - 10;
    const strokeW = 12.0;

    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: radius), -math.pi / 2, 2 * math.pi, false,
      Paint()..color = const Color(0xFFe2e8f0)..style = PaintingStyle.stroke..strokeWidth = strokeW..strokeCap = StrokeCap.round);

    if (progress > 0) {
      canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: radius), -math.pi / 2, 2 * math.pi * progress.clamp(0, 1), false,
        Paint()
          ..shader = SweepGradient(colors: [color.withAlpha(180), color], startAngle: -math.pi / 2, endAngle: 2 * math.pi - math.pi / 2)
              .createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius))
          ..style = PaintingStyle.stroke..strokeWidth = strokeW..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
