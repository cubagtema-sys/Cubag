import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../components/app_layout.dart';
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
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _user = {'name': prefs.getString('cubag_name') ?? 'Member', 'role': prefs.getString('cubag_role') ?? ''});

    try {
      final api = ApiService();
      final taskRes = await api.get('/tasks');
      final annRes  = await api.get('/announcements');
      if (!mounted) return;
      if (taskRes.statusCode == 200) setState(() => _tasks = ApiService.ensureList(taskRes.data));
      if (annRes.statusCode  == 200) setState(() => _announcements = ApiService.ensureList(annRes.data).take(3).toList());
    } catch (_) {}

    try {
      final res = await http.get(Uri.parse('https://open.er-api.com/v6/latest/GHS'));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = res.body;
        String extractRate(String currency) {
          final pattern = '"$currency":';
          final idx = body.indexOf(pattern);
          if (idx == -1) return '...';
          final start = idx + pattern.length;
          final end = body.indexOf(',', start);
          final rateStr = body.substring(start, end).trim();
          final rate = double.tryParse(rateStr);
          return rate != null ? (1 / rate).toStringAsFixed(2) : '...';
        }
        setState(() => _forex = {'USD': extractRate('USD'), 'EUR': extractRate('EUR')});
      }
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
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
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Banner (Responsive layout)
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

                // Quick Shortcuts (Responsive grid layout)
                _sectionCard(
                  title: 'Quick Shortcuts',
                  icon: Icons.apps,
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: isMobile ? 2 : 4,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: isMobile ? 2.5 : 1.3,
                    padding: const EdgeInsets.all(12),
                    children: [
                      _quickAction(context, Icons.payments, 'Pay Dues', '/payments', isMobile),
                      _quickAction(context, Icons.bar_chart, 'Live Data', '/live-data', isMobile),
                      _quickAction(context, Icons.group, 'Networking', '/networking', isMobile),
                      _quickAction(context, Icons.support_agent, 'Support', '/engagement', isMobile),
                    ],
                  ),
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
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.withAlpha(20))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [Icon(icon, color: Theme.of(context).primaryColor, size: 20), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }

  Widget _quickAction(BuildContext context, IconData icon, String label, String route, bool isMobile) {
    final primary = Theme.of(context).primaryColor;
    return InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primary.withValues(alpha: 0.1)),
        ),
        child: isMobile 
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: primary, size: 18),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label, 
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 40, height: 40, decoration: BoxDecoration(color: primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: primary, size: 20)),
                  const SizedBox(height: 6),
                  Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
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
