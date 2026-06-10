import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../components/app_layout.dart';
import '../components/skeleton_loader.dart';
import '../services/api_service.dart';

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
    // If we already have data, don't show the full skeleton loader
    if (_tasks.isEmpty) setState(() => _loading = true);

    // 1. Get user data from local storage (Instant)
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _user = {
        'name': prefs.getString('cubag_name') ?? 'Member',
        'role': prefs.getString('cubag_role') ?? ''
      };
    });

    // 2. Fetch all remote data in PARALLEL (Much faster)
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
      // Use a more modern approach for Forex
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;
    final firstName = (_user['name'] as String? ?? 'Member').split(' ').first;
    final pending = _tasks.where((t) => t['done'] != true).toList();
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return AppLayout(
      title: 'Dashboard',
      scrollable: false,
      child: _loading && _tasks.isEmpty
          ? const DashboardSkeleton()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
                opacity: _loading ? 0.6 : 1.0,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [primary, primary.withValues(alpha: 0.75)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: isMobile
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Good day, $firstName!', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Text('You have ${pending.length} pending item${pending.length != 1 ? 's' : ''}.', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _forexBadge('USD: ${_forex['USD']}'),
                                    _forexBadge('EUR: ${_forex['EUR']}'),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 44,
                                  child: ElevatedButton(
                                    onPressed: () => context.go('/payments'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                    child: const Text('Renew License', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                )
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Good day, $firstName!', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 6),
                                      Text('You have ${pending.length} pending item${pending.length != 1 ? 's' : ''}.', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          _forexBadge('USD: ${_forex['USD']}'),
                                          const SizedBox(width: 8),
                                          _forexBadge('EUR: ${_forex['EUR']}'),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () => context.go('/payments'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: primary, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                  child: const Text('Renew License', style: TextStyle(fontWeight: FontWeight.bold)),
                                )
                              ],
                            ),
                    ),
                    const SizedBox(height: 20),

                    // Priority Tasks
                    _sectionCard(
                      title: 'Priority Tasks',
                      icon: Icons.task_alt,
                      child: pending.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(child: Column(children: [Icon(Icons.check_circle, size: 32, color: Colors.grey), SizedBox(height: 8), Text('No pending tasks! You are all caught up.', style: TextStyle(color: Colors.grey))])),
                            )
                          : Column(
                              children: [
                                ...pending.map((task) {
                                  bool overdue = task['due_date'] != null && DateTime.tryParse(task['due_date'].toString())?.isBefore(DateTime.now()) == true;
                                  return ListTile(
                                    leading: CircleAvatar(backgroundColor: primary.withValues(alpha: 0.1), child: Icon(Icons.description, color: primary, size: 18)),
                                    title: Text(task['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                    subtitle: Text(overdue ? '⚠ Overdue: ${task['due_date']}' : 'Due: ${task['due_date'] ?? 'No deadline'}', style: TextStyle(fontSize: 12, color: overdue ? Colors.red : Colors.grey)),
                                    trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: Text('Required', style: TextStyle(fontSize: 10, color: primary, fontWeight: FontWeight.bold))),
                                  );
                                }),
                                TextButton(onPressed: () => context.go('/tasks'), child: const Text('View all tasks')),
                              ],
                            ),
                    ),
                    const SizedBox(height: 16),

                    // Announcements
                    _sectionCard(
                      title: 'Announcements',
                      icon: Icons.campaign,
                      child: _announcements.isEmpty
                          ? const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No new announcements.', style: TextStyle(color: Colors.grey))))
                          : Column(
                              children: [
                                ..._announcements.map((a) => ListTile(
                                  leading: Icon(Icons.campaign, color: primary),
                                  title: Text(a['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  subtitle: Text(a['content'] ?? a['body'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                                )),
                                TextButton(onPressed: () => context.go('/announcements'), child: const Text('View all announcements')),
                              ],
                            ),
                    ),
                    const SizedBox(height: 16),

                    // Quick Shortcuts (ECG Style Grid)
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: isMobile ? 2 : 4,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: isMobile ? 1.4 : 1.3,
                      padding: EdgeInsets.zero,
                      children: [
                        _quickAction(context, Icons.payments_outlined, 'Pay Dues', '/payments', isMobile, color: const Color(0xFF3b82f6), subtext: 'Renew your license'),
                        _quickAction(context, Icons.receipt_long_outlined, 'Statement', '/payments', isMobile, color: const Color(0xFFef4444), subtext: 'View transactions'),
                        _quickAction(context, Icons.bar_chart_rounded, 'Live Data', '/live-data', isMobile, color: const Color(0xFF10b981), subtext: 'Platform stats'),
                        _quickAction(context, Icons.support_agent_rounded, 'Support', '/engagement', isMobile, color: const Color(0xFF8b5cf6), subtext: 'Create a ticket'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Live Forex
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: primary.withAlpha(50)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Live Forex', style: TextStyle(fontWeight: FontWeight.bold, color: primary, fontSize: 16)),
                              const Spacer(),
                              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10b981), shape: BoxShape.circle)),
                              const SizedBox(width: 4),
                              const Text('LIVE', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _forexRow('\$', 'USD/GHS', _forex['USD']!, Theme.of(context).primaryColor),
                          const SizedBox(height: 12),
                          _forexRow('€', 'EUR/GHS', _forex['EUR']!, const Color(0xFF3b82f6)),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: () => context.go('/live-data'),
                            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            child: const Text('View Full Data Hub'),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _forexBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.2))),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _sectionCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [Icon(icon, color: Theme.of(context).primaryColor, size: 20), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))]),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }

  Widget _quickAction(BuildContext context, IconData icon, String label, String route, bool isMobile, {required Color color, String? subtext}) {
    return InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const Spacer(),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800), textAlign: TextAlign.center, maxLines: 1),
            if (subtext != null) ...[
              const SizedBox(height: 4),
              Text(subtext, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
            ]
          ],
        ),
      ),
    );
  }

  Widget _forexRow(String symbol, String pair, String rate, Color color) {
    return Row(
      children: [
        Container(width: 24, height: 24, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), alignment: Alignment.center, child: Text(symbol, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color))),
        const SizedBox(width: 8),
        Text(pair, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const Spacer(),
        Text(rate, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
      ],
    );
  }
}
