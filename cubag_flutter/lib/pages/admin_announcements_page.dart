import 'package:flutter/material.dart';
import '../components/app_layout.dart';
import '../components/custom_dropdown.dart';
import '../services/api_service.dart';
import '../components/shimmer_loader.dart';

const _kOrange = Color(0xFFf08232);
const _kGreen  = Color(0xFF10b981);
const _kRed    = Color(0xFFef4444);

class AdminAnnouncementsPage extends StatefulWidget {
  const AdminAnnouncementsPage({super.key});
  @override State<AdminAnnouncementsPage> createState() => _State();
}

class _State extends State<AdminAnnouncementsPage> {
  final _api = ApiService();
  
  String _tab = 'history';
  String _category = 'General';
  String _msg = '';
  bool _submitting = false;

  final _titleCtrl = TextEditingController();
  final _bodyCtrl  = TextEditingController();
  
  // Pagination State for Active
  List<dynamic> _active = [];
  bool _loadingActive = true;
  bool _loadingMoreActive = false;
  int _pageActive = 1;
  bool _hasMoreActive = true;

  // Pagination State for Archived
  List<dynamic> _archived = [];
  bool _loadingArchived = true;
  bool _loadingMoreArchived = false;
  int _pageArchived = 1;
  bool _hasMoreArchived = true;

  final ScrollController _scrollController = ScrollController();

