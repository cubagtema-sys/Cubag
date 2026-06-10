import 'package:flutter/material.dart';
import '../components/app_layout.dart';
import '../components/custom_dropdown.dart';
import '../components/trend_line.dart';
import '../services/api_service.dart';
import '../components/fetch_error_view.dart';
import '../components/shimmer_loader.dart';

class StandingTier {
  final String label;
  final Color color;
  final IconData icon;
  final String badgeText;

  StandingTier({
    required this.label,
    required this.color,
    required this.icon,
    required this.badgeText,
  });

  static StandingTier getFromStars(double stars) {
    if (stars >= 4.5) {
      return StandingTier(
        label: 'Elite Standing',
        color: const Color(0xFFD4AF37), // Gold
        icon: Icons.workspace_premium,
        badgeText: 'ELITE MEMBER',
      );
    } else if (stars >= 3.5) {
      return StandingTier(
        label: 'Good Standing',
        color: const Color(0xFF10B981), // Emerald Green
        icon: Icons.verified_user,
        badgeText: 'ACTIVE MEMBER',
      );
    } else if (stars >= 2.0) {
      return StandingTier(
        label: 'Warning / Probationary',
        color: const Color(0xFFF59E0B), // Amber
        icon: Icons.warning_amber,
        badgeText: 'PROBATIONARY',
      );
    } else {
      return StandingTier(
        label: 'Suspended / Delinquent',
        color: const Color(0xFFEF4444), // Red
        icon: Icons.block,
        badgeText: 'SUSPENDED',
      );
    }
  }
}

class AdminMembersPage extends StatefulWidget {
  const AdminMembersPage({super.key});
  @override
  State<AdminMembersPage> createState() => _AdminMembersPageState();
}

class _AdminMembersPageState extends State<AdminMembersPage> {
  bool _loading = true;
  bool _hasError = false;
  bool _loadingMore = false;
  int _page = 1;
  int _total = 0;
  bool _hasMore = true;
  List<dynamic> _members = [];
  String _search = '';
  String _filterStatus = 'all';
  String _sortBy = 'name';
  Map<String, dynamic>? _selected;
  double _editReviewScore = 10.0;
  bool _updating = false;
  final ScrollController _scrollController = ScrollController();

  final _statusStyle = {
    'active':    {'bg': const Color(0x1910b981), 'color': const Color(0xFF10b981), 'label': 'Active'},
    'pending':   {'bg': const Color(0x19f59e0b), 'color': const Color(0xFFf59e0b), 'label': 'Pending'},
    'inactive':  {'bg': const Color(0x1964748b), 'color': const Color(0xFF64748b), 'label': 'Inactive'},
    'suspended': {'bg': const Color(0x19ef4444), 'color': const Color(0xFFef4444), 'label': 'Suspended'},
  };

