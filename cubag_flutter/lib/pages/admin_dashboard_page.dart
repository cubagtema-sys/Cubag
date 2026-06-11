import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:google_fonts/google_fonts.dart';
import '../components/app_layout.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  String? _error;

  // Date Range Filtering
  String _dateFilter = 'All Time';
  List<dynamic> _rawMembers = [];

  // Financial Stats
  double _revenue = 0.0;
  double _pendingRevenue = 0.0;
  double _failedRevenue = 0.0;
  List<dynamic> _transactions = [];

  // Membership Stats
  int _totalMembers = 0;
  Map<String, double> _statusCounts = {'active': 0, 'pending': 0, 'suspended': 0, 'inactive': 0};
  Map<String, double> _typeCounts = {'Corporate Agency': 0, 'Individual Broker': 0, 'Freight Forwarder': 0, 'Shipping Line': 0};

  // Operational Stats
  int _openTickets = 0;
  int _announcementsCount = 0;
  int _cargoSchedulesCount = 0;

  // Original Dashboard Stats
  Map<String, dynamic> _stats = {
    'total_members': 0, 'active_members': 0, 'revenue': 0,
    'pending_members': 0, 'open_tickets': 0
  };
  List<dynamic> _recentMembers = [];

  bool _isWithinDateRange(String? dateStr) {
    if (dateStr == null) return false;
    final date = DateTime.tryParse(dateStr);
    if (date == null) return false;
    
    final now = DateTime.now();
    switch (_dateFilter) {
      case 'Last 7 Days':
        final limit = now.subtract(const Duration(days: 7));
        return date.isAfter(limit);
      case 'Last 30 Days':
        final limit = now.subtract(const Duration(days: 30));
        return date.isAfter(limit);
      case 'Year to Date':
        final startOfYear = DateTime(now.year, 1, 1);
        return date.isAfter(startOfYear) || date.isAtSameMomentAs(startOfYear);
      case 'All Time':
      default:
        return true;
    }
  }

  // Getters for filtered Financial metrics
  double get _filteredRevenue {
    if (_dateFilter == 'All Time') return _revenue;
    return _transactions
        .where((tx) => tx['status']?.toString().toLowerCase() == 'paid' && _isWithinDateRange(tx['date']?.toString() ?? tx['created_at']?.toString()))
        .fold(0.0, (sum, tx) => sum + (double.tryParse(tx['amount']?.toString() ?? '0') ?? 0.0));
  }

  double get _filteredPendingRevenue {
    if (_dateFilter == 'All Time') return _pendingRevenue;
    return _transactions
        .where((tx) => tx['status']?.toString().toLowerCase() == 'pending' && _isWithinDateRange(tx['date']?.toString() ?? tx['created_at']?.toString()))
        .fold(0.0, (sum, tx) => sum + (double.tryParse(tx['amount']?.toString() ?? '0') ?? 0.0));
  }

  double get _filteredFailedRevenue {
    if (_dateFilter == 'All Time') return _failedRevenue;
    return _transactions
        .where((tx) => (tx['status']?.toString().toLowerCase() == 'failed' || tx['status']?.toString().toLowerCase() == 'overdue') && _isWithinDateRange(tx['date']?.toString() ?? tx['created_at']?.toString()))
        .fold(0.0, (sum, tx) => sum + (double.tryParse(tx['amount']?.toString() ?? '0') ?? 0.0));
  }

  List<dynamic> get _filteredTransactionsList {
    return _transactions
        .where((tx) => _isWithinDateRange(tx['date']?.toString() ?? tx['created_at']?.toString()))
        .toList();
  }

  Map<String, double> get _filteredMonthlyRevenueMap {
    final Map<String, double> filteredMap = {};
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    for (var tx in _transactions) {
      if (tx['status']?.toString().toLowerCase() == 'paid' && _isWithinDateRange(tx['date']?.toString() ?? tx['created_at']?.toString())) {
        try {
          final date = DateTime.parse(tx['date']?.toString() ?? tx['created_at']?.toString() ?? '');
          final monthLabel = '${months[date.month - 1]} ${date.year.toString().substring(2)}';
          final amt = (double.tryParse(tx['amount']?.toString() ?? '0') ?? 0.0);
          filteredMap[monthLabel] = (filteredMap[monthLabel] ?? 0.0) + amt;
        } catch (_) {}
      }
    }
    return filteredMap;
  }

  // Getters for filtered Membership metrics
  int get _filteredTotalMembersCount {
    if (_dateFilter == 'All Time') return _totalMembers;
    final filtered = _rawMembers.where((m) {
      final dateStr = m['created_at']?.toString() ?? m['date']?.toString();
      if (dateStr == null) return true; 
      return _isWithinDateRange(dateStr);
    }).toList();
    return filtered.length;
  }

  Map<String, double> get _filteredStatusCountsMap {
    if (_dateFilter == 'All Time') return _statusCounts;
    final Map<String, double> counts = {'active': 0, 'pending': 0, 'suspended': 0, 'inactive': 0};
    for (var m in _rawMembers) {
      final dateStr = m['created_at']?.toString() ?? m['date']?.toString();
      if (dateStr != null && !_isWithinDateRange(dateStr)) continue;
      
      final status = (m['status'] ?? '').toString().toLowerCase();
      if (counts.containsKey(status)) {
        counts[status] = counts[status]! + 1;
      }
    }
    return counts;
  }

  Map<String, double> get _filteredTypeCountsMap {
    if (_dateFilter == 'All Time') return _typeCounts;
    final Map<String, double> counts = {'Corporate Agency': 0, 'Individual Broker': 0, 'Freight Forwarder': 0, 'Shipping Line': 0};
    for (var m in _rawMembers) {
      final dateStr = m['created_at']?.toString() ?? m['date']?.toString();
      if (dateStr != null && !_isWithinDateRange(dateStr)) continue;

      final type = (m['member_type'] ?? '').toString();
      if (type.isNotEmpty) {
        if (counts.containsKey(type)) {
          counts[type] = counts[type]! + 1;
        } else {
          counts[type] = (counts[type] ?? 0) + 1;
        }
      }
    }
    return counts;
  }

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthService>(context, listen: false);
    int tabCount = 0;
    if (auth.hasPermission('payments')) tabCount++;
    if (auth.hasPermission('members')) tabCount++;
    if (auth.hasPermission('tickets') || auth.hasPermission('schedules') || auth.hasPermission('announcements')) tabCount++;
    
    _tabController = TabController(length: tabCount == 0 ? 1 : tabCount, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final api = ApiService();

    try {
      final results = await Future.wait([
        api.get('/admin/dashboard').catchError((e) => Response(requestOptions: RequestOptions(), statusCode: 500, data: {'message': e.toString()})),
        api.get('/payments/admin/all?page=1&limit=200').catchError((_) => Response(requestOptions: RequestOptions(), statusCode: 403, data: null)),
        api.get('/members/admin/all?page=1&limit=500').catchError((_) => Response(requestOptions: RequestOptions(), statusCode: 403, data: null)),
      ]);

      final dRes = results[0];
      final fRes = results[1];
      final mRes = results[2];

      bool dashboardFailed = false;

      // ── 1. Handle Dashboard KPIs ──
      if (dRes.statusCode == 200 && dRes.data is Map) {
        final dData = Map<String, dynamic>.from(dRes.data);

        if (dData['kpis'] != null) {
          _stats = Map<String, dynamic>.from(dData['kpis']);
          _totalMembers = int.tryParse(_stats['total_members']?.toString() ?? '') ?? 0;
          _openTickets = int.tryParse(_stats['open_tickets']?.toString() ?? '') ?? 0;
          _revenue = double.tryParse(_stats['revenue']?.toString() ?? '') ?? 0.0;
          _pendingRevenue = double.tryParse(_stats['pending_revenue']?.toString() ?? '') ?? 0.0;
          _failedRevenue = double.tryParse(_stats['failed_revenue']?.toString() ?? '') ?? 0.0;
          _announcementsCount = int.tryParse(_stats['announcements']?.toString() ?? '') ?? 0;
          _cargoSchedulesCount = int.tryParse(_stats['schedules']?.toString() ?? '') ?? 0;
        }

        if (dData['status_counts'] != null) {
          final sc = Map<String, dynamic>.from(dData['status_counts']);
          _statusCounts = sc.map((k, v) => MapEntry(k.toString(), double.tryParse(v?.toString() ?? '0') ?? 0.0));
        }
        if (dData['type_counts'] != null) {
          final tc = Map<String, dynamic>.from(dData['type_counts']);
          _typeCounts = tc.map((k, v) => MapEntry(k.toString(), double.tryParse(v?.toString() ?? '0') ?? 0.0));
        }
        if (dData['recent_members'] != null) {
          _recentMembers = ApiService.ensureList(dData['recent_members']);
        }
      } else {
        dashboardFailed = true;
        if (dRes.data != null && dRes.data is Map) {
          _error = dRes.data['message'] ?? dRes.data['error_details'];
        } else {
          _error = 'Server error loading dashboard stats';
        }
      }

      // ── 2. Handle Payments ──
      if (fRes.statusCode == 200 && fRes.data != null) {
        final fData = fRes.data is Map ? Map<String, dynamic>.from(fRes.data) : null;
        _transactions = ApiService.ensureList(fRes.data);

        if (fData != null) {
          final kpis = fData['kpis'] as Map<String, dynamic>? ?? {};
          if (kpis.isNotEmpty) {
            _revenue = double.tryParse(kpis['revenue']?.toString() ?? '') ?? _revenue;
            _pendingRevenue = double.tryParse(kpis['pending']?.toString() ?? '') ?? _pendingRevenue;
            _failedRevenue = double.tryParse(kpis['failed']?.toString() ?? '') ?? _failedRevenue;
          }
        }
      }

      // ── 3. Handle Members ──
      if (mRes.statusCode == 200 && mRes.data != null) {
        _rawMembers = ApiService.ensureList(mRes.data);
        if (_dateFilter != 'All Time' && _rawMembers.isNotEmpty) {
          final Map<String, double> sc = {'active': 0, 'pending': 0, 'suspended': 0, 'inactive': 0};
          final Map<String, double> tc = {'Corporate Agency': 0, 'Individual Broker': 0, 'Freight Forwarder': 0, 'Shipping Line': 0};
          for (var m in _rawMembers) {
            final status = (m['status'] ?? '').toString().toLowerCase();
            if (sc.containsKey(status)) sc[status] = sc[status]! + 1;
            final type = (m['member_type'] ?? '').toString();
            if (type.isNotEmpty) {
              if (tc.containsKey(type)) {
                tc[type] = tc[type]! + 1;
              } else {
                tc[type] = (tc[type] ?? 0) + 1;
              }
            }
          }
          _statusCounts = sc;
          _typeCounts = tc;
        }
      }

      if (mounted) {
        setState(() {
          _loading = false;
          if (dashboardFailed && _error == null) {
            _error = 'Dashboard could not load critical data.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'An unexpected error occurred: $e';
        });
      }
    }
  }

  Future<void> _exportCSV(String title, String csvContent) async {
    try {
      final uri = Uri.dataFromString(
        csvContent,
        mimeType: 'text/csv',
        encoding: utf8,
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw 'Could not launch CSV download';
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Export $title'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your browser blocked the direct file download. You can copy the CSV data below:', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 10),
                Container(
                  height: 150,
                  width: double.maxFinite,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.grey.shade50, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                  child: SingleChildScrollView(child: SelectableText(csvContent, style: const TextStyle(fontSize: 10, fontFamily: 'monospace'))),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.download, color: Theme.of(context).primaryColor),
            const SizedBox(width: 10),
            const Text('Export Report Data'),
          ],
        ),
        content: const Text(
          'Select the dataset you would like to download as a spreadsheet-compatible CSV file.',
          style: TextStyle(color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _exportFinancialsCSV();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(0, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Financial Ledger'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _exportMembersCSV();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3b82f6),
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(0, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Members Roster'),
          ),
        ],
      ),
    );
  }

  void _exportFinancialsCSV() {
    final filteredTx = _transactions.where((tx) => _isWithinDateRange(tx['date']?.toString() ?? tx['created_at']?.toString())).toList();
    String csv = 'ID,Date,Member Name,Member Type,Amount,Method,Reference,Status\n';
    for (var tx in filteredTx) {
      final id = tx['id']?.toString() ?? '';
      final date = tx['date']?.toString() ?? tx['created_at']?.toString() ?? '';
      final name = '"${tx['member_name']?.toString().replaceAll('"', '""') ?? ''}"';
      final type = '"${tx['member_type']?.toString().replaceAll('"', '""') ?? ''}"';
      final amount = tx['amount']?.toString() ?? '0.00';
      final method = tx['payment_method']?.toString() ?? 'Mobile Money';
      final ref = tx['reference']?.toString() ?? '';
      final status = tx['status']?.toString() ?? 'pending';
      csv += '$id,$date,$name,$type,$amount,$method,$ref,$status\n';
    }
    _exportCSV('Financial_Ledger_${_dateFilter.replaceAll(' ', '_')}', csv);
  }

  void _exportMembersCSV() {
    final filteredMembers = _rawMembers.where((m) {
      final dateStr = m['created_at']?.toString() ?? m['date']?.toString();
      if (dateStr == null) return true;
      return _isWithinDateRange(dateStr);
    }).toList();
    String csv = 'ID,Name,Email,Type,Status,License Number,Phone\n';
    for (var m in filteredMembers) {
      final id = m['id']?.toString() ?? '';
      final name = '"${m['name']?.toString().replaceAll('"', '""') ?? ''}"';
      final email = m['email']?.toString() ?? '';
      final type = '"${m['member_type']?.toString().replaceAll('"', '""') ?? ''}"';
      final status = m['status']?.toString() ?? '';
      final lic = m['license_number']?.toString() ?? '';
      final phone = m['phone']?.toString() ?? '';
      csv += '$id,$name,$email,$type,$status,$lic,$phone\n';
    }
    _exportCSV('Members_Roster_${_dateFilter.replaceAll(' ', '_')}', csv);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1e1f26) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2d2e38) : const Color(0xFFe2e8f0);
    final textColor = isDark ? Colors.white : const Color(0xFF0f172a);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF64748b);
    final authService = Provider.of<AuthService>(context);

    return AppLayout(
      title: 'Admin Dashboard',
      hideSearch: false,
      scrollable: false,
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
                _buildWelcomeBanner(context, authService.userName, cardBg, borderColor, textColor, subTextColor, primary),
                _buildHeaderBar(cardBg, borderColor, textColor, primary),
                const SizedBox(height: 16),
                _buildKPIGrid(isDesktop, cardBg, borderColor),
                const SizedBox(height: 20),
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildAnalyticsSection(isDark, cardBg, borderColor, textColor, subTextColor, primary),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            _buildPortalManagementCard(cardBg, borderColor, textColor, subTextColor),
                            const SizedBox(height: 16),
                            _buildRecentRegistrationsCard(primary, cardBg, borderColor, textColor, subTextColor),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildAnalyticsSection(isDark, cardBg, borderColor, textColor, subTextColor, primary),
                      const SizedBox(height: 16),
                      _buildPortalManagementCard(cardBg, borderColor, textColor, subTextColor),
                      const SizedBox(height: 16),
                      _buildRecentRegistrationsCard(primary, cardBg, borderColor, textColor, subTextColor),
                    ],
                  ),
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

  Widget _buildWelcomeBanner(BuildContext context, String? name, Color cardBg, Color borderColor, Color textColor, Color subTextColor, Color primary) {
    final hour = DateTime.now().hour;
    String greeting = 'Welcome back';
    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 18) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayName = name ?? 'Admin';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark 
              ? [const Color(0xFF1e1f26), const Color(0xFF261c15)] 
              : [primary.withValues(alpha: 0.04), primary.withValues(alpha: 0.1)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF3e2d23).withValues(alpha: 0.4) : primary.withValues(alpha: 0.15), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.admin_panel_settings_rounded, color: primary, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, $displayName!',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Here is the status of the CUBAG platform today. All services are fully operational.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: subTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (MediaQuery.of(context).size.width > 600) ...[
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF10b981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10b981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'ONLINE',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF10b981),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderBar(Color cardBg, Color borderColor, Color textColor, Color primary) {
    final isSmall = MediaQuery.of(context).size.width < 500;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Overview Insights',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            if (!isSmall) _buildActionButtons(context, cardBg, borderColor, textColor, primary),
          ],
        ),
        if (isSmall) ...[
          const SizedBox(height: 12),
          _buildActionButtons(context, cardBg, borderColor, textColor, primary),
        ],
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, Color cardBg, Color borderColor, Color textColor, Color primary) {
    final isSmall = MediaQuery.of(context).size.width < 500;
    
    final filters = [
      {'value': 'All Time', 'label': 'All Time'},
      {'value': 'Last 7 Days', 'label': '7 Days'},
      {'value': 'Last 30 Days', 'label': '30 Days'},
      {'value': 'Year to Date', 'label': 'YTD'},
    ];

    return Row(
      mainAxisAlignment: isSmall ? MainAxisAlignment.spaceBetween : MainAxisAlignment.end,
      children: [
        ElevatedButton.icon(
          onPressed: _showExportDialog,
          icon: Icon(Icons.download_rounded, size: 14, color: primary),
          label: Text('Export', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: primary)),
          style: ElevatedButton.styleFrom(
            backgroundColor: cardBg,
            elevation: 0,
            minimumSize: const Size(0, 40),
            side: BorderSide(color: primary.withValues(alpha: 0.5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSmall ? Colors.transparent : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF13141a) : const Color(0xFFf1f5f9)),
            borderRadius: BorderRadius.circular(10),
            border: isSmall ? null : Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: filters.map((f) {
              final isSelected = _dateFilter == f['value'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _dateFilter = f['value']!;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? primary 
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: isSelected 
                        ? [BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 1))]
                        : null,
                  ),
                  child: Text(
                    f['label']!,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected 
                          ? Colors.white 
                          : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF475569)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildKPIGrid(bool isDesktop, Color cardBg, Color borderColor) {
    final primary = Theme.of(context).primaryColor;
    final auth = Provider.of<AuthService>(context, listen: false);
    
    final revenue = _filteredRevenue;
    final revenueLabel = revenue >= 1000 ? 'GH₵${(revenue / 1000).toStringAsFixed(1)}k' : 'GH₵${revenue.toStringAsFixed(0)}';

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isDesktop ? 4 : 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: isDesktop ? 2.2 : 1.6,
      children: [
        if (auth.hasPermission('members'))
          _KPICard(
            icon: Icons.people_alt_rounded,
            color: primary,
            label: 'Total Users',
            value: '$_filteredTotalMembersCount',
            cardBg: cardBg,
            borderColor: borderColor,
          ),
        if (auth.hasPermission('members'))
          _KPICard(
            icon: Icons.verified_user_rounded,
            color: const Color(0xFF10b981),
            label: 'Active Licenses',
            value: '${_stats['active_members'] ?? 0}',
            cardBg: cardBg,
            borderColor: borderColor,
          ),
        if (auth.hasPermission('tickets'))
          _KPICard(
            icon: Icons.support_agent_rounded,
            color: const Color(0xFFf59e0b),
            label: 'Open Tickets',
            value: '${_stats['open_tickets'] ?? 0}',
            cardBg: cardBg,
            borderColor: borderColor,
          ),
        if (auth.hasPermission('payments'))
          _KPICard(
            icon: Icons.payments_rounded,
            color: const Color(0xFF3b82f6),
            label: 'Revenue Collected',
            value: revenueLabel,
            cardBg: cardBg,
            borderColor: borderColor,
          ),
      ],
    );
  }

  Widget _buildAnalyticsSection(bool isDark, Color cardBg, Color borderColor, Color textColor, Color subTextColor, Color primary) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final List<Widget> tabs = [];
    final List<Widget> children = [];

    if (auth.hasPermission('payments')) {
      tabs.add(const Tab(text: 'Financial Center'));
      children.add(_buildFinancialTab(isDark, cardBg, borderColor, textColor, subTextColor, primary));
    }
    if (auth.hasPermission('members')) {
      tabs.add(const Tab(text: 'Membership Insights'));
      children.add(_buildMembershipTab(isDark, cardBg, borderColor, textColor, subTextColor, primary));
    }
    if (auth.hasPermission('tickets') || auth.hasPermission('schedules') || auth.hasPermission('announcements')) {
      tabs.add(const Tab(text: 'Operations & Alerts'));
      children.add(_buildOperationsTab(isDark, cardBg, borderColor, textColor, subTextColor, primary));
    }

    if (tabs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pill style Tab Bar
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF13141a) : const Color(0xFFf1f5f9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: primary,
            unselectedLabelColor: isDark ? Colors.white38 : const Color(0xFF64748b),
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: isDark ? const Color(0xFF1e1f26) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            dividerColor: Colors.transparent,
            labelStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold),
            unselectedLabelStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: tabs,
          ),
        ),
        const SizedBox(height: 16),

        // Tab Body
        SizedBox(
          height: 540,
          child: TabBarView(
            controller: _tabController,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialTab(bool isDark, Color cardBg, Color borderColor, Color textColor, Color subTextColor, Color primary) {
    final filteredMonthly = _filteredMonthlyRevenueMap;
    final sortedMonths = filteredMonthly.keys.toList()..sort();
    final values = sortedMonths.map((m) => filteredMonthly[m] ?? 0.0).toList();

    final maxVal = values.isNotEmpty ? values.reduce((curr, next) => curr > next ? curr : next) : 1000.0;
    final filteredTx = _filteredTransactionsList;
    final isMobile = MediaQuery.of(context).size.width < 900;

    final chartContainer = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Revenue Collection Trend (GH₵)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
          const SizedBox(height: 16),
          sortedMonths.isEmpty
              ? SizedBox(
                  height: 190,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bar_chart_rounded, size: 40, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text('No revenue data available', style: GoogleFonts.inter(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                )
              : _CustomBarChart(
                  values: values,
                  labels: sortedMonths,
                  maxValue: maxVal,
                  color: primary,
                ),
        ],
      ),
    );

    final distContainer = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dues Distribution', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
          const SizedBox(height: 16),
          _financialMetricBar('Paid Revenue', _filteredRevenue, const Color(0xFF10b981)),
          _financialMetricBar('Pending Receivables', _filteredPendingRevenue, const Color(0xFFf59e0b)),
          _financialMetricBar('Failed/Overdue Dues', _filteredFailedRevenue, const Color(0xFFef4444)),
        ],
      ),
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [chartContainer, const SizedBox(height: 12), distContainer],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: chartContainer),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: distContainer),
                  ],
                ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Recent Payment Ledger', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                const SizedBox(height: 12),
                if (filteredTx.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(child: Text('No transaction logs found for this period', style: GoogleFonts.inter(color: Colors.grey, fontSize: 13))),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredTx.length > 5 ? 5 : filteredTx.length,
                    separatorBuilder: (c, i) => Divider(color: borderColor, height: 1),
                    itemBuilder: (context, index) {
                      final tx = filteredTx[index];
                      final status = (tx['status']?.toString() ?? 'pending').toLowerCase();
                      
                      Color statusText;
                      Color statusBg;
                      if (status == 'paid') {
                        statusText = const Color(0xFF10b981);
                        statusBg = const Color(0xFF10b981).withValues(alpha: 0.12);
                      } else if (status == 'pending') {
                        statusText = const Color(0xFFf59e0b);
                        statusBg = const Color(0xFFf59e0b).withValues(alpha: 0.12);
                      } else {
                        statusText = const Color(0xFFef4444);
                        statusBg = const Color(0xFFef4444).withValues(alpha: 0.12);
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: primary.withValues(alpha: 0.08),
                            child: Icon(Icons.payment_rounded, color: primary, size: 18),
                          ),
                          title: Text(tx['member_name']?.toString() ?? 'Anonymous Member', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                          subtitle: Text(tx['description']?.toString() ?? 'Platform Fee', style: GoogleFonts.inter(fontSize: 11, color: subTextColor, fontWeight: FontWeight.w500)),
                          trailing: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('₵${(tx['amount'] ?? 0).toString()}', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, color: textColor)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(status.toUpperCase(), style: GoogleFonts.inter(color: statusText, fontWeight: FontWeight.bold, fontSize: 8)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _financialMetricBar(String label, double val, Color color) {
    final total = _filteredRevenue + _filteredPendingRevenue + _filteredFailedRevenue;
    final pct = total > 0 ? val / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748b))),
              Text('₵${val.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembershipTab(bool isDark, Color cardBg, Color borderColor, Color textColor, Color subTextColor, Color primary) {
    final typeColors = {
      'Corporate Agency': const Color(0xFF3b82f6),
      'Individual Broker': primary,
      'Freight Forwarder': const Color(0xFF10b981),
      'Shipping Line': const Color(0xFF8b5cf6),
    };

    final statusColors = {
      'active': const Color(0xFF10b981),
      'pending': const Color(0xFFf59e0b),
      'suspended': const Color(0xFFef4444),
      'inactive': const Color(0xFF64748b),
    };

    final filteredStatus = _filteredStatusCountsMap;
    final filteredTypes = _filteredTypeCountsMap;
    final filteredTotal = _filteredTotalMembersCount;
    final isMobile = MediaQuery.of(context).size.width < 900;

    final ratioContainer = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Member Status Ratios', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
          const SizedBox(height: 24),
          _CustomRingChart(
            data: filteredStatus,
            colors: statusColors,
          ),
        ],
      ),
    );

    final classContainer = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Broker Classifications', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
          const SizedBox(height: 16),
          ...filteredTypes.entries.map((e) {
            final color = typeColors[e.key] ?? const Color(0xFF64748b);
            final maxCount = filteredTotal > 0 ? filteredTotal.toDouble() : 10.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key, style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: textColor)),
                      Text('${e.value.toInt()}', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w900, color: textColor)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LinearProgressIndicator(
                      value: e.value / maxCount,
                      minHeight: 8,
                      backgroundColor: isDark ? const Color(0xFF13141a) : Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            );
          })
        ],
      ),
    );

    return SingleChildScrollView(
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [ratioContainer, const SizedBox(height: 12), classContainer],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: ratioContainer),
                const SizedBox(width: 12),
                Expanded(child: classContainer),
              ],
            ),
    );
  }

  Widget _buildOperationsTab(bool isDark, Color cardBg, Color borderColor, Color textColor, Color subTextColor, Color primary) {
    return SingleChildScrollView(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = MediaQuery.of(context).size.width < 900;
          final alertsCard = _activityMetricCard('Push Alerts Dispatched', '$_announcementsCount Alerts', Icons.campaign_rounded, primary, cardBg, borderColor, textColor);
          final ticketsCard = _activityMetricCard('Open Support Tickets', '$_openTickets Open', Icons.support_agent_rounded, const Color(0xFFef4444), cardBg, borderColor, textColor);
          final logsCard = _activityMetricCard('Logistics Vanning Logs', '$_cargoSchedulesCount Logs', Icons.local_shipping_rounded, const Color(0xFF3b82f6), cardBg, borderColor, textColor);

          if (isMobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [alertsCard, const SizedBox(height: 12), ticketsCard, const SizedBox(height: 12), logsCard],
            );
          }
          return Row(
            children: [
              Expanded(child: alertsCard),
              const SizedBox(width: 12),
              Expanded(child: ticketsCard),
              const SizedBox(width: 12),
              Expanded(child: logsCard),
            ],
          );
        },
      ),
    );
  }

  Widget _activityMetricCard(String title, String value, IconData icon, Color color, Color cardBg, Color borderColor, Color textColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(value, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: textColor)),
          const SizedBox(height: 4),
          Text(title, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white38 : const Color(0xFF94a3b8))),
        ],
      ),
    );
  }

  Widget _buildPortalManagementCard(Color cardBg, Color borderColor, Color textColor, Color subTextColor) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final List<Widget> items = [];

    if (auth.hasPermission('members')) {
      items.add(_MgmtTile(route: '/admin/license-renewal', icon: Icons.fact_check_rounded, color: const Color(0xFFf08232), label: 'Licenses', sub: 'Review renewals & expiries', cardBg: cardBg, borderColor: borderColor, textColor: textColor, subTextColor: subTextColor));
      items.add(_MgmtTile(route: '/admin/members', icon: Icons.group_rounded, color: const Color(0xFF3b82f6), label: 'Member Directory', sub: 'Manage all registered accounts', cardBg: cardBg, borderColor: borderColor, textColor: textColor, subTextColor: subTextColor));
      items.add(_MgmtTile(route: '/admin/tasks', icon: Icons.assignment_turned_in_rounded, color: const Color(0xFF10b981), label: 'Compliance & Tasks', sub: 'Assign and verify duties', cardBg: cardBg, borderColor: borderColor, textColor: textColor, subTextColor: subTextColor));
    }
    if (auth.hasPermission('announcements')) {
      items.add(_MgmtTile(route: '/admin/announcements', icon: Icons.campaign_rounded, color: const Color(0xFF8b5cf6), label: 'Broadcast Alerts', sub: 'Send push notifications', cardBg: cardBg, borderColor: borderColor, textColor: textColor, subTextColor: subTextColor));
    }
    if (auth.hasPermission('surveys')) {
      items.add(_MgmtTile(route: '/admin/surveys', icon: Icons.how_to_vote_rounded, color: const Color(0xFFec4899), label: 'Surveys & Elections', sub: 'Manage polls and elections', cardBg: cardBg, borderColor: borderColor, textColor: textColor, subTextColor: subTextColor));
    }
    if (auth.hasPermission('schedules')) {
      items.add(_MgmtTile(route: '/admin/cargo-schedules', icon: Icons.local_shipping_rounded, color: const Color(0xFFf59e0b), label: 'Logistics Master', sub: 'Update vanning schedules', cardBg: cardBg, borderColor: borderColor, textColor: textColor, subTextColor: subTextColor));
    }
    if (auth.hasPermission('payments')) {
      items.add(_MgmtTile(route: '/admin/payments', icon: Icons.account_balance_wallet_rounded, color: const Color(0xFF06b6d4), label: 'Revenue Control', sub: 'Audit and confirm payments', cardBg: cardBg, borderColor: borderColor, textColor: textColor, subTextColor: subTextColor));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Portal Management', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 16),
            ...items,
          ],
        ),
      ),
    );
  }

  Widget _buildRecentRegistrationsCard(Color primary, Color cardBg, Color borderColor, Color textColor, Color subTextColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Registrations', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                TextButton(
                  onPressed: () => context.go('/admin/members'),
                  child: Text('View All', style: GoogleFonts.outfit(color: primary, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Divider(color: borderColor, height: 1),
          if (_loading && _recentMembers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(color: primary)),
            )
          else if (_recentMembers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text('No recent registrations', style: GoogleFonts.inter(color: subTextColor, fontSize: 12))),
            )
          else
            ...(_recentMembers).take(4).map((m) {
              final status = (m['status']?.toString() ?? 'pending').toLowerCase();
              final name = m['name']?.toString() ?? 'Unknown';
              
              Color statusColor;
              Color statusBg;
              if (status == 'active') {
                statusColor = const Color(0xFF10b981);
                statusBg = const Color(0xFF10b981).withValues(alpha: 0.12);
              } else if (status == 'pending') {
                statusColor = const Color(0xFFf59e0b);
                statusBg = const Color(0xFFf59e0b).withValues(alpha: 0.12);
              } else {
                statusColor = const Color(0xFFef4444);
                statusBg = const Color(0xFFef4444).withValues(alpha: 0.12);
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: primary.withValues(alpha: 0.08),
                        child: Text(
                          _getInitials(name),
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: primary,
                          ),
                        ),
                      ),
                      title: Text(name, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: textColor)),
                      subtitle: Text(m['member_type']?.toString() ?? '', style: GoogleFonts.inter(fontSize: 11, color: subTextColor, fontWeight: FontWeight.w500)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                      ),
                    ),
                  ),
                  Divider(color: borderColor, height: 1),
                ],
              );
            }),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
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
                child: Icon(widget.icon, color: widget.color, size: 22),
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

