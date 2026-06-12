import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../components/app_layout.dart';
import '../components/shimmer_loader.dart';
import '../services/cache_service.dart';
import '../services/api_service.dart';

class VanningSchedulesPage extends StatefulWidget {
  const VanningSchedulesPage({super.key});
  @override
  State<VanningSchedulesPage> createState() => _VanningSchedulesPageState();
}

class _VanningSchedulesPageState extends State<VanningSchedulesPage> {
  bool _loading = true;
  List<dynamic> _schedules = [];
  final CacheService _cache = CacheService();
  String _searchQuery = '';
  String _selectedStatus = 'All';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (!_loading) setState(() => _loading = true);
    try {
      final data = await _cache.fetchCached('/schedules/vanning');
      if (mounted) setState(() => _schedules = ApiService.ensureList(data));
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1f2028) : Colors.white;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobileLayout = screenWidth < 600;

    // Compute dynamic statistics
    final totalCount = _schedules.length;
    final inProgressCount = _schedules.where((s) => s['status'] == 'In Progress').length;
    final scheduledCount = _schedules.where((s) => s['status'] == 'Scheduled' || s['status'] == 'Pending' || s['status'] == 'scheduled').length;

    Widget buildStatCard(String label, String value, IconData icon, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : const Color(0xFF64748b),
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0f172a),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Build the responsive stats dashboard
    final statWidget = isMobileLayout
        ? Row(
            children: [
              buildStatCard('Total', '$totalCount', Icons.inventory_2_rounded, primary),
              const SizedBox(width: 8),
              buildStatCard('Active', '$inProgressCount', Icons.local_shipping_rounded, const Color(0xFF3b82f6)),
              const SizedBox(width: 8),
              buildStatCard('Scheduled', '$scheduledCount', Icons.calendar_month_rounded, const Color(0xFF10b981)),
            ],
          )
        : Row(
            children: [
              buildStatCard('Total Shipments', '$totalCount', Icons.inventory_2_rounded, primary),
              const SizedBox(width: 12),
              buildStatCard('In Progress', '$inProgressCount', Icons.local_shipping_rounded, const Color(0xFF3b82f6)),
              const SizedBox(width: 12),
              buildStatCard('Scheduled', '$scheduledCount', Icons.calendar_month_rounded, const Color(0xFF10b981)),
            ],
          );

    // Filter Chips
    final List<String> statusFilters = ['All', 'In Progress', 'Scheduled'];
    final filterChipsWidget = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: statusFilters.map((status) {
          final isSelected = _selectedStatus == status;
          int count = 0;
          if (status == 'All') {
            count = totalCount;
          } else if (status == 'In Progress') {
            count = inProgressCount;
          } else if (status == 'Scheduled') {
            count = scheduledCount;
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(
                '$status ($count)',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
              ),
              selected: isSelected,
              selectedColor: primary,
              backgroundColor: isDark ? const Color(0xFF2a2b36) : const Color(0xFFf1f5f9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? primary
                      : (isDark ? const Color(0xFF3a3b46) : const Color(0xFFe2e8f0)),
                  width: 1,
                ),
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedStatus = status;
                  });
                }
              },
            ),
          );
        }).toList(),
      ),
    );

    // Search Field
    final searchWidget = TextField(
      onChanged: (val) {
        setState(() {
          _searchQuery = val;
        });
      },
      style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white : const Color(0xFF0f172a)),
      decoration: InputDecoration(
        hintText: "Search container or vessel...",
        hintStyle: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF94a3b8)),
        prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.white54 : const Color(0xFF94a3b8)),
        filled: true,
        fillColor: isDark ? const Color(0xFF1f2028) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                  });
                },
              )
            : null,
      ),
    );

    // Filter list of schedules
    final filteredList = _schedules.where((s) {
      final container = s['container']?.toString().toLowerCase() ?? '';
      final vessel = s['vessel']?.toString().toLowerCase() ?? '';
      final status = s['status']?.toString() ?? 'Scheduled';
      final matchesSearch = container.contains(_searchQuery.toLowerCase()) ||
          vessel.contains(_searchQuery.toLowerCase());

      bool matchesStatus = true;
      if (_selectedStatus == 'In Progress') {
        matchesStatus = status == 'In Progress';
      } else if (_selectedStatus == 'Scheduled') {
        matchesStatus = status == 'Scheduled' || status == 'Pending' || status == 'scheduled';
      }

      return matchesSearch && matchesStatus;
    }).toList();

    // Vanning Cargo Card builder
    Widget buildVanningCard(Map<String, dynamic> s) {
      final status = s['status']?.toString() ?? 'Scheduled';
      final isInProgress = status == 'In Progress';
      final statusColor = isInProgress ? const Color(0xFF3b82f6) : const Color(0xFF10b981);
      final containerNum = s['container']?.toString() ?? 'PENDING';
      final vesselName = s['vessel']?.toString() ?? 'TBA';
      final portName = s['port']?.toString() ?? 'Unknown Port';
      final dateStr = s['date']?.toString() ?? 'No Date';

      Widget detailRow(IconData icon, String label, String value) {
        return Row(
          children: [
            Icon(icon, size: 14, color: isDark ? Colors.white54 : const Color(0xFF64748b)),
            const SizedBox(width: 8),
            Text(
              '$label: ',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? Colors.white60 : const Color(0xFF64748b),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1e293b),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      }

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).dividerColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.local_shipping_rounded, color: primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        containerNum != 'PENDING' ? containerNum : 'Vessel: $vesselName',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : const Color(0xFF0f172a),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Vanning Cargo Schedule',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: isDark ? Colors.white70 : const Color(0xFF64748b),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: GoogleFonts.outfit(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF16171d) : const Color(0xFFf8fafc),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                children: [
                  detailRow(Icons.directions_boat_outlined, 'Vessel', vesselName),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(height: 1, thickness: 0.5),
                  ),
                  detailRow(Icons.place_outlined, 'Port of Loading', portName),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(height: 1, thickness: 0.5),
                  ),
                  detailRow(Icons.calendar_month_outlined, 'Loading Date', dateStr),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Empty state view
    final emptyStateWidget = Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.calendar_today_rounded, size: 36, color: primary),
          ),
          const SizedBox(height: 16),
          Text(
            'No Vanning Schedules Found',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDark ? Colors.white : const Color(0xFF0f172a),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try adjusting your search query to find cargo schedules.'
                : 'There are currently no vanning schedules available.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF64748b),
            ),
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text(
                'Clear Search',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );

    return AppLayout(
      title: 'Vanning Schedules',
      scrollable: false,
      child: RefreshIndicator(
        onRefresh: _fetch,
        color: primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Statistics overview
                    statWidget,
                    const SizedBox(height: 24),

                    // Controls (Search + Filters)
                    searchWidget,
                    const SizedBox(height: 16),
                    filterChipsWidget,
                    const SizedBox(height: 24),

                    // Content Area
                    if (_loading)
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 3,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 16),
                        itemBuilder: (ctx, i) => const ShimmerListTile(),
                      )
                    else if (filteredList.isEmpty)
                      emptyStateWidget
                    else
                      ...filteredList.map((s) => buildVanningCard(s)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
