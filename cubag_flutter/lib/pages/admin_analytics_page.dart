import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/app_layout.dart';
import '../components/custom_dropdown.dart';
import '../services/api_service.dart';

class AdminAnalyticsPage extends StatefulWidget {
  const AdminAnalyticsPage({super.key});

  @override
  State<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsPageState extends State<AdminAnalyticsPage> with SingleTickerProviderStateMixin {
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
  final Map<String, double> _monthlyRevenue = {};

  // Membership Stats
  int _totalMembers = 0;
  Map<String, double> _statusCounts = {'active': 0, 'pending': 0, 'suspended': 0, 'inactive': 0};
  Map<String, double> _typeCounts = {'Corporate Agency': 0, 'Individual Broker': 0, 'Freight Forwarder': 0, 'Shipping Line': 0};

  // Operational Stats
  int _openTickets = 0;
  int _announcementsCount = 0;
  int _cargoSchedulesCount = 0;

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
    if (_transactions.isEmpty && _dateFilter == 'All Time') return _revenue;
    return _transactions
        .where((tx) => tx['status']?.toString().toLowerCase() == 'paid' && _isWithinDateRange(tx['date']?.toString() ?? tx['created_at']?.toString()))
        .fold(0.0, (sum, tx) => sum + (double.tryParse(tx['amount']?.toString() ?? '0') ?? 0.0));
  }

  double get _filteredPendingRevenue {
    if (_transactions.isEmpty && _dateFilter == 'All Time') return _pendingRevenue;
    return _transactions
        .where((tx) => tx['status']?.toString().toLowerCase() == 'pending' && _isWithinDateRange(tx['date']?.toString() ?? tx['created_at']?.toString()))
        .fold(0.0, (sum, tx) => sum + (double.tryParse(tx['amount']?.toString() ?? '0') ?? 0.0));
  }

