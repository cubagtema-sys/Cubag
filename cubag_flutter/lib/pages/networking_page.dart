import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../components/app_layout.dart';
import '../components/shimmer_loader.dart';
import '../services/api_service.dart';

const _kOrange = Color(0xFFf08232);

class NetworkingPage extends StatefulWidget {
  const NetworkingPage({super.key});
  @override
  State<NetworkingPage> createState() => _NetworkingPageState();
}

class _NetworkingPageState extends State<NetworkingPage> {
  bool _loading = true;
  List<dynamic> _members = [];
  String _search = '';
  String _filterType = 'All';
  Map<String, dynamic>? _selected;
  final TextEditingController _searchCtrl = TextEditingController();

  final Map<String, Color> _typeColors = {
    'Corporate Agency':  const Color(0xFF3b82f6),
    'Individual Broker': _kOrange,
    'Freight Forwarder': const Color(0xFF10b981),
    'Shipping Line':     const Color(0xFF8b5cf6),
  };

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = _search;
    _fetch();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    if (!_loading) setState(() => _loading = true);
    await ApiService().fetchDataWithCache('/members', (data, isCached, {bool hasError = false}) {
      if (mounted && data != null) {
        setState(() {
          _members = ApiService.ensureList(data);
          _loading = false;
        });
      }
    });
  }

  String _initials(String name) => name.trim().isEmpty ? '?' : name.split(' ').where((n) => n.isNotEmpty).map((n) => n[0]).take(2).join().toUpperCase();

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filterType == value;
    return GestureDetector(
      onTap: () => setState(() => _filterType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isSelected ? _kOrange : const Color(0xFFf1f5f9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _kOrange : const Color(0xFFe2e8f0),
            width: 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: _kOrange.withAlpha(30), blurRadius: 8, offset: const Offset(0, 3))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF475569),
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFf8fafc),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 48,
                color: Color(0xFFcbd5e1),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Members Found',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _search.isNotEmpty
                  ? 'Try refining your keywords or clearing the search query.'
                  : 'There are no active members registered in this category.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF94a3b8),
                height: 1.4,
              ),
            ),
            if (_search.isNotEmpty || _filterType != 'All') ...[
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => setState(() {
                  _searchCtrl.clear();
                  _search = '';
                  _filterType = 'All';
                }),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFcbd5e1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Reset Filters',
                  style: TextStyle(
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> m, Color primary) {
    final color = _typeColors[m['member_type']] ?? primary;
    final initials = _initials(m['name']?.toString() ?? '');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFcbd5e1).withAlpha(120), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Hero(
                tag: 'avatar_${m['id']}',
                child: Material(
                  type: MaterialType.transparency,
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: color.withAlpha(20),
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m['name']?.toString() ?? '',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: const Color(0xFF0f172a),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      m['member_type']?.toString() ?? '',
                      style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.business_outlined, size: 14, color: Color(0xFF94a3b8)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  m['company']?.toString() ?? 'Independent',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748b),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() => _selected = Map<String, dynamic>.from(m));
                _showMemberDetails(context, m, primary);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _kOrange,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'View Profile',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMemberDetails(BuildContext context, Map<String, dynamic> m, Color primary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxWidth: 600,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4, margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildDetailSheet(primary),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _selected = null);
    });
  }

  Widget _buildDetailSheet(Color primary) {
    final m = _selected!;
    final color = _typeColors[m['member_type']] ?? primary;
    final initials = _initials(m['name']?.toString() ?? '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Hero(
              tag: 'avatar_${m['id']}',
              child: Material(
                type: MaterialType.transparency,
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: color.withAlpha(20),
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m['name']?.toString() ?? '',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: const Color(0xFF0f172a),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withAlpha(20),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      (m['member_type']?.toString() ?? '').toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        color: color,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Info Rows
        ...([
          {'icon': Icons.business_outlined, 'label': 'Organisation', 'val': m['company']},
          {'icon': Icons.location_on_outlined, 'label': 'Port / Operation', 'val': m['port_of_operation']},
          {'icon': Icons.badge_outlined, 'label': 'License No.', 'val': m['license_number']},
          {'icon': Icons.mail_outline_rounded, 'label': 'Email Address', 'val': m['email']},
          {'icon': Icons.phone_outlined, 'label': 'Phone Number', 'val': m['phone']},
        ].where((r) => r['val'] != null && r['val'].toString().isNotEmpty)).map((row) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFf8fafc),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFf1f5f9), width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(row['icon'] as IconData, color: color, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row['label'].toString().toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        row['val'].toString(),
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1e293b),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () {
                  final id = m['id']?.toString() ?? '';
                  final name = m['name']?.toString() ?? '';
                  final company = m['company']?.toString() ?? '';
                  final uri = Uri(path: '/messaging', queryParameters: {
                    'id': id,
                    'name': name,
                    'company': company,
                  });
                  context.go(uri.toString());
                  setState(() => _selected = null);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kOrange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                label: Text(
                  'Message',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  side: const BorderSide(color: Color(0xFFcbd5e1), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  foregroundColor: const Color(0xFF475569),
                ),
                icon: const Icon(Icons.mail_outline_rounded, size: 18),
                label: Text(
                  'Email',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    final filtered = _members.where((m) {
      if (m['role'] == 'admin' || m['role'] == 'sub_admin') return false;
      final q = _search.toLowerCase();
      final matchSearch = (m['name'] ?? '').toString().toLowerCase().contains(q) || (m['company'] ?? '').toString().toLowerCase().contains(q);
      final matchType = _filterType == 'All' || m['member_type'] == _filterType;
      return matchSearch && matchType;
    }).toList();

    return AppLayout(
      title: 'Member Directory',
      scrollable: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Member Directory',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0f172a),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Search and connect with CUBAG certified professionals.',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF64748b),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),

                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFf1f5f9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextFormField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: 'Search members by name or company...',
                      hintStyle: const TextStyle(color: Color(0xFF94a3b8), fontSize: 14),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94a3b8)),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, color: Color(0xFF94a3b8)),
                              onPressed: () => setState(() {
                                _searchCtrl.clear();
                                _search = '';
                              }),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Type filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'All Types'),
                      _buildFilterChip('Corporate Agency', 'Corporate Agency'),
                      _buildFilterChip('Individual Broker', 'Individual Broker'),
                      _buildFilterChip('Freight Forwarder', 'Freight Forwarder'),
                      _buildFilterChip('Shipping Line', 'Shipping Line'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                if (!_loading)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'FOUND ${filtered.length} MEMBERS',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: const Color(0xFF64748b),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),

                // Grid / List View
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetch,
                    color: _kOrange,
                    child: _loading && filtered.isEmpty
                        ? ListView.separated(
                            itemCount: 5,
                            separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                            itemBuilder: (ctx, i) => const ShimmerListTile(),
                          )
                        : filtered.isEmpty
                            ? _buildEmptyState()
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  final isWide = constraints.maxWidth > 600;
                                  if (isWide) {
                                    return GridView.builder(
                                      physics: const AlwaysScrollableScrollPhysics(),
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 12,
                                        childAspectRatio: 1.45,
                                      ),
                                      itemCount: filtered.length,
                                      itemBuilder: (context, i) {
                                        return _buildMemberCard(filtered[i], primary);
                                      },
                                    );
                                  } else {
                                    return ListView.separated(
                                      physics: const AlwaysScrollableScrollPhysics(),
                                      itemCount: filtered.length,
                                      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                                      itemBuilder: (context, i) {
                                        return _buildMemberCard(filtered[i], primary);
                                      },
                                    );
                                  }
                                },
                              ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
