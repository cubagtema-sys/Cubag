import 'package:flutter/material.dart';
import '../components/app_layout.dart';
import '../services/cache_service.dart';

class VanningSchedulesPage extends StatefulWidget {
  const VanningSchedulesPage({super.key});
  @override
  State<VanningSchedulesPage> createState() => _VanningSchedulesPageState();
}

class _VanningSchedulesPageState extends State<VanningSchedulesPage> {
  bool _loading = true;
  List<dynamic> _schedules = [];
  final CacheService _cache = CacheService();

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final data = await _cache.fetchCached('/schedules/vanning');
      if (mounted) setState(() => _schedules = data);
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return AppLayout(
      title: 'Vanning Schedules',
      child: Column(children: [
        if (_loading) const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
        else if (_schedules.isEmpty)
          Container(padding: const EdgeInsets.all(60), alignment: Alignment.center, child: Column(children: [Icon(Icons.schedule, size: 48, color: Colors.grey.shade300), const SizedBox(height: 12), const Text('No vanning schedules available.', style: TextStyle(color: Colors.grey))]))
        else
          ..._schedules.map((s) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.local_shipping, color: primary)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s['container_number']?.toString() ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('${s['port'] ?? ''} · ${s['date'] ?? ''}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF10b981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Text((s['status'] ?? 'Scheduled').toString().toUpperCase(), style: const TextStyle(color: Color(0xFF10b981), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ])),
          )),
      ]),
    );
  }
}