class _MgmtTile extends StatefulWidget {
  final String route;
  final IconData icon;
  final Color color;
  final String label;
  final String sub;
  final Color cardBg;
  final Color borderColor;
  final Color textColor;
  final Color subTextColor;

  const _MgmtTile({
    required this.route,
    required this.icon,
    required this.color,
    required this.label,
    required this.sub,
    required this.cardBg,
    required this.borderColor,
    required this.textColor,
    required this.subTextColor,
  });

  @override
  State<_MgmtTile> createState() => _MgmtTileState();
}

class _MgmtTileState extends State<_MgmtTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => context.go(widget.route),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 8),
          transform: _isHovered ? Matrix4.translationValues(4.0, 0.0, 0.0) : Matrix4.identity(),
          decoration: BoxDecoration(
            color: widget.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered ? widget.color.withValues(alpha: 0.5) : widget.borderColor,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered 
                    ? widget.color.withValues(alpha: 0.08) 
                    : Colors.black.withValues(alpha: 0.01),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: _isHovered ? 6 : 4,
                  color: widget.color,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: widget.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(widget.icon, color: widget.color, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.label,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                  color: widget.textColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.sub,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: widget.subTextColor,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: _isHovered ? widget.color : const Color(0xFF94a3b8),
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                      ],
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

class _CustomBarChart extends StatefulWidget {
  final List<double> values;
  final List<String> labels;
  final double maxValue;
  final Color color;

  const _CustomBarChart({
    required this.values,
    required this.labels,
    required this.maxValue,
    this.color = const Color(0xFFf08232),
  });

  @override
  State<_CustomBarChart> createState() => _CustomBarChartState();
}

class _CustomBarChartState extends State<_CustomBarChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0f172a);
    final gridColor = isDark ? const Color(0xFF2d2e38) : const Color(0xFFf1f5f9);

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartHeight = constraints.maxHeight.isFinite ? constraints.maxHeight : 190.0;
        final actualChartH = chartHeight.clamp(100.0, 220.0);
        
        return SizedBox(
          height: actualChartH,
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    // Grid lines backdrop
                    Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(4, (index) {
                        return Container(
                          height: 1,
                          color: gridColor,
                          width: double.infinity,
                        );
                      }),
                    ),
                    // Bars
                    Positioned.fill(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(widget.values.length, (index) {
                          final val = widget.values[index];
                          final pct = widget.maxValue > 0 ? val / widget.maxValue : 0.0;
                          final label = widget.labels[index];
                          final isSelected = _selectedIndex == index;

                          return Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _selectedIndex = isSelected ? null : index),
                              borderRadius: BorderRadius.circular(8),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  AnimatedOpacity(
                                    opacity: isSelected ? 1.0 : 0.6,
                                    duration: const Duration(milliseconds: 150),
                                    child: Text(
                                      val >= 1000 ? '₵${(val / 1000).toStringAsFixed(1)}k' : '₵${val.toStringAsFixed(0)}',
                                      style: GoogleFonts.outfit(
                                        fontSize: isSelected ? 10 : 8,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                        color: isSelected ? widget.color : textColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Expanded(
                                    child: LayoutBuilder(
                                      builder: (ctx, bc) {
                                        final availH = bc.maxHeight.isFinite && bc.maxHeight > 0 ? bc.maxHeight : 80.0;
                                        final barH = (availH * pct.clamp(0.04, 1.0)).clamp(4.0, availH);
                                        return Align(
                                          alignment: Alignment.bottomCenter,
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            height: barH,
                                            margin: const EdgeInsets.symmetric(horizontal: 12),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.bottomCenter,
                                                end: Alignment.topCenter,
                                                colors: isSelected
                                                    ? [widget.color, const Color(0xFFf59e0b)]
                                                    : [widget.color.withValues(alpha: 0.6), widget.color.withValues(alpha: 0.9)],
                                              ),
                                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                              boxShadow: isSelected
                                                  ? [BoxShadow(color: widget.color.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, -2))]
                                                  : null,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    label,
                                    style: GoogleFonts.outfit(
                                      fontSize: 9,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected ? widget.color : (isDark ? Colors.white54 : const Color(0xFF64748b)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              if (_selectedIndex != null) ...[
                const SizedBox(height: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: widget.color.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    'Selected: ${widget.labels[_selectedIndex!]} - GH₵${widget.values[_selectedIndex!].toStringAsFixed(2)}',
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: widget.color),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CustomRingChart extends StatefulWidget {
  final Map<String, double> data;
  final Map<String, Color> colors;

  const _CustomRingChart({required this.data, required this.colors});

  @override
  State<_CustomRingChart> createState() => _CustomRingChartState();
}

class _CustomRingChartState extends State<_CustomRingChart> {
  String? _selectedKey;

  @override
  Widget build(BuildContext context) {
    final total = widget.data.values.fold(0.0, (sum, val) => sum + val);
    final activeKey = _selectedKey ?? (widget.data.keys.any((k) => widget.data[k]! > 0) ? widget.data.keys.firstWhere((k) => widget.data[k]! > 0) : widget.data.keys.first);
    final activeValue = widget.data[activeKey] ?? 0.0;
    final activePct = total > 0 ? (activeValue / total * 100).toStringAsFixed(1) : '0';
    final activeColor = widget.colors[activeKey] ?? Colors.grey;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0f172a);

    return Row(
      children: [
        SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _RingPainter(
                    data: widget.data,
                    colors: widget.colors,
                    total: total,
                    selectedKey: activeKey,
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      activeKey.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white38 : const Color(0xFF94a3b8),
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${activeValue.toInt()}',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: activeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$activePct%',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: activeColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: widget.data.entries.map((e) {
              final color = widget.colors[e.key] ?? Colors.grey;
              final isSelected = e.key == activeKey;
              final pct = total > 0 ? (e.value / total * 100).toStringAsFixed(1) : '0';
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3.0),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedKey = e.key;
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withValues(alpha: 0.08) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? color.withValues(alpha: 0.25) : Colors.transparent,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            e.key.toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? textColor : (isDark ? Colors.white60 : const Color(0xFF475569)),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF13141a) : const Color(0xFFf1f5f9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${e.value.toInt()} ($pct%)',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? textColor : (isDark ? Colors.white54 : const Color(0xFF64748b)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final Map<String, double> data;
  final Map<String, Color> colors;
  final double total;
  final String? selectedKey;

  _RingPainter({
    required this.data,
    required this.colors,
    required this.total,
    this.selectedKey,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidthNormal = 10.0;
    const strokeWidthSelected = 14.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (total == 0) {
      paint.color = Colors.grey.shade100;
      paint.strokeWidth = strokeWidthNormal;
      canvas.drawCircle(center, radius - strokeWidthSelected / 2, paint);
      return;
    }

    double startAngle = -3.14159 / 2;
    data.forEach((key, val) {
      if (val == 0) return;
      final sweepAngle = (val / total) * 3.14159 * 2;
      final isSelected = key == selectedKey;
      
      paint.color = isSelected ? (colors[key] ?? Colors.grey) : (colors[key] ?? Colors.grey).withValues(alpha: 0.4);
      paint.strokeWidth = isSelected ? strokeWidthSelected : strokeWidthNormal;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidthSelected / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    });
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.selectedKey != selectedKey || oldDelegate.total != total;
  }
}
