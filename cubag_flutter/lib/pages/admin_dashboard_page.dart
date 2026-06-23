import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../components/app_layout.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool _loading = true;
  String? _error;
  dynamic _approvingId;

  // Stats Data
  int _totalMembers = 0;
  int _openTickets = 0;
  double _revenue = 0.0;
  List<dynamic> _rawMembers = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  void _prefetchAdminData() {
    final api = ApiService();
    // Warm up and cache critical admin pages in the background
    Future.microtask(() async {
      try {
        // 1. Members Directory (first page)
        await api.fetchDataWithCache('/members/admin/all?page=1&limit=20', (data, isCached, {bool hasError = false}) {});
        // 2. Payments Directory (first page)
        await api.fetchDataWithCache('/payments/admin/all?page=1&limit=20&search=&status=all', (data, isCached, {bool hasError = false}) {});
        // 3. Support Tickets (first page)
        await api.fetchDataWithCache('/tickets/admin/all?page=1&per_page=10&status=inbox', (data, isCached, {bool hasError = false}) {});
        // 4. Announcements (active & archived)
        await api.fetchDataWithCache('/announcements/admin/all?archived=false&page=1&limit=10', (data, isCached, {bool hasError = false}) {});
        await api.fetchDataWithCache('/announcements/admin/all?archived=true&page=1&limit=10', (data, isCached, {bool hasError = false}) {});
        // 5. Cargo Schedules
        await api.fetchDataWithCache('schedules?status=All&page=1&per_page=10', (data, isCached, {bool hasError = false}) {});
        // 6. Events (upcoming & history)
        await api.fetchDataWithCache('/events/admin/all?page=1&per_page=20&status=upcoming', (data, isCached, {bool hasError = false}) {});
        await api.fetchDataWithCache('/events/admin/all?page=1&per_page=20&status=history', (data, isCached, {bool hasError = false}) {});
        // 7. Surveys (active)
        await api.fetchDataWithCache('surveys/admin/all?page=1&per_page=20&status=active', (data, isCached, {bool hasError = false}) {});
      } catch (_) {}
    });
  }

  Future<void> _fetchData() async {
    if (_rawMembers.isEmpty) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final api = ApiService();
    bool statsLoaded = false;
    bool membersLoaded = false;
    bool dashboardFailed = false;

    void checkDone() {
      if (mounted) {
        setState(() {
          if (statsLoaded && membersLoaded) {
            _loading = false;
          }
        });
      }
    }

    // Load Dashboard Stats
    await api.fetchDataWithCache('/admin/dashboard', (data, isCached, {bool hasError = false}) {
      if (!mounted) return;
      if (hasError) {
        dashboardFailed = true;
        setState(() {
          _error = 'Server error loading dashboard stats';
          _loading = false;
        });
        return;
      }
      if (data is Map) {
        final dData = Map<String, dynamic>.from(data);
        if (dData['kpis'] != null) {
          final stats = Map<String, dynamic>.from(dData['kpis']);
          setState(() {
            _totalMembers = int.tryParse(stats['total_members']?.toString() ?? '') ?? 0;
            _openTickets = int.tryParse(stats['open_tickets']?.toString() ?? '') ?? 0;
            _revenue = double.tryParse(stats['revenue']?.toString() ?? '') ?? 0.0;
            statsLoaded = true;
          });
          checkDone();
        }
      }
    });

    // Load Pending Members list
    await api.fetchDataWithCache('/members/admin/all?page=1&limit=100&status=pending', (data, isCached, {bool hasError = false}) {
      if (!mounted) return;
      if (data != null) {
        setState(() {
          _rawMembers = ApiService.ensureList(data);
          membersLoaded = true;
        });
        checkDone();
      }

      if (!isCached && !dashboardFailed) {
        _prefetchAdminData();
      }
    });
  }

  Future<void> _approveMember(dynamic id, String name) async {
    setState(() => _approvingId = id);
    try {
      final res = await ApiService().put('/members/admin/status/$id', data: {'status': 'active'});
      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Member $name has been approved!'),
              backgroundColor: const Color(0xFF10b981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        _fetchData();
      } else {
        final msg = res.data?['message'] ?? 'Unknown error';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Failed to approve member: $msg'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _approvingId = null);
      }
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '??';
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '??';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1e1f26) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2d2e38) : const Color(0xFFe2e8f0);
    final textColor = isDark ? Colors.white : const Color(0xFF0f172a);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF64748b);
    final authService = Provider.of<AuthService>(context);

    final pendingMembers = _rawMembers.where((m) => m['status']?.toString().toLowerCase() == 'pending').toList();

    return AppLayout(
      title: 'Admin Dashboard',
      hideSearch: false,
      scrollable: true,
      child: _loading
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(48.0),
                child: CircularProgressIndicator(color: primary),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error != null) _buildErrorBanner(isDark),
                _buildWelcomeHeader(context, authService.userName),
                _buildKPIGrid(context, pendingMembers.length),
                const SizedBox(height: 24),
                _buildPendingApprovalsCard(context, pendingMembers, primary, cardBg, borderColor, textColor, subTextColor),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildErrorBanner(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFef4444).withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFef4444).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFef4444)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: GoogleFonts.inter(color: const Color(0xFFef4444), fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFef4444), size: 18),
            onPressed: _fetchData,
          )
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader(BuildContext context, String? name) {
    final displayName = name ?? 'Admin';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0f172a);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF64748b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back, $displayName',
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Overview of association compliance, membership directory, and support requests.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: subTextColor,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildKPIGrid(BuildContext context, int pendingCount) {
    final primary = Theme.of(context).primaryColor;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    final revenueLabel = _revenue >= 1000 ? 'GH₵${(_revenue / 1000).toStringAsFixed(1)}k' : 'GH₵${_revenue.toStringAsFixed(0)}';

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isDesktop ? 4 : 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: isDesktop ? 2.2 : 1.6,
      children: [
        _DashboardKPICard(
          icon: Icons.people_alt_rounded,
          color: primary,
          title: 'TOTAL MEMBERS',
          value: '$_totalMembers',
        ),
        _DashboardKPICard(
          icon: Icons.pending_actions_rounded,
          color: Colors.orange,
          title: 'PENDING APPROVALS',
          value: '$pendingCount',
        ),
        _DashboardKPICard(
          icon: Icons.account_balance_wallet_rounded,
          color: const Color(0xFF10b981),
          title: 'TOTAL REVENUE',
          value: revenueLabel,
        ),
        _DashboardKPICard(
          icon: Icons.confirmation_number_rounded,
          color: const Color(0xFF3b82f6),
          title: 'OPEN TICKETS',
          value: '$_openTickets',
        ),
      ],
    );
  }

  Widget _buildPendingApprovalsCard(
    BuildContext context,
    List<dynamic> pendingMembers,
    Color primary,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subTextColor,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.pending_actions_rounded, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Pending License Approvals',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${pendingMembers.length} awaiting review',
                  style: GoogleFonts.inter(
                    color: Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (pendingMembers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36.0, horizontal: 16),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 40),
                    const SizedBox(height: 10),
                    Text(
                      'All caught up!',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'No members are currently waiting for license approvals.',
                      style: GoogleFonts.inter(
                        color: subTextColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pendingMembers.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final m = pendingMembers[index];
                final name = m['name']?.toString() ?? 'Unnamed Member';
                final type = m['member_type']?.toString() ?? 'Individual Broker';
                final id = m['id'];

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: primary.withValues(alpha: 0.1),
                        child: Text(
                          _getInitials(name),
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              type,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: subTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _approvingId == id
                            ? null
                            : () => _approveMember(id, name),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: _approvingId == id
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Approve',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _DashboardKPICard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;

  const _DashboardKPICard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1e1f26) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2d2e38) : const Color(0xFFe2e8f0);
    final textColor = isDark ? Colors.white : const Color(0xFF0f172a);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF64748b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: subTextColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
