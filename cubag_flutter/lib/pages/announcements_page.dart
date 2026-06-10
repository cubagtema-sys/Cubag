import 'package:flutter/material.dart';
import '../components/app_layout.dart';
import '../components/custom_dropdown.dart';
import '../services/api_service.dart';
import '../components/shimmer_loader.dart';

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});
  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  bool _loading = true;
  bool _loadingMore = false;
  int _page = 1;
  int _total = 0;
  bool _hasMore = true;
  List<dynamic> _alerts = [];
  final Set<dynamic> _expanded = {};
  String _filter = 'All';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetch();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_loading && !_loadingMore && _hasMore) {
        _fetchMore();
      }
    }
  }

  Future<void> _fetch({bool refresh = false}) async {
    if (refresh) {
      setState(() { _page = 1; _hasMore = true; _loading = true; _alerts = []; });
    } else {
      if (!_loading) setState(() => _loading = true);
    }
    await ApiService().fetchDataWithCache('/announcements?page=$_page&limit=20', (data, isCached, {bool hasError = false}) {
      if (mounted && data != null) {
        setState(() {
          _loading = false;
          _alerts = ApiService.ensureList(data);
          if (data is Map && data.containsKey('total')) {
            _total = data['total'];
            _hasMore = _alerts.length < _total;
          } else {
            _hasMore = false;
          }
        });
      }
    });
  }

  Future<void> _fetchMore() async {
    setState(() => _loadingMore = true);
    _page++;
    try {
      final data = await ApiService().fetchData('/announcements?page=$_page&limit=20');
      if (mounted) {
        final newItems = ApiService.ensureList(data);
        setState(() {
          _alerts.addAll(newItems);
          if (data is Map && data.containsKey('total')) {
            _hasMore = _alerts.length < data['total'];
          } else {
            _hasMore = newItems.isNotEmpty;
          }
        });
      }
    } catch (_) { _page--; }
    if (mounted) setState(() => _loadingMore = false);
  }

  Future<void> _markAllRead() async {
    try {
      await ApiService().post('/announcements/mark-read', data: {});
      setState(() => _alerts = _alerts.map((a) => {...a, 'is_read': true}).toList());
    } catch (_) {}
  }

  Future<void> _toggleExpand(dynamic id, bool isRead) async {
    if (!isRead) {
      try {
        await ApiService().post('/announcements/mark-read', data: {'announcement_id': id});
        setState(() => _alerts = _alerts.map((a) => a['id'] == id ? {...a, 'is_read': true} : a).toList());
      } catch (_) {}
    }
    setState(() => _expanded.contains(id) ? _expanded.remove(id) : _expanded.add(id));
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final categories = ['All', ..._alerts.map((a) => a['category'] ?? a['type'] ?? 'GENERAL').toSet().cast<String>()];
    final filtered = _filter == 'All' ? _alerts : _alerts.where((a) => (a['category'] ?? a['type']) == _filter).toList();
    final unread = _alerts.where((a) => a['is_read'] != true).length;

    return AppLayout(
      title: 'Announcements',
      scrollable: false,
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CustomDropdown<String>(
          value: _filter,
          items: categories.map((c) => DropdownItem<String>(value: c, label: c == 'All' ? 'All Updates' : c)).toList(),
          onChanged: (v) => setState(() => _filter = v),
          prefixIcon: Icon(Icons.filter_alt, color: primary),
        ),
        const SizedBox(height: 16),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                const Text('LATEST CIRCULARS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const Spacer(),
                if (unread > 0) TextButton.icon(onPressed: _markAllRead, icon: const Icon(Icons.done_all, size: 16), label: const Text('Mark All Read', style: TextStyle(fontSize: 11)), style: TextButton.styleFrom(foregroundColor: primary)),
              ]),
            ),
            const Divider(height: 1),
            if (_loading)
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 8,
                separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) => const ShimmerListTile(),
              )
            else if (filtered.isEmpty)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('No circulars found.', style: TextStyle(color: Colors.grey))))
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final a = filtered[i];
                  final isRead = a['is_read'] == true;
                  final isExpanded = _expanded.contains(a['id']);
                  return InkWell(
                    onTap: () => _toggleExpand(a['id'], isRead),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isRead ? Colors.transparent : primary.withValues(alpha: 0.03),
                        border: isRead ? null : Border(left: BorderSide(color: primary, width: 3)),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(width: 36, height: 36, decoration: BoxDecoration(color: primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.campaign, color: primary, size: 18)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(a['title'] ?? '', style: TextStyle(fontWeight: isRead ? FontWeight.w600 : FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(a['body'] ?? a['content'] ?? '', maxLines: isExpanded ? null : 2, overflow: isExpanded ? null : TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)),
                            child: Text((a['category'] ?? a['type'] ?? 'GENERAL').toString().toUpperCase(), style: TextStyle(fontSize: 10, color: primary, fontWeight: FontWeight.bold)),
                          ),
                        ])),
                      ]),
                    ),
                  );
                },
              ),
            if (_loadingMore) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
          ]),
        ),
      ]),
      ),
    );
  }
}
