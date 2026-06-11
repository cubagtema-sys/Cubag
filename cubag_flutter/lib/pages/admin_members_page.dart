import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1e293b) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0);
    final textColor = isDark ? const Color(0xFFcbd5e1) : const Color(0xFF0f172a);
    final subTextColor = isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b);

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
            Expanded(child: _KPICard(icon: Icons.group, color: const Color(0xFF3b82f6), label: 'Total', value: '$total', cardBg: cardBg, borderColor: borderColor)),
            const SizedBox(width: 8),
            Expanded(child: _KPICard(icon: Icons.verified_user, color: const Color(0xFF10b981), label: 'Active', value: '$active', cardBg: cardBg, borderColor: borderColor)),
            const SizedBox(width: 8),
            Expanded(child: _KPICard(icon: Icons.pending_actions, color: const Color(0xFFf59e0b), label: 'Pending', value: '$pending', cardBg: cardBg, borderColor: borderColor)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              flex: 4,
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                style: GoogleFonts.outfit(fontSize: 13, color: textColor),
                decoration: InputDecoration(
                  fillColor: cardBg,
                  filled: true,
                  prefixIcon: Icon(Icons.search, color: subTextColor, size: 18),
                  hintText: 'Search by name, email...',
                  hintStyle: GoogleFonts.outfit(fontSize: 13, color: subTextColor),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), 
                    borderSide: BorderSide(color: borderColor, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), 
                    borderSide: BorderSide(color: primary, width: 2),
                  ),
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
                    itemBuilder: (ctx, i) => _buildMemberCard(filtered[i], primary, ctx, isDark, cardBg, borderColor, textColor, subTextColor),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    return _buildMemberCard(filtered[i], primary, ctx, isDark, cardBg, borderColor, textColor, subTextColor);
                  },
                );
              }
            ),
          const SizedBox(height: 12),
          if (_loadingMore) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
          if (!_loading) Center(child: Text('${filtered.length} members shown${_total > 0 ? " of $_total" : ""}', style: const TextStyle(fontSize: 12, color: Colors.grey))),
        ])),

        if (_selected != null)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
              child: GestureDetector(
                onTap: () => setState(() => _selected = null),
                child: Container(
                  color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.4),
                  alignment: Alignment.center,
                  child: GestureDetector(
                    onTap: () {},
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      margin: const EdgeInsets.all(24),
                      constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 24, right: 16, top: 20, bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Member Profile',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.close, color: subTextColor, size: 20),
                                  onPressed: () => setState(() => _selected = null),
                                  splashRadius: 20,
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: _buildSheet(primary, isDark, cardBg, borderColor, textColor, subTextColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _buildSheet(Color primary, bool isDark, Color cardBg, Color borderColor, Color textColor, Color subTextColor) {
    final m  = _selected!;
    final c  = _typeColors[m['member_type']] ?? primary;
    final ss = _statusStyle[m['status']] ?? _statusStyle['inactive']!;
    
    final starRating = double.tryParse(m['star_rating']?.toString() ?? '') ?? 5.0;
    final complianceScore = int.tryParse(m['compliance_score']?.toString() ?? '') ?? 100;
    final tier = StandingTier.getFromStars(starRating);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [c, c.withValues(alpha: 0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: c.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            _initials(m['name']?.toString() ?? ''),
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            m['name']?.toString() ?? '', 
            style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18, color: textColor),
          ),
          const SizedBox(height: 2),
          Text(
            m['email']?.toString() ?? '', 
            style: GoogleFonts.outfit(color: subTextColor, fontSize: 12),
          ),
        ])),
      ]),
      const SizedBox(height: 20),
      
      // Standing and compliance scorecard
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0f172a) : Colors.grey.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'STANDING & COMPLIANCE', 
            style: GoogleFonts.outfit(fontSize: 10, color: subTextColor, fontWeight: FontWeight.w800, letterSpacing: 1),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.star, color: Color(0xFFFFD700), size: 22),
                  const SizedBox(width: 6),
                  Text(
                    '${starRating.toStringAsFixed(1)} / 5.0',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: textColor),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: tier.color.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: tier.color.withValues(alpha: 0.3), width: 1),
                ),
                child: Text(
                  tier.label,
                  style: GoogleFonts.outfit(
                    color: tier.color,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: complianceScore / 100.0,
              backgroundColor: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
              color: tier.color,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Compliance Score: $complianceScore%',
            style: GoogleFonts.outfit(fontSize: 12, color: subTextColor, fontWeight: FontWeight.w600),
          ),
          Divider(height: 32, color: borderColor),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Manual Review Score: ${_editReviewScore.round()} / 10',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13, color: textColor),
              ),
              ElevatedButton(
                onPressed: _updating ? null : () => _updateReviewScore(m['id']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text('Save Score', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 4),
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
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0f172a) : Colors.grey.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'HISTORICAL COMPLIANCE TREND', 
            style: GoogleFonts.outfit(fontSize: 10, color: subTextColor, fontWeight: FontWeight.w800, letterSpacing: 1),
          ),
          const SizedBox(height: 16),
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
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0f172a) : Colors.grey.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: _buildMathBreakdownSection(m, primary, isDark, textColor, subTextColor),
      ),
      
      ...([
        ['Organisation', m['company']], ['Type', m['member_type']], ['Port', m['port_of_operation']],
        ['License', (m['license_number']?.toString().trim().isEmpty ?? true) ? 'N/A' : m['license_number']], 
        ['Payment Ref', (m['payment_ref']?.toString().trim().isEmpty ?? true) ? 'None' : m['payment_ref']],
      ].where((r) => r[1] != null)).map((r) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              r[0].toString().toUpperCase(), 
              style: GoogleFonts.outfit(fontSize: 10, color: subTextColor, fontWeight: FontWeight.w800, letterSpacing: 0.5),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                r[1].toString(), 
                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: textColor),
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      )),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(16), 
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0f172a) : Colors.grey.withValues(alpha: 0.03), 
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ), 
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), 
              decoration: BoxDecoration(
                color: (ss['bg'] as Color).withValues(alpha: isDark ? 0.25 : 0.12), 
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: (ss['color'] as Color).withValues(alpha: 0.3)),
              ), 
              child: Text(
                (ss['label'] as String).toUpperCase(), 
                style: GoogleFonts.outfit(fontSize: 10, color: ss['color'] as Color, fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
            ),
            const SizedBox(width: 8),
            Text('Status Controls', style: GoogleFonts.outfit(fontSize: 12, color: subTextColor, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            if (m['status'] != 'active') 
              Expanded(
                child: ElevatedButton(
                  onPressed: _updating ? null : () => _updateStatus(m['id'], 'active'), 
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary, 
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48), 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), 
                    elevation: 0,
                  ), 
                  child: Text('Activate', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            if (m['status'] != 'suspended') ...[
              const SizedBox(width: 8), 
              Expanded(
                child: ElevatedButton(
                  onPressed: _updating ? null : () => _updateStatus(m['id'], 'suspended'), 
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, 
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48), 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), 
                    elevation: 0,
                  ), 
                  child: Text('Suspend', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
            if (m['status'] != 'inactive') ...[
              const SizedBox(width: 8), 
              Expanded(
                child: OutlinedButton(
                  onPressed: _updating ? null : () => _updateStatus(m['id'], 'inactive'), 
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48), 
                    side: BorderSide(color: borderColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ), 
                  child: Text(
                    'Disable', 
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                  ),
                ),
              ),
            ],
          ]),
        ]),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity, 
        child: TextButton(
          onPressed: () => setState(() => _selected = null), 
          child: Text('Close Profile', style: GoogleFonts.outfit(color: subTextColor, fontWeight: FontWeight.w600)),
        ),
      ),
    ]);
  }

  Widget _buildMemberCard(dynamic m, Color primary, BuildContext ctx, bool isDark, Color cardBg, Color borderColor, Color textColor, Color subTextColor) {
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
        decoration: BoxDecoration(
          color: cardBg, 
          borderRadius: BorderRadius.circular(12), 
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [c, c.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: c.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials(m['name']?.toString() ?? ''),
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (ss['bg'] as Color).withValues(alpha: isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (ss['color'] as Color).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  (ss['label'] as String).toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 8,
                    color: ss['color'] as Color,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              m['name']?.toString() ?? '', 
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: textColor), 
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              m['email']?.toString() ?? '', 
              style: GoogleFonts.outfit(fontSize: 11, color: subTextColor), 
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.star, color: Color(0xFFFFD700), size: 14),
                const SizedBox(width: 4),
                Text(
                  starRating.toStringAsFixed(1),
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(width: 6),
                Text(
                  '($score%)',
                  style: GoogleFonts.outfit(fontSize: 11, color: subTextColor),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tier.label,
                    style: GoogleFonts.outfit(fontSize: 10, color: tier.color, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _selectMember(m), 
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 4), 
                    minimumSize: const Size(0, 36), 
                    side: BorderSide(color: borderColor, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ), 
                  child: Text(
                    'Details', 
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
                  ),
                ),
              ),
              if (m['status'] == 'pending') ...[
                const SizedBox(width: 6), 
                Expanded(
                  child: ElevatedButton(
                    onPressed: _updating ? null : () => _updateStatus(m['id'], 'active'), 
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary, 
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 4), 
                      minimumSize: const Size(0, 36), 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), 
                      elevation: 0,
                    ), 
                    child: Text(
                      'Approve', 
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
              if (m['status'] == 'active') ...[
                const SizedBox(width: 6), 
                Expanded(
                  child: ElevatedButton(
                    onPressed: _updating ? null : () => _updateStatus(m['id'], 'suspended'), 
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red, 
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 4), 
                      minimumSize: const Size(0, 36), 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), 
                      elevation: 0,
                    ), 
                    child: Text(
                      'Suspend', 
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildMathBreakdownSection(Map<String, dynamic> m, Color primary, bool isDark, Color textColor, Color subTextColor) {
    final bd = m['breakdown'] as Map<String, dynamic>?;
    if (bd == null || bd.isEmpty || !bd.containsKey('standing')) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: Text('Loading compliance breakdown details...', style: TextStyle(color: Colors.grey, fontSize: 12))),
      );
    }

    final standingScore = bd['standing'] ?? 0;
    final financialScore = bd['financial'] ?? 0;
    final eventScore = bd['events'] ?? 0;
    final adminScore = bd['admin'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COMPLIANCE BREAKDOWN MATH',
          style: GoogleFonts.outfit(fontSize: 10, color: subTextColor, fontWeight: FontWeight.w800, letterSpacing: 1),
        ),
        const SizedBox(height: 12),
        
        _breakdownTile(
          icon: Icons.verified_user_outlined,
          color: const Color(0xFF3B82F6),
          title: 'Licensing & Good Standing',
          scoreText: '$standingScore / 40 pts',
          details: [
            '• 40 pts: Active member with valid license.',
            '• 20 pts: Active member but license recently expired.',
            '• 0 pts: Pending, Suspended, or Inactive status.',
          ],
          isDark: isDark,
          textColor: textColor,
          subTextColor: subTextColor,
        ),

        _breakdownTile(
          icon: Icons.payments_outlined,
          color: const Color(0xFF10B981),
          title: 'Financial Compliance',
          scoreText: '$financialScore / 30 pts',
          details: [
            '• Evaluates the ratio of paid invoices vs total issued invoices.',
            '• Members without any invoices start with full points automatically.',
          ],
          isDark: isDark,
          textColor: textColor,
          subTextColor: subTextColor,
        ),
        
        _breakdownTile(
          icon: Icons.event_available_outlined,
          color: const Color(0xFF8B5CF6),
          title: 'Event Attendance',
          scoreText: '$eventScore / 20 pts',
          details: [
            '• Evaluates ratio of attended events vs total events held since joining.',
            '• If no events have been held since joining, member gets full points.',
          ],
          isDark: isDark,
          textColor: textColor,
          subTextColor: subTextColor,
        ),

        _breakdownTile(
          icon: Icons.admin_panel_settings_outlined,
          color: const Color(0xFFF59E0B),
          title: 'Admin Trust Score',
          scoreText: '$adminScore / 10 pts',
          details: [
            '• Derived directly from the manual review slider above.',
          ],
          isDark: isDark,
          textColor: textColor,
          subTextColor: subTextColor,
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
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1)),
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
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12, color: textColor),
                ),
              ),
              Text(
                scoreText,
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: color, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...details.map((detail) => Padding(
            padding: const EdgeInsets.only(top: 2, left: 24),
            child: Text(
              detail,
              style: GoogleFonts.outfit(fontSize: 11, color: subTextColor, fontWeight: FontWeight.w500),
            ),
          )),
        ],
      ),
    );
  }
}

class _KPICard extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final Color cardBg;
  final Color borderColor;

  const _KPICard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.cardBg,
    required this.borderColor,
  });

  @override
  State<_KPICard> createState() => _KPICardState();
}

class _KPICardState extends State<_KPICard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        transform: _isHovered ? Matrix4.translationValues(0.0, -4.0, 0.0) : Matrix4.identity(),
        decoration: BoxDecoration(
          color: widget.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered ? widget.color.withValues(alpha: 0.5) : widget.borderColor,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered 
                  ? widget.color.withValues(alpha: 0.15) 
                  : Colors.black.withValues(alpha: 0.02),
              blurRadius: _isHovered ? 12 : 4,
              offset: _isHovered ? const Offset(0, 6) : const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.color.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: Icon(widget.icon, color: widget.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.label.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white38 : const Color(0xFF64748b),
                        letterSpacing: 0.8,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.value,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0f172a),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