  @override void initState() { 
    super.initState(); 
    _fetchActive(); 
    _fetchArchived();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (_tab == 'history' && !_loadingActive && !_loadingMoreActive && _hasMoreActive) {
        _fetchMoreActive();
      } else if (_tab == 'archived' && !_loadingArchived && !_loadingMoreArchived && _hasMoreArchived) {
        _fetchMoreArchived();
      }
    }
  }

  Future<void> _fetchActive({bool refresh = false}) async {
    if (refresh) setState(() { _pageActive = 1; _loadingActive = true; _hasMoreActive = true; });
    await _api.fetchDataWithCache('/announcements/admin/all?archived=false&page=$_pageActive&limit=20', (data, isCached) {
      if (mounted && data != null) {
        setState(() {
          _active = ApiService.ensureList(data);
          if (data is Map && data.containsKey('total')) {
            _hasMoreActive = _active.length < data['total'];
          } else {
            _hasMoreActive = false;
          }
          _loadingActive = false;
        });
      }
    });
  }

  Future<void> _fetchMoreActive() async {
    setState(() => _loadingMoreActive = true);
    _pageActive++;
    try {
      final res = await _api.get('/announcements/admin/all?archived=false&page=$_pageActive&limit=20');
      if (res.statusCode == 200) {
        final data = res.data;
        final newItems = ApiService.ensureList(data);
        setState(() {
          _active.addAll(newItems);
          if (data is Map && data.containsKey('total')) {
            _hasMoreActive = _active.length < data['total'];
          } else {
            _hasMoreActive = newItems.isNotEmpty;
          }
        });
      }
    } catch (_) { _pageActive--; }
    setState(() => _loadingMoreActive = false);
  }

  Future<void> _fetchArchived({bool refresh = false}) async {
    if (refresh) setState(() { _pageArchived = 1; _loadingArchived = true; _hasMoreArchived = true; });
    await _api.fetchDataWithCache('/announcements/admin/all?archived=true&page=$_pageArchived&limit=20', (data, isCached) {
      if (mounted && data != null) {
        setState(() {
          _archived = ApiService.ensureList(data);
          if (data is Map && data.containsKey('total')) {
            _hasMoreArchived = _archived.length < data['total'];
          } else {
            _hasMoreArchived = false;
          }
          _loadingArchived = false;
        });
      }
    });
  }

  Future<void> _fetchMoreArchived() async {
    setState(() => _loadingMoreArchived = true);
    _pageArchived++;
    try {
      final res = await _api.get('/announcements/admin/all?archived=true&page=$_pageArchived&limit=20');
      if (res.statusCode == 200) {
        final data = res.data;
        final newItems = ApiService.ensureList(data);
        setState(() {
          _archived.addAll(newItems);
          if (data is Map && data.containsKey('total')) {
            _hasMoreArchived = _archived.length < data['total'];
          } else {
            _hasMoreArchived = newItems.isNotEmpty;
          }
        });
      }
    } catch (_) { _pageArchived--; }
    setState(() => _loadingMoreArchived = false);
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.isEmpty || _bodyCtrl.text.isEmpty) return;
    setState(() => _submitting = true);
    await _api.postData('announcements', {'title': _titleCtrl.text, 'body': _bodyCtrl.text, 'category': _category, 'posted_by': 'System Administrator'});
    _titleCtrl.clear(); _bodyCtrl.clear();
    setState(() => _category = 'General');
    await _fetchActive(refresh: true);
    if (mounted) setState(() { _submitting = false; _msg = 'Announcement broadcasted!'; _tab = 'history'; });
    Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _msg = ''); });
  }

  Future<void> _delete(int id) async {
    // Optimistic UI Update
    final index = _active.indexWhere((a) => a['id'] == id);
    if (index != -1) {
      final item = _active.removeAt(index);
      setState(() => _archived.insert(0, item));
    }

    try {
      await _api.deleteData('announcements/$id');
      setState(() => _msg = 'Archived successfully.');
      Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _msg = ''); });
    } catch (_) {
      // Revert on error (could be improved to fully revert)
      _fetchActive(refresh: true);
      _fetchArchived(refresh: true);
    }
  }

  Future<void> _restore(int id) async {
    // Optimistic UI Update
    final index = _archived.indexWhere((a) => a['id'] == id);
    if (index != -1) {
      final item = _archived.removeAt(index);
      setState(() => _active.insert(0, item));
    }

    try {
      await _api.patchData('announcements/$id/restore', {});
      setState(() => _msg = 'Restored.');
      Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _msg = ''); });
    } catch (_) {
      _fetchActive(refresh: true);
      _fetchArchived(refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      {'id': 'create',   'label': 'New Broadcast'},
      {'id': 'history',  'label': 'History'},
      {'id': 'archived', 'label': 'Archived'},
    ];
    return AppLayout(
      title: 'Announcements',
      scrollable: false,
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Tab bar
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
            child: Row(children: tabs.map((t) {
              final active = _tab == t['id'];
              return Expanded(child: GestureDetector(
                onTap: () {
                  setState(() => _tab = t['id']!);
                  if (t['id'] == 'history' && _active.isEmpty) _fetchActive(refresh: true);
                  if (t['id'] == 'archived' && _archived.isEmpty) _fetchArchived(refresh: true);
                },
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

          // Toast
          if (_msg.isNotEmpty) Container(
            padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: _kGreen.withAlpha(25), borderRadius: BorderRadius.circular(12), border: Border.all(color: _kGreen.withAlpha(50))),
            child: Text(_msg, style: const TextStyle(color: _kGreen, fontWeight: FontWeight.w700, fontSize: 13)),
          ),

          if (_tab == 'create') _buildCreate(),
          if (_tab == 'history') _buildList(_active, archived: false, loading: _loadingActive, loadingMore: _loadingMoreActive),
          if (_tab == 'archived') _buildList(_archived, archived: true, loading: _loadingArchived, loadingMore: _loadingMoreArchived),
        ]),
      )
    );
  }

  Widget _buildCreate() => Container(
    constraints: const BoxConstraints(maxWidth: 600),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Compose Message', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 16),
      const Text('Alert Type', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
      const SizedBox(height: 6),
      CustomDropdown<String>(
        value: _category,
        items: const [
          DropdownItem(value: 'General',             label: 'General'),
          DropdownItem(value: 'Urgent Alert',        label: 'Urgent Alert'),
          DropdownItem(value: 'System Maintenance',  label: 'System Maintenance'),
          DropdownItem(value: 'Event',               label: 'Event'),
        ],
        onChanged: (v) => setState(() => _category = v),
      ),
      const SizedBox(height: 14),
      const Text('Subject', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
      const SizedBox(height: 6),
      TextField(
        controller: _titleCtrl,
        decoration: InputDecoration(
          hintText: 'Enter title...',
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kOrange, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      const SizedBox(height: 14),
      const Text('Content', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
      const SizedBox(height: 6),
      TextField(
        controller: _bodyCtrl,
        maxLines: 4,
        decoration: InputDecoration(
          hintText: 'Broadcast details...',
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kOrange, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(
        onPressed: _submitting ? null : _submit,
        icon: _submitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send),
        label: const Text('Broadcast Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        style: ElevatedButton.styleFrom(backgroundColor: _kOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
      )),
    ]),
  );

  Widget _buildList(List items, {required bool archived, required bool loading, required bool loadingMore}) {
    if (loading) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        separatorBuilder: (ctx, i) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) => const ShimmerListTile(),
      );
    }
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
        child: Center(child: Text(archived ? 'No archived announcements.' : 'No active announcements.', style: const TextStyle(color: Colors.grey))),
      );
    }
    return Column(children: [
      ...items.map((ann) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 6)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: (ann['category'] == 'Urgent Alert' ? _kRed : Colors.blue).withAlpha(25), borderRadius: BorderRadius.circular(20)), child: Text(ann['category'] ?? '', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: ann['category'] == 'Urgent Alert' ? _kRed : Colors.blue))),
            const Spacer(),
            if (!archived) IconButton(icon: const Icon(Icons.archive_outlined, color: _kRed, size: 18), onPressed: () => _delete(ann['id'])),
            if (archived) TextButton.icon(icon: const Icon(Icons.restore, size: 16, color: _kGreen), label: const Text('Restore', style: TextStyle(color: _kGreen, fontSize: 12)), onPressed: () => _restore(ann['id'])),
          ]),
          const SizedBox(height: 6),
          Text(ann['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 4),
          Text(ann['body'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 8),
          Text('Posted by: ${ann['posted_by'] ?? ''}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
      )),
      if (loadingMore) const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
    ]);
  }
}

