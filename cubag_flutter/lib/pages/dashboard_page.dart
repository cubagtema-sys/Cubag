import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:google_fonts/google_fonts.dart';
import '../components/app_layout.dart';
import '../components/skeleton_loader.dart';
import '../services/api_service.dart';

const _kOrange = Color(0xFFf08232);

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _loading = true;
  List<dynamic> _tasks = [];
  List<dynamic> _announcements = [];
  Map<String, String> _forex = {'USD': '...', 'EUR': '...'};
  Map<String, dynamic> _user = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (_tasks.isEmpty) setState(() => _loading = true);

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _user = {
        'name': prefs.getString('cubag_name') ?? 'Member',
        'role': prefs.getString('cubag_role') ?? ''
      };
    });

    try {
      await Future.wait([
        _fetchTasks(),
        _fetchAnnouncements(),
        _fetchForex(),
      ]);
    } catch (e) {
      debugPrint('Dashboard data load error: $e');
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchTasks() async {
    await ApiService().fetchDataWithCache('/tasks', (data, isCached, {bool hasError = false}) {
      if (mounted && data != null) {
        setState(() => _tasks = ApiService.ensureList(data));
      }
    });
  }

  Future<void> _fetchAnnouncements() async {
    await ApiService().fetchDataWithCache('/announcements', (data, isCached, {bool hasError = false}) {
      if (mounted && data != null) {
        setState(() => _announcements = ApiService.ensureList(data).take(3).toList());
      }
    });
  }

  Future<void> _fetchForex() async {
    try {
      final dio = Dio();
      final res = await dio.get('https://open.er-api.com/v6/latest/GHS');
      if (res.statusCode == 200 && mounted) {
        final rates = res.data['rates'] as Map<String, dynamic>;
        setState(() {
          _forex = {
            'USD': (1 / (rates['USD'] ?? 1.0)).toStringAsFixed(2),
            'EUR': (1 / (rates['EUR'] ?? 1.0)).toStringAsFixed(2),
          };
        });
      }
    } catch (_) {}
  }

  Widget _forexBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(50)),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner(String firstName, String role, List<dynamic> pending, Color primary, bool isMobile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _kOrange,
            Color(0xFFea580c),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _kOrange.withAlpha(50),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withAlpha(80), width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  firstName.isNotEmpty ? firstName[0].toUpperCase() : 'M',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good day, $firstName!',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (role.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          role.toUpperCase(),
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'You have ${pending.length} pending item${pending.length != 1 ? 's' : ''} that require your attention.',
            style: GoogleFonts.outfit(
              color: Colors.white.withAlpha(220),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                onPressed: () => context.go('/payments'),
                icon: const Icon(Icons.autorenew_rounded, size: 16),
                label: const Text('Renew License'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFea580c),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              if (!isMobile)
                Row(
                  children: [
                    _forexBadge('USD: ${_forex['USD']}'),
                    const SizedBox(width: 8),
                    _forexBadge('EUR: ${_forex['EUR']}'),
                  ],
                ),
            ],
          ),
          if (isMobile) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _forexBadge('USD: ${_forex['USD']}'),
                const SizedBox(width: 8),
                _forexBadge('EUR: ${_forex['EUR']}'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriorityTasksSection(List<dynamic> pending, Color primary) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFe2e8f0), width: 1.5),
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
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _kOrange.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.task_alt_rounded, color: _kOrange, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  'Priority Tasks',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: const Color(0xFF0f172a),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFf1f5f9)),
          if (pending.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFf8fafc),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_outline_rounded, size: 36, color: Color(0xFFcbd5e1)),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No pending tasks!',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'You are completely up to date.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pending.length,
              separatorBuilder: (context, i) => const Divider(height: 1, color: Color(0xFFf1f5f9)),
              itemBuilder: (context, i) {
                final task = pending[i];
                bool overdue = task['due_date'] != null &&
                    DateTime.tryParse(task['due_date'].toString())?.isBefore(DateTime.now()) == true;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: overdue ? Colors.red.shade50 : const Color(0xFFf1f5f9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.description_outlined,
                      color: overdue ? Colors.red.shade600 : const Color(0xFF475569),
                      size: 18,
                    ),
                  ),
                  title: Text(
                    task['title'] ?? '',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: const Color(0xFF0f172a),
                    ),
                  ),
                  subtitle: Text(
                    overdue
                        ? '⚠ Overdue: ${task['due_date']}'
                        : 'Due: ${task['due_date'] ?? 'No deadline'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: overdue ? Colors.red.shade600 : const Color(0xFF64748b),
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: overdue ? Colors.red.shade50 : _kOrange.withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: overdue ? Colors.red.shade100 : _kOrange.withAlpha(40),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'REQUIRED',
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        color: overdue ? Colors.red.shade600 : _kOrange,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                );
              },
            ),
            const Divider(height: 1, color: Color(0xFFf1f5f9)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: TextButton.icon(
                  onPressed: () => context.go('/tasks'),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('View All Tasks'),
                  style: TextButton.styleFrom(
                    foregroundColor: _kOrange,
                    textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnnouncementsSection(Color primary) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFe2e8f0), width: 1.5),
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
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8b5cf6).withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.campaign_outlined, color: Color(0xFF8b5cf6), size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  'Latest Announcements',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: const Color(0xFF0f172a),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFf1f5f9)),
          if (_announcements.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Text(
                  'No new announcements.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            )
          else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _announcements.length,
              separatorBuilder: (context, i) => const Divider(height: 1, color: Color(0xFFf1f5f9)),
              itemBuilder: (context, i) {
                final a = _announcements[i];
                final category = (a['category'] ?? a['type'] ?? 'General').toString().toUpperCase();
                
                Color catBg = const Color(0xFFf1f5f9);
                Color catFg = const Color(0xFF475569);
                if (category == 'OPERATIONS' || category == 'PORT') {
                  catBg = const Color(0xFFe0f2fe);
                  catFg = const Color(0xFF0369a1);
                } else if (category == 'BILLING' || category == 'FINANCE') {
                  catBg = const Color(0xFFdcfce7);
                  catFg = const Color(0xFF15803d);
                } else if (category == 'REGULATORY' || category == 'LEGAL') {
                  catBg = const Color(0xFFf3e8ff);
                  catFg = const Color(0xFF7e22ce);
                } else if (category == 'GENERAL') {
                  catBg = const Color(0xFFfef3c7);
                  catFg = const Color(0xFFb45309);
                }

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: catBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: catFg,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text(
                        a['title'] ?? '',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: const Color(0xFF0f172a),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        a['content'] ?? a['body'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF475569),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(height: 1, color: Color(0xFFf1f5f9)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: TextButton.icon(
                  onPressed: () => context.go('/announcements'),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('View All Announcements'),
                  style: TextButton.styleFrom(
                    foregroundColor: _kOrange,
                    textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildForexSection(ThemeData theme, Color primary) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFe2e8f0), width: 1.5),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10b981).withAlpha(15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.trending_up_rounded, color: Color(0xFF10b981), size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Live Forex',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: const Color(0xFF0f172a),
                ),
              ),
              const Spacer(),
              const BlinkingDot(),
              const SizedBox(width: 6),
              Text(
                'LIVE',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  color: const Color(0xFF64748b),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _forexRow('\$', 'USD/GHS', _forex['USD']!, const Color(0xFF0f172a), 'US Dollar'),
          const SizedBox(height: 12),
          _forexRow('€', 'EUR/GHS', _forex['EUR']!, const Color(0xFF2563eb), 'Euro'),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => context.go('/live-data'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              side: const BorderSide(color: Color(0xFFcbd5e1), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: GoogleFonts.outfit(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              foregroundColor: const Color(0xFF475569),
            ),
            child: const Text('View Full Data Hub'),
          )
        ],
      ),
    );
  }

  Widget _forexRow(String symbol, String pair, String rate, Color color, String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFf8fafc),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFf1f5f9), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              symbol,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pair,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: const Color(0xFF0f172a),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94a3b8),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            rate,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid(bool isMobile) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      padding: EdgeInsets.zero,
      children: [
        _quickAction(
          context,
          Icons.payments_outlined,
          'Pay Dues',
          '/payments',
          color: const Color(0xFFf08232),
          subtext: 'Renew your license',
        ),
        _quickAction(
          context,
          Icons.receipt_long_outlined,
          'Statement',
          '/payments',
          color: const Color(0xFFef4444),
          subtext: 'View transactions',
        ),
        _quickAction(
          context,
          Icons.bar_chart_rounded,
          'Live Data',
          '/live-data',
          color: const Color(0xFF10b981),
          subtext: 'Platform stats',
        ),
        _quickAction(
          context,
          Icons.support_agent_rounded,
          'Support Hub',
          '/engagement',
          color: const Color(0xFF8b5cf6),
          subtext: 'Create a ticket',
        ),
      ],
    );
  }

  Widget _quickAction(BuildContext context, IconData icon, String label, String route, {required Color color, String? subtext}) {
    return InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withAlpha(12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(40), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const Spacer(),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0f172a),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtext != null) ...[
              const SizedBox(height: 2),
              Text(
                subtext,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF64748b),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ]
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;
    final firstName = (_user['name'] as String? ?? 'Member').split(' ').first;
    final role = _user['role'] as String? ?? '';
    final pending = _tasks.where((t) => t['done'] != true).toList();

    return AppLayout(
      title: 'Dashboard',
      scrollable: false,
      child: _loading && _tasks.isEmpty
          ? const DashboardSkeleton()
          : RefreshIndicator(
              onRefresh: _loadData,
              color: _kOrange,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 950;
                          
                          if (isWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildWelcomeBanner(firstName, role, pending, primary, false),
                                      const SizedBox(height: 20),
                                      _buildPriorityTasksSection(pending, primary),
                                      const SizedBox(height: 20),
                                      _buildAnnouncementsSection(primary),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildForexSection(theme, primary),
                                      const SizedBox(height: 20),
                                      Text(
                                        'QUICK ACTIONS',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                          color: const Color(0xFF64748b),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      _buildQuickActionsGrid(false),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          } else {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildWelcomeBanner(firstName, role, pending, primary, true),
                                const SizedBox(height: 20),
                                Text(
                                  'QUICK ACTIONS',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: const Color(0xFF64748b),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _buildQuickActionsGrid(true),
                                const SizedBox(height: 20),
                                _buildPriorityTasksSection(pending, primary),
                                const SizedBox(height: 20),
                                _buildForexSection(theme, primary),
                                const SizedBox(height: 20),
                                _buildAnnouncementsSection(primary),
                              ],
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class BlinkingDot extends StatefulWidget {
  const BlinkingDot({super.key});

  @override
  State<BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<BlinkingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Color(0xFF10b981),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
