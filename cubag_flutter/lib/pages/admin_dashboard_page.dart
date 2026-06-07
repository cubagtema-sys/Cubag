import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import '../components/app_layout.dart';
import '../components/custom_dropdown.dart';
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

    // Fire off all requests in parallel for better performance
    final results = await Future.wait([
      api.get('/admin/dashboard'),
      api.get('/payments/admin/all').catchError((_) => Response(requestOptions: RequestOptions(), statusCode: 403, data: null)),
      api.get('/members/admin/all').catchError((_) => Response(requestOptions: RequestOptions(), statusCode: 403, data: null)),
    ]);

    final dRes = results[0];
    final fRes = results[1];
    final mRes = results[2];

    bool dashboardFailed = false;

    // ── 1. Handle Dashboard KPIs ──
    if (dRes.statusCode == 200) {
      final dData = dRes.data as Map<String, dynamic>;

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
        _statusCounts = sc.map((k, v) => MapEntry(k.toString(), (v ?? 0).toDouble()));
      }
      if (dData['type_counts'] != null) {
        final tc = Map<String, dynamic>.from(dData['type_counts']);
        _typeCounts = tc.map((k, v) => MapEntry(k.toString(), (v ?? 0).toDouble()));
      }
      if (dData['recent_members'] != null) {
        _recentMembers = dData['recent_members'] as List<dynamic>;
      }
    } else {
      dashboardFailed = true;
      _error = dRes.data != null && dRes.data is Map ? (dRes.data['message'] ?? dRes.data['error_details']) : 'Server error';
    }

    // ── 2. Handle Payments Supplement ──
    if (fRes.statusCode == 200 && fRes.data is Map) {
      final fData = fRes.data as Map<String, dynamic>;
      _transactions = ApiService.ensureList(fData['transactions']);
      final kpis = fData['kpis'] as Map<String, dynamic>? ?? {};
      if (kpis.isNotEmpty) {
        _revenue = double.tryParse(kpis['revenue']?.toString() ?? '') ?? _revenue;
        _pendingRevenue = double.tryParse(kpis['pending']?.toString() ?? '') ?? _pendingRevenue;
        _failedRevenue = double.tryParse(kpis['failed']?.toString() ?? '') ?? _failedRevenue;
      }
    }

    // ── 3. Handle Members Supplement ──
    if (mRes.statusCode == 200) {
      _rawMembers = ApiService.ensureList(mRes.data);
      final members = _rawMembers;
      final Map<String, double> sc = {'active': 0, 'pending': 0, 'suspended': 0, 'inactive': 0};
      final Map<String, double> tc = {'Corporate Agency': 0, 'Individual Broker': 0, 'Freight Forwarder': 0, 'Shipping Line': 0};
      for (var m in members) {
        final status = (m['status'] ?? '').toString().toLowerCase();
        if (sc.containsKey(status)) sc[status] = sc[status]! + 1;
        final type = (m['member_type'] ?? '').toString();
        if (type.isNotEmpty) {
           if (tc.containsKey(type)) tc[type] = tc[type]! + 1;
           else tc[type] = (tc[type] ?? 0) + 1;
        }
      }
      _statusCounts = sc;
      _typeCounts = tc;
    }

    if (mounted) {
      setState(() {
        _loading = false;
        if (dashboardFailed && _error == null) {
          _error = 'Dashboard could not load critical data.';
        }
      });
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

    return AppLayout(
      title: 'Admin Dashboard',
      hideSearch: false,
      scrollable: true,
      child: _loading
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(48.0),
                child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error != null) _buildErrorBanner(),
                _buildHeaderBar(),
                const SizedBox(height: 16),
                _buildKPIGrid(isDesktop),
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
                            _buildAnalyticsSection(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            _buildPortalManagementCard(),
                            const SizedBox(height: 16),
                            _buildRecentRegistrationsCard(primary),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildAnalyticsSection(),
                      const SizedBox(height: 16),
                      _buildPortalManagementCard(),
                      const SizedBox(height: 16),
                      _buildRecentRegistrationsCard(primary),
                    ],
                  ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x19ef4444),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x33ef4444)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFef4444)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: Color(0xFFef4444), fontSize: 13, fontWeight: FontWeight.w600),
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

  Widget _buildHeaderBar() {
    final isSmall = MediaQuery.of(context).size.width < 360;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Overview Insights',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0f172a),
              ),
            ),
            if (!isSmall) _buildActionButtons(),
          ],
        ),
        if (isSmall) ...[
          const SizedBox(height: 12),
          _buildActionButtons(),
        ],
      ],
    );
  }

  Widget _buildActionButtons() {
    final isSmall = MediaQuery.of(context).size.width < 360;
    return Row(
      mainAxisAlignment: isSmall ? MainAxisAlignment.spaceBetween : MainAxisAlignment.end,
      children: [
        ElevatedButton.icon(
          onPressed: _showExportDialog,
          icon: const Icon(Icons.download, size: 14),
          label: const Text('Export Data', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Theme.of(context).primaryColor,
            elevation: 0,
            minimumSize: const Size(0, 52),
            side: BorderSide(color: Theme.of(context).primaryColor),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
        ),
        const SizedBox(width: 8),
        CustomDropdown<String>(
          value: _dateFilter,
          width: isSmall ? 130 : 140,
          dense: true,
          items: const [
            DropdownItem(value: 'All Time', label: 'All Time'),
            DropdownItem(value: 'Last 7 Days', label: '7 Days'),
            DropdownItem(value: 'Last 30 Days', label: '30 Days'),
            DropdownItem(value: 'Year to Date', label: 'YTD'),
          ],
          onChanged: (newValue) {
            setState(() {
              _dateFilter = newValue!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildKPIGrid(bool isDesktop) {
    final primary = Theme.of(context).primaryColor;
    final size = MediaQuery.of(context).size;
    final isSmall = size.width < 360;
    final auth = Provider.of<AuthService>(context, listen: false);
    
    final revenue = _filteredRevenue;
    final revenueLabel = revenue >= 1000 ? '₵${(revenue / 1000).toStringAsFixed(1)}k' : '₵${revenue.toStringAsFixed(0)}';

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isDesktop ? 4 : 2,
      mainAxisSpacing: isSmall ? 8 : 12,
      crossAxisSpacing: isSmall ? 8 : 12,
      childAspectRatio: isDesktop ? 1.4 : (isSmall ? 1.1 : 1.3),
      children: [
        if (auth.hasPermission('members'))
          _kpiCard(Icons.group, primary, 'Total Users', '$_filteredTotalMembersCount'),
        if (auth.hasPermission('members'))
          _kpiCard(Icons.verified_user, const Color(0xFF10b981), 'Active Licenses', '${_stats['active_members'] ?? 0}'),
        if (auth.hasPermission('tickets'))
          _kpiCard(Icons.support_agent, const Color(0xFFf59e0b), 'Open Tickets', '${_stats['open_tickets'] ?? 0}'),
        if (auth.hasPermission('payments'))
          _kpiCard(Icons.payments, const Color(0xFF3b82f6), 'Revenue Collected', revenueLabel),
      ],
    );
  }

  Widget _kpiCard(IconData icon, Color color, String label, String value) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color.withValues(alpha: 0.15))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 18)),
          const SizedBox(height: 8),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0f172a)))),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, child: Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
        ]),
      ),
    );
  }

  Widget _buildAnalyticsSection() {
    final auth = Provider.of<AuthService>(context, listen: false);
    final List<Widget> tabs = [];
    final List<Widget> children = [];

    if (auth.hasPermission('payments')) {
      tabs.add(const Tab(text: 'Financial Center'));
      children.add(_buildFinancialTab());
    }
    if (auth.hasPermission('members')) {
      tabs.add(const Tab(text: 'Membership Insights'));
      children.add(_buildMembershipTab());
    }
    if (auth.hasPermission('tickets') || auth.hasPermission('schedules') || auth.hasPermission('announcements')) {
      tabs.add(const Tab(text: 'Operations & Alerts'));
      children.add(_buildOperationsTab());
    }

    if (tabs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab Bar
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFe2e8f0))),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: const Color(0xFF64748b),
            indicatorColor: Theme.of(context).primaryColor,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
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

  Widget _buildFinancialTab() {
    final filteredMonthly = _filteredMonthlyRevenueMap;
    final sortedMonths = filteredMonthly.keys.toList()..sort();
    final values = sortedMonths.map((m) => filteredMonthly[m] ?? 0.0).toList();

    final maxVal = values.isNotEmpty ? values.reduce((curr, next) => curr > next ? curr : next) : 1000.0;
    final filteredTx = _filteredTransactionsList;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFe2e8f0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Revenue Collection Trend (GH₵)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 12),
                      sortedMonths.isEmpty
                          ? const SizedBox(
                              height: 190,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.bar_chart, size: 40, color: Colors.grey),
                                    SizedBox(height: 8),
                                    Text('No revenue data available', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                  ],
                                ),
                              ),
                            )
                          : _CustomBarChart(
                              values: values,
                              labels: sortedMonths,
                              maxValue: maxVal,
                              color: Theme.of(context).primaryColor,
                            ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFe2e8f0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Dues Distribution', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 16),
                      _financialMetricBar('Paid Revenue', _filteredRevenue, const Color(0xFF10b981)),
                      _financialMetricBar('Pending Receivables', _filteredPendingRevenue, const Color(0xFFf59e0b)),
                      _financialMetricBar('Failed/Overdue Dues', _filteredFailedRevenue, const Color(0xFFef4444)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFe2e8f0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Recent Payment Ledger', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 12),
                if (filteredTx.isEmpty)
                  const Center(child: Text('No transaction logs found for this period', style: TextStyle(color: Colors.grey, fontSize: 13)))
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredTx.length > 5 ? 5 : filteredTx.length,
                    separatorBuilder: (c, i) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final tx = filteredTx[index];
                      final status = tx['status']?.toString() ?? 'pending';
                      final statusColor = status == 'paid' ? const Color(0xFF10b981) : const Color(0xFFf59e0b);

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(tx['member_name']?.toString() ?? 'Anonymous Member', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(tx['description']?.toString() ?? 'Platform Fee', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        trailing: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('₵${(tx['amount'] ?? 0).toString()}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                            const SizedBox(height: 2),
                            Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 9)),
                          ],
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
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748b))),
              Text('₵${val.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
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

  Widget _buildMembershipTab() {
    final typeColors = {
      'Corporate Agency': const Color(0xFF3b82f6),
      'Individual Broker': Theme.of(context).primaryColor,
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

    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFe2e8f0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Member Status Ratios', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 24),
                  _CustomRingChart(
                    data: filteredStatus,
                    colors: statusColors,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFe2e8f0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Broker Classifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                              Text(e.key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                              Text('${e.value.toInt()}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: LinearProgressIndicator(
                              value: e.value / maxCount,
                              minHeight: 8,
                              backgroundColor: Colors.grey.shade100,
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
                          ),
                        ],
                      ),
                    );
                  })
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationsTab() {
    return SingleChildScrollView(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              Expanded(
                child: _activityMetricCard('Push Alerts Dispatched', '$_announcementsCount Alerts', Icons.campaign, Theme.of(context).primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _activityMetricCard('Open Support Tickets', '$_openTickets Open', Icons.support_agent, const Color(0xFFef4444)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _activityMetricCard('Logistics Vanning Logs', '$_cargoSchedulesCount Logs', Icons.local_shipping, const Color(0xFF3b82f6)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _activityMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFe2e8f0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 14),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0f172a))),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94a3b8))),
        ],
      ),
    );
  }



  Widget _buildPortalManagementCard() {
    final auth = Provider.of<AuthService>(context, listen: false);
    final List<Widget> items = [];

    if (auth.hasPermission('members')) {
      items.add(_mgmtTile(context, '/admin/license-renewal', Icons.fact_check, const Color(0xFFf08232), 'Licenses', 'Review renewals & expiries'));
      items.add(_mgmtTile(context, '/admin/members', Icons.group, const Color(0xFFf08232), 'Member Directory', 'Manage all registered accounts'));
      items.add(_mgmtTile(context, '/admin/tasks', Icons.assignment_add, const Color(0xFFf08232), 'Compliance & Tasks', 'Assign and verify duties'));
    }
    if (auth.hasPermission('announcements')) {
      items.add(_mgmtTile(context, '/admin/announcements', Icons.campaign, const Color(0xFFf08232), 'Broadcast Alerts', 'Send push notifications'));
    }
    if (auth.hasPermission('surveys')) {
      items.add(_mgmtTile(context, '/admin/surveys', Icons.how_to_vote, const Color(0xFFf08232), 'Surveys & Elections', 'Manage polls and elections'));
    }
    if (auth.hasPermission('schedules')) {
      items.add(_mgmtTile(context, '/admin/cargo-schedules', Icons.local_shipping, const Color(0xFFf08232), 'Logistics Master', 'Update vanning schedules'));
    }
    if (auth.hasPermission('payments')) {
      items.add(_mgmtTile(context, '/admin/payments', Icons.account_balance_wallet, const Color(0xFFf08232), 'Revenue Control', 'Audit and confirm payments'));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withAlpha(20))),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Portal Management', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0f172a))),
            const SizedBox(height: 12),
            ...items,
          ],
        ),
      ),
    );
  }

  Widget _mgmtTile(BuildContext context, String route, IconData icon, Color color, String label, String sub) {
    return GestureDetector(
      onTap: () => context.go(route),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFe2e8f0)),
          boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 2, offset: Offset(0, 1))],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(children: [
            Container(
              width: 4,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0f172a))),
                    const SizedBox(height: 1),
                    Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xFF64748b)), overflow: TextOverflow.ellipsis),
                  ])),
                  const Icon(Icons.chevron_right, color: Color(0xFF94a3b8), size: 16),
                  const SizedBox(width: 12),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildRecentRegistrationsCard(Color primary) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withAlpha(20))),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Recent Registrations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            TextButton(onPressed: () => context.go('/admin/members'), child: Text('View All', style: TextStyle(color: primary, fontSize: 12))),
          ]),
        ),
        const Divider(height: 1),
        if (_loading && _recentMembers.isEmpty)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: Colors.orange)))
        else if (_recentMembers.isEmpty)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No recent registrations', style: TextStyle(color: Colors.grey, fontSize: 12))))
        else
          ...(_recentMembers).take(4).map((m) {
            final status = m['status']?.toString() ?? '';
            Color statusColor = status == 'active' ? const Color(0xFF10b981) : status == 'pending' ? const Color(0xFFf59e0b) : const Color(0xFFef4444);
            return Column(children: [
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                title: Text(m['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: Text(m['member_type']?.toString() ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Text(status.toUpperCase(), style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: statusColor))),
              ),
              const Divider(height: 1),
            ]);
          }),
      ]),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final chartHeight = constraints.maxHeight.isFinite ? constraints.maxHeight : 190.0;
        return SizedBox(
          height: chartHeight.clamp(100.0, 220.0),
          child: Column(
            children: [
              Expanded(
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
                        borderRadius: BorderRadius.circular(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              val >= 1000 ? '₵${(val / 1000).toStringAsFixed(1)}k' : '₵${val.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: isSelected ? 10 : 8,
                                fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                                color: isSelected ? widget.color : const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (ctx, bc) {
                                  // Guard against zero height from layout constraints
                                  final availH = bc.maxHeight.isFinite && bc.maxHeight > 0 ? bc.maxHeight : 80.0;
                                  final barH = (availH * pct.clamp(0.04, 1.0)).clamp(2.0, availH);
                                  return Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Container(
                                      height: barH,
                                      margin: const EdgeInsets.symmetric(horizontal: 10),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: isSelected
                                              ? [widget.color, widget.color]
                                              : [widget.color.withValues(alpha: 0.4), widget.color.withValues(alpha: 0.8)],
                                        ),
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                        border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                                        boxShadow: isSelected
                                            ? [BoxShadow(color: widget.color.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, -2))]
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
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                                  color: isSelected ? widget.color : const Color(0xFF64748b)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
              if (_selectedIndex != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Selected: ${widget.labels[_selectedIndex!]} - ₵${widget.values[_selectedIndex!].toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: widget.color),
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

    return Row(
      children: [
        SizedBox(
          width: 100,
          height: 100,
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
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade500,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${activeValue.toInt()}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0f172a),
                      ),
                    ),
                    Text(
                      '$activePct%',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: activeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: widget.data.entries.map((e) {
              final color = widget.colors[e.key] ?? Colors.grey;
              final isSelected = e.key == activeKey;
              final pct = total > 0 ? (e.value / total * 100).toStringAsFixed(1) : '0';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedKey = e.key;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withValues(alpha: 0.08) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? color.withValues(alpha: 0.3) : Colors.transparent,
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
                            '${e.key.toUpperCase()}: ${e.value.toInt()} ($pct%)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                              color: isSelected ? const Color(0xFF0f172a) : const Color(0xFF475569),
                            ),
                            overflow: TextOverflow.ellipsis,
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