  double get _filteredFailedRevenue {
    if (_transactions.isEmpty && _dateFilter == 'All Time') return _failedRevenue;
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
    if (_rawMembers.isEmpty) return _totalMembers;
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
                  decoration: BoxDecoration(color: Colors.grey.shade50, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.download, color: Color(0xFFf08232)),
            SizedBox(width: 10),
            Text('Export Report Data'),
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
              backgroundColor: const Color(0xFFf08232),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
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
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

    try {
      // Fetch Dashboard Stats
      final dashboardRes = await ApiService().get('/admin/dashboard');
      if (dashboardRes.statusCode == 200) {
        final dData = dashboardRes.data as Map<String, dynamic>;
        final kpis = dData['kpis'] as Map<String, dynamic>? ?? {};
        _totalMembers = kpis['total_members'] ?? 0;
        _openTickets = kpis['open_tickets'] ?? 0;
      }

      // Fetch Financial Stats
      final financialRes = await ApiService().get('/payments/admin/all');
      if (financialRes.statusCode == 200) {
        final fData = financialRes.data as Map<String, dynamic>;
        final kpis = fData['kpis'] as Map<String, dynamic>? ?? {};
        _revenue = (kpis['revenue'] ?? 0.0).toDouble();
        _pendingRevenue = (kpis['pending'] ?? 0.0).toDouble();
        _failedRevenue = (kpis['failed'] ?? 0.0).toDouble();
        _transactions = fData['transactions'] as List<dynamic>? ?? [];

        // Calculate Monthly Revenue from transaction dates
        _monthlyRevenue.clear();
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        for (var tx in _transactions) {
          if (tx['status'] == 'paid' && tx['date'] != null) {
            try {
              final date = DateTime.parse(tx['date'].toString());
              final monthLabel = '${months[date.month - 1]} ${date.year.toString().substring(2)}';
              final amt = (tx['amount'] ?? 0.0).toDouble();
              _monthlyRevenue[monthLabel] = (_monthlyRevenue[monthLabel] ?? 0.0) + amt;
            } catch (_) {}
          }
        }
      }

      // Fetch Members Stats
      final membersRes = await ApiService().get('/members/admin/all');
      if (membersRes.statusCode == 200) {
        final List<dynamic> members = membersRes.data ?? [];
        _rawMembers = members;
        
        // Reset counts
        _statusCounts = {'active': 0, 'pending': 0, 'suspended': 0, 'inactive': 0};
        _typeCounts = {'Corporate Agency': 0, 'Individual Broker': 0, 'Freight Forwarder': 0, 'Shipping Line': 0};

        for (var m in members) {
          final status = (m['status'] ?? '').toString().toLowerCase();
          if (_statusCounts.containsKey(status)) {
            _statusCounts[status] = _statusCounts[status]! + 1;
          }

          final type = (m['member_type'] ?? '').toString();
          if (type.isNotEmpty) {
            if (_typeCounts.containsKey(type)) {
              _typeCounts[type] = _typeCounts[type]! + 1;
            } else {
              _typeCounts[type] = (_typeCounts[type] ?? 0) + 1;
            }
          }
        }
      }

      // Fetch cargo schedules (for Operations Tab)
      final cargoRes = await ApiService().get('/schedules');
      if (cargoRes.statusCode == 200) {
        final List<dynamic> cargo = cargoRes.data ?? [];
        _cargoSchedulesCount = cargo.length;
      }

      // Fetch announcements (for Operations Tab)
      final announcementsRes = await ApiService().get('/announcements');
      if (announcementsRes.statusCode == 200) {
        final List<dynamic> ann = announcementsRes.data ?? [];
        _announcementsCount = ann.length;
      }

    } catch (e) {
      _error = 'Failed to fetch some analytics data. Visualizing available records.';
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      title: 'Platform Analytics',
      hideSearch: false,
      scrollable: true,
      child: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(48.0),
                child: CircularProgressIndicator(color: Color(0xFFf08232)),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error != null)
                  Container(
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
                  ),

                // Date filter and Export action bar
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
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _showExportDialog,
                          icon: const Icon(Icons.download, size: 14),
                          label: const Text('Export Data', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFFf08232),
                            elevation: 0,
                            side: const BorderSide(color: Color(0xFFf08232)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CustomDropdown<String>(
                          value: _dateFilter,
                          width: 140,
                          dense: true,
                          items: const [
                            DropdownItem(value: 'All Time', label: 'All Time'),
                            DropdownItem(value: 'Last 7 Days', label: 'Last 7 Days'),
                            DropdownItem(value: 'Last 30 Days', label: 'Last 30 Days'),
                            DropdownItem(value: 'Year to Date', label: 'Year to Date'),
                          ],
                          onChanged: (newValue) {
                            setState(() {
                              _dateFilter = newValue;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Top Stats Summary Grid
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: MediaQuery.of(context).size.width < 600 ? 2 : 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.6,
                  children: [
                    _summaryCard('TOTAL REVENUE', '₵${_filteredRevenue.toStringAsFixed(0)}', Icons.payments, const Color(0xFF10b981)),
                    _summaryCard('TOTAL MEMBERS', '$_filteredTotalMembersCount', Icons.group, const Color(0xFF3b82f6)),
                    _summaryCard('CARGO LOGS', '$_cargoSchedulesCount', Icons.local_shipping, const Color(0xFFf08232)),
                    _summaryCard('OPEN TICKETS', '$_openTickets', Icons.confirmation_number, const Color(0xFFef4444)),
                  ],
                ),
                const SizedBox(height: 20),

                // Tab Bar
                Container(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFe2e8f0))),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFFf08232),
                    unselectedLabelColor: const Color(0xFF64748b),
                    indicatorColor: const Color(0xFFf08232),
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    tabs: const [
                      Tab(text: 'Financial Center'),
                      Tab(text: 'Membership Insights'),
                      Tab(text: 'Operations & Alerts'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Tab Body
                SizedBox(
                  height: 520,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildFinancialTab(),
                      _buildMembershipTab(),
                      _buildOperationsTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFe2e8f0)),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748b), letterSpacing: 0.5)),
              Icon(icon, color: color.withValues(alpha: 0.7), size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0f172a))),
        ],
      ),
    );
  }

  Widget _buildFinancialTab() {
    // Generate monthly revenue list
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
                    borderRadius: BorderRadius.circular(16),
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
                              color: const Color(0xFFf08232),
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
                    borderRadius: BorderRadius.circular(16),
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
          // Recent Transactions Breakdown
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
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
            borderRadius: BorderRadius.circular(10),
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
      'Individual Broker': const Color(0xFFf08232),
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
                borderRadius: BorderRadius.circular(16),
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
                borderRadius: BorderRadius.circular(16),
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
                            borderRadius: BorderRadius.circular(10),
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
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _activityMetricCard('Push Alerts Dispatched', '$_announcementsCount Alerts', Icons.campaign, const Color(0xFFf08232)),
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
          ),
        ],
      ),
    );
  }

  Widget _activityMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
    return Container(
      height: 190,
      padding: const EdgeInsets.symmetric(vertical: 8),
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
                    onTap: () {
                      setState(() {
                        _selectedIndex = isSelected ? null : index;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
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
                        const SizedBox(height: 6),
                        Expanded(
                          child: FractionallySizedBox(
                            heightFactor: pct.clamp(0.04, 1.0),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: isSelected
                                      ? [widget.color, widget.color]
                                      : [widget.color.withValues(alpha: 0.4), widget.color.withValues(alpha: 0.8)],
                                ),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                border: isSelected
                                    ? Border.all(color: Colors.white, width: 2)
                                    : null,
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: widget.color.withValues(alpha: 0.4),
                                          blurRadius: 6,
                                          offset: const Offset(0, -2),
                                        )
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                            color: isSelected ? widget.color : const Color(0xFF64748b),
                          ),
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
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Selected: ${widget.labels[_selectedIndex!]} - ₵${widget.values[_selectedIndex!].toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: widget.color,
                ),
              ),
            ),
          ],
        ],
      ),
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
    
    // Select first non-zero key by default if none selected
    final activeKey = _selectedKey ?? widget.data.keys.firstWhere((k) => widget.data[k]! > 0, orElse: () => widget.data.keys.first);
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
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withValues(alpha: 0.08) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
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