  final _typeColors = {
    'Corporate Agency':  const Color(0xFF3b82f6),
    'Individual Broker': const Color(0xFFf08232),
    'Freight Forwarder': const Color(0xFF10b981),
    'Shipping Line':     const Color(0xFF8b5cf6),
  };

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
      setState(() { _page = 1; _hasMore = true; _loading = true; _members = []; });
    } else {
      if (!_loading) setState(() => _loading = true);
    }
    
    await ApiService().fetchDataWithCache('/members/admin/all?page=$_page&limit=20', (data, isCached, {bool hasError = false}) {
      if (!mounted) return;

      if (hasError) {
        if (_members.isEmpty) {
          setState(() { _loading = false; _hasError = true; });
        } else {
          // If we already have cached data, don't show full error view,
          // but we should still exit loading state.
          setState(() { _loading = false; });
        }
        return;
      }

      if (data == null) {
        setState(() => _loading = false);
        return;
      }

      setState(() {
        _loading = false;
        _hasError = false;
        final List<dynamic> newMembers = ApiService.ensureList(data);

        // If it's fresh data (not cached), replace. If cached, just set.
        // Actually fetchDataWithCache calls once for cache and once for fresh.
        _members = newMembers;

        if (data is Map && data.containsKey('total')) {
          _total = int.tryParse(data['total']?.toString() ?? '0') ?? 0;
          _hasMore = _members.length < _total;
        } else {
          _hasMore = false;
        }
      });
    });
  }

  Future<void> _fetchMore() async {
    setState(() => _loadingMore = true);
    _page++;
    try {
      final res = await ApiService().get('/members/admin/all?page=$_page&limit=20');
      if (res.statusCode == 200) {
        final data = res.data;
        final newItems = ApiService.ensureList(data);
        setState(() {
          _members.addAll(newItems);
          if (data is Map && data.containsKey('total')) {
            _hasMore = _members.length < data['total'];
          } else {
            _hasMore = newItems.isEmpty ? false : true;
          }
        });
      }
    } catch (_) {
      _page--;
    }
    setState(() => _loadingMore = false);
  }

  Future<void> _selectMember(Map<String, dynamic> m) async {
    setState(() {
      _selected = Map<String, dynamic>.from(m);
      _editReviewScore = double.tryParse((m['manual_review_score'] ?? 10).toString()) ?? 10.0;
    });
    try {
      final res = await ApiService().get('/members/${m['id']}');
      if (res.statusCode == 200 && _selected?['id'] == m['id']) {
        setState(() {
          _selected = Map<String, dynamic>.from(res.data);
        });
      }
    } catch (_) {}
  }

  Future<void> _updateStatus(dynamic id, String status) async {
    setState(() => _updating = true);
    try {
      final res = await ApiService().put('/members/admin/status/$id', data: {'status': status});
      final d = res.data ?? {};
      setState(() {
        _members = _members.map((m) => m['id'] == id ? {
          ...m, 
          'status': status, 
          'license_number': d['license_number'] ?? m['license_number'],
          'compliance_score': d['compliance_score'] ?? m['compliance_score'],
          'star_rating': d['star_rating'] ?? m['star_rating']
        } : m).toList();
        if (_selected?['id'] == id) {
          _selected = {
            ..._selected!, 
            'status': status,
            'compliance_score': d['compliance_score'] ?? _selected!['compliance_score'],
            'star_rating': d['star_rating'] ?? _selected!['star_rating']
          };
        }
      });
    } catch (_) {}
    setState(() => _updating = false);
  }

  Future<void> _updateReviewScore(dynamic id) async {
    setState(() => _updating = true);
    try {
      final res = await ApiService().put('/members/admin/set-review-score/$id', data: {
        'manual_review_score': _editReviewScore.round(),
      });
      if (res.statusCode == 200) {
        final d = res.data ?? {};
        if (mounted) {
          setState(() {
            _members = _members.map((m) => m['id'] == id ? {
              ...m,
              'manual_review_score': _editReviewScore.round(),
              'compliance_score': d['compliance_score'] ?? m['compliance_score'],
              'star_rating': d['star_rating'] ?? m['star_rating'],
            } : m).toList();
            if (_selected?['id'] == id) {
              _selected = {
                ..._selected!,
                'manual_review_score': _editReviewScore.round(),
                'compliance_score': d['compliance_score'] ?? _selected!['compliance_score'],
                'star_rating': d['star_rating'] ?? _selected!['star_rating'],
              };
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Manual review score saved successfully')),
          );
        }
      }
    } catch (_) {}
    setState(() => _updating = false);
  }

  String _initials(String n) => n.trim().isEmpty ? '?' : n.split(' ').where((s) => s.isNotEmpty).map((s) => s[0]).take(2).join().toUpperCase();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final total   = _members.length;
    final active  = _members.where((m) => m['status']?.toString().toLowerCase() == 'active').length;
    final pending = _members.where((m) => m['status']?.toString().toLowerCase() == 'pending').length;
    
    final filtered = _members.where((m) {
      final q = _search.toLowerCase();
      final status = m['status']?.toString().toLowerCase() ?? '';
      if (_filterStatus != 'all' && status != _filterStatus) return false;
      return ((m['name'] ?? '').toString().toLowerCase().contains(q) ||
              (m['email'] ?? '').toString().toLowerCase().contains(q));
    }).toList();

    // Sort logic
    if (_sortBy == 'name') {
      filtered.sort((a, b) => (a['name']?.toString() ?? '').toLowerCase().compareTo((b['name']?.toString() ?? '').toLowerCase()));
    } else if (_sortBy == 'score_desc') {
      filtered.sort((a, b) {
        final scoreA = int.tryParse(a['compliance_score']?.toString() ?? '') ?? 100;
        final scoreB = int.tryParse(b['compliance_score']?.toString() ?? '') ?? 100;
        return scoreB.compareTo(scoreA);
      });
    } else if (_sortBy == 'score_asc') {
      filtered.sort((a, b) {
        final scoreA = int.tryParse(a['compliance_score']?.toString() ?? '') ?? 100;
        final scoreB = int.tryParse(b['compliance_score']?.toString() ?? '') ?? 100;
        return scoreA.compareTo(scoreB);
      });
    }

    return AppLayout(
      title: 'Association Members',
      scrollable: false,
      child: Stack(children: [
        SingleChildScrollView(
          controller: _scrollController,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: _kpiCard(Icons.group, const Color(0xFF3b82f6), 'Total', '$total')),
            const SizedBox(width: 8),
            Expanded(child: _kpiCard(Icons.verified_user, const Color(0xFF10b981), 'Active', '$active')),
            const SizedBox(width: 8),
            Expanded(child: _kpiCard(Icons.pending_actions, const Color(0xFFf59e0b), 'Pending', '$pending')),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              flex: 4,
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 18),
                  hintText: 'Search by name, email...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748b)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primary, width: 2)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: CustomDropdown<String>(
                value: _filterStatus,
                prefixIcon: const Icon(Icons.filter_alt_outlined, size: 16, color: Color(0xFF64748b)),
                items: [
                  DropdownItem(value: 'all',       label: 'All ($total)'),
                  DropdownItem(value: 'active',    label: 'Active ($active)'),
                  DropdownItem(value: 'pending',   label: 'Pending ($pending)'),
                  const DropdownItem(value: 'inactive',  label: 'Inactive'),
                  const DropdownItem(value: 'suspended', label: 'Suspended'),
                ],
                onChanged: (v) => setState(() => _filterStatus = v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: CustomDropdown<String>(
                value: _sortBy,
                prefixIcon: const Icon(Icons.sort, size: 16, color: Color(0xFF64748b)),
                items: const [
                  DropdownItem(value: 'name', label: 'Name (A-Z)'),
                  DropdownItem(value: 'score_desc', label: 'High Score'),
                  DropdownItem(value: 'score_asc', label: 'At Risk'),
                ],
                onChanged: (v) => setState(() => _sortBy = v),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          if (_loading)
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 800) {
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 12,
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 400,
                      childAspectRatio: 1.8,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemBuilder: (ctx, i) => const ShimmerGridCard(),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 8,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) => const ShimmerListTile(),
                );
              }
            )
          else if (_hasError && _members.isEmpty)
            FetchErrorView(onRetry: () => _fetch(refresh: true))
          else if (filtered.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No members found.', style: TextStyle(color: Colors.grey))))
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 800) {
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 400,
                      childAspectRatio: 1.8,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemBuilder: (ctx, i) => _buildMemberCard(filtered[i], primary, ctx),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    return _buildMemberCard(filtered[i], primary, ctx);
                  },
                );
              }
            ),
          const SizedBox(height: 12),
          if (_loadingMore) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
          if (!_loading) Center(child: Text('${filtered.length} members shown${_total > 0 ? " of $_total" : ""}', style: const TextStyle(fontSize: 12, color: Colors.grey))),
        ])),

        if (_selected != null)
          Positioned.fill(child: GestureDetector(
            onTap: () => setState(() => _selected = null),
            child: Container(color: Colors.black54, alignment: Alignment.bottomCenter, child: GestureDetector(
              onTap: () {},
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
                decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 12), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                  Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: _buildSheet(primary))),
                ]),
              ),
            )),
          )),
      ]),
    );
  }

  Widget _buildSheet(Color primary) {
    final m  = _selected!;
    final c  = _typeColors[m['member_type']] ?? primary;
    final ss = _statusStyle[m['status']] ?? _statusStyle['inactive']!;
    
    final starRating = double.tryParse(m['star_rating']?.toString() ?? '') ?? 5.0;
    final complianceScore = int.tryParse(m['compliance_score']?.toString() ?? '') ?? 100;
    final tier = StandingTier.getFromStars(starRating);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        CircleAvatar(radius: 26, backgroundColor: c.withValues(alpha: 0.1), child: Text(_initials(m['name']?.toString() ?? ''), style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 16))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(m['email']?.toString() ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ])),
      ]),
      const SizedBox(height: 16),
      
      // Standing and compliance scorecard
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('STANDING & COMPLIANCE', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.star, color: Color(0xFFFFD700), size: 20),
                  const SizedBox(width: 4),
                  Text(
                    '${starRating.toStringAsFixed(1)} / 5.0',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: tier.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tier.label,
                  style: TextStyle(
                    color: tier.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: complianceScore / 100.0,
              backgroundColor: Colors.grey.shade200,
              color: tier.color,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Compliance Score: $complianceScore%',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Manual Review Score: ${_editReviewScore.round()} / 10',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              ElevatedButton(
                onPressed: _updating ? null : () => _updateReviewScore(m['id']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Save Score', style: TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ],
          ),
          Slider(
            value: _editReviewScore,
            min: 0.0,
            max: 10.0,
            divisions: 10,
            activeColor: primary,
            inactiveColor: primary.withValues(alpha: 0.2),
            onChanged: (val) {
              setState(() {
                _editReviewScore = val;
              });
            },
          ),
        ]),
      ),
      
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('HISTORICAL COMPLIANCE TREND', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 14),
          TrendLineWidget(
            points: (m['rating_history'] as List?)
                    ?.map((h) => double.tryParse(h['compliance_score']?.toString() ?? '') ?? 100.0)
                    .toList() ??
                [complianceScore.toDouble()],
            color: tier.color,
            height: 100,
          ),
        ]),
      ),

      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(14)),
        child: _buildMathBreakdownSection(m, primary),
      ),
      
      ...([
        ['Organisation', m['company']], ['Type', m['member_type']], ['Port', m['port_of_operation']],
        ['License', m['license_number'] ?? 'N/A'], ['Payment Ref', m['payment_ref'] ?? 'None'],
      ].where((r) => r[1] != null)).map((r) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r[0].toString().toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          Text(r[1].toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
      )),
      const SizedBox(height: 14),
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: ss['bg'] as Color, borderRadius: BorderRadius.circular(20)), child: Text((ss['label'] as String).toUpperCase(), style: TextStyle(fontSize: 10, color: ss['color'] as Color, fontWeight: FontWeight.bold))),
          const SizedBox(width: 8),
          const Text('Update status:', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          if (m['status'] != 'active') Expanded(child: ElevatedButton(onPressed: _updating ? null : () => _updateStatus(m['id'], 'active'), style: ElevatedButton.styleFrom(backgroundColor: primary, minimumSize: const Size(0, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), child: const Text('Activate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
          if (m['status'] != 'suspended') ...[const SizedBox(width: 6), Expanded(child: ElevatedButton(onPressed: _updating ? null : () => _updateStatus(m['id'], 'suspended'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, minimumSize: const Size(0, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), child: const Text('Suspend', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))],
          if (m['status'] != 'inactive') ...[const SizedBox(width: 6), Expanded(child: OutlinedButton(onPressed: _updating ? null : () => _updateStatus(m['id'], 'inactive'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Disable', style: TextStyle(fontWeight: FontWeight.bold))))],
        ]),
      ])),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, child: TextButton(onPressed: () => setState(() => _selected = null), child: const Text('Close Profile', style: TextStyle(color: Colors.grey)))),
    ]);
  }

  Widget _kpiCard(IconData icon, Color color, String label, String value) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      Container(width: 30, height: 30, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 15)),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
      ])),
    ]),
  );

  Widget _buildMemberCard(dynamic m, Color primary, BuildContext ctx) {
    final ss = _statusStyle[m['status']] ?? _statusStyle['inactive']!;
    final c  = _typeColors[m['member_type']] ?? primary;
    final starRating = double.tryParse(m['star_rating']?.toString() ?? '') ?? 5.0;
    final score = int.tryParse(m['compliance_score']?.toString() ?? '') ?? 100;
    final tier = StandingTier.getFromStars(starRating);

    return InkWell(
      onTap: () => _selectMember(m),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Theme.of(ctx).cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(ctx).dividerColor)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Row(children: [
              CircleAvatar(radius: 18, backgroundColor: c.withValues(alpha: 0.1), child: Text(_initials(m['name']?.toString() ?? ''), style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12))),
              const Spacer(),
              Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: ss['bg'] as Color, borderRadius: BorderRadius.circular(20)), child: Text((ss['label'] as String).toUpperCase(), style: TextStyle(fontSize: 8, color: ss['color'] as Color, fontWeight: FontWeight.bold))),
            ]),
            const SizedBox(height: 8),
            Text(m['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
            Text(m['email']?.toString() ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.star, color: Color(0xFFFFD700), size: 14),
                const SizedBox(width: 4),
                Text(
                  starRating.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 6),
                Text(
                  '($score%)',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tier.label,
                    style: TextStyle(fontSize: 10, color: tier.color, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => _selectMember(m), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 4), minimumSize: const Size(0, 36), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Details', style: TextStyle(fontSize: 11)))),
              if (m['status'] == 'pending') ...[const SizedBox(width: 6), Expanded(child: ElevatedButton(onPressed: _updating ? null : () => _updateStatus(m['id'], 'active'), style: ElevatedButton.styleFrom(backgroundColor: primary, padding: const EdgeInsets.symmetric(vertical: 4), minimumSize: const Size(0, 36), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), child: const Text('Approve', style: TextStyle(color: Colors.white, fontSize: 11))))],
              if (m['status'] == 'active') ...[const SizedBox(width: 6), Expanded(child: ElevatedButton(onPressed: _updating ? null : () => _updateStatus(m['id'], 'suspended'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 4), minimumSize: const Size(0, 36), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), child: const Text('Suspend', style: TextStyle(color: Colors.white, fontSize: 11))))],
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildMathBreakdownSection(Map<String, dynamic> m, Color primary) {
    final bd = m['breakdown'] as Map<String, dynamic>?;
    if (bd == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: Text('Loading compliance breakdown details...', style: TextStyle(color: Colors.grey, fontSize: 12))),
      );
    }

    final paymentScore = bd['payment_score'] ?? 0;
    final paymentPunctual = bd['payment_punctual_score'] ?? 0;
    final paymentHistory = bd['payment_history_score'] ?? 0;
    final overdueCount = bd['overdue_payments_count'] ?? 0;
    final totalPaid = bd['total_payments_paid'] ?? 0;
    final onTimePaid = bd['on_time_payments_paid'] ?? 0;

    final taskScore = bd['task_score'] ?? 0;
    final licenseScore = bd['license_score'] ?? 0;
    final taskCompletionScore = bd['task_completion_score'] ?? 0;
    final totalTasks = bd['total_tasks'] ?? 0;
    final completedTasks = bd['completed_tasks'] ?? 0;

    final engagementScore = bd['engagement_score'] ?? 0;
    final surveyScore = bd['survey_score'] ?? 0;
    final totalSurveys = bd['total_surveys'] ?? 0;
    final respondedSurveys = bd['responded_surveys'] ?? 0;
    final agmScore = bd['agm_score'] ?? 0;

    final adminScore = bd['admin_score'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'COMPLIANCE BREAKDOWN MATH',
          style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        const SizedBox(height: 12),
        
        _breakdownTile(
          icon: Icons.payments_outlined,
          color: const Color(0xFF10B981),
          title: 'Payment Compliance',
          scoreText: '$paymentScore / 40 pts',
          details: [
            '• Punctual payment (no outstanding overdue): $paymentPunctual / 25 pts',
            '• On-time payment history ratio ($onTimePaid / $totalPaid paid on time): $paymentHistory / 15 pts',
            if (overdueCount > 0) '• WARNING: $overdueCount overdue payments detected.'
          ],
        ),
        
        _breakdownTile(
          icon: Icons.task_alt_outlined,
          color: const Color(0xFF3B82F6),
          title: 'Task & Document Compliance',
          scoreText: '$taskScore / 30 pts',
          details: [
            '• License renewal status: $licenseScore / 15 pts',
            '• Required tasks compliance ($completedTasks / $totalTasks completed): $taskCompletionScore / 15 pts',
          ],
        ),

        _breakdownTile(
          icon: Icons.campaign_outlined,
          color: const Color(0xFF8B5CF6),
          title: 'Engagement & Activities',
          scoreText: '$engagementScore / 20 pts',
          details: [
            '• Survey response rate ($respondedSurveys / $totalSurveys completed): $surveyScore / 10 pts',
            '• Annual General Meeting (AGM) attendance: $agmScore / 10 pts',
          ],
        ),

        _breakdownTile(
          icon: Icons.rate_review_outlined,
          color: const Color(0xFFF59E0B),
          title: 'Admin Manual Review',
          scoreText: '$adminScore / 10 pts',
          details: [
            '• Direct administrative compliance modifier: $adminScore / 10 pts',
          ],
        ),
      ],
    );
  }

  Widget _breakdownTile({
    required IconData icon,
    required Color color,
    required String title,
    required String scoreText,
    required List<String> details,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              Text(
                scoreText,
                style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...details.map((detail) => Padding(
            padding: const EdgeInsets.only(top: 2, left: 24),
            child: Text(
              detail,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          )),
        ],
      ),
    );
  }
}
