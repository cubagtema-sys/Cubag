import 'package:flutter/material.dart';
import '../components/app_layout.dart';
import '../services/api_service.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});
  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  bool _loading = true;
  List<dynamic> _events = [];

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().get('/events');
      if (res.statusCode == 200) setState(() => _events = ApiService.ensureList(res.data));
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return AppLayout(
      title: 'Events & Workshops',
      child: Column(children: [
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
        else if (_events.isEmpty)
          Container(padding: const EdgeInsets.all(60), alignment: Alignment.center, child: Column(children: [Icon(Icons.calendar_month, size: 48, color: Colors.grey.shade300), const SizedBox(height: 12), const Text('No Upcoming Events', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 6), const Text('Check back later for meetings and seminars.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))]))
        else
          ..._events.map((e) {
            DateTime? date;
            try { date = DateTime.parse(e['date'].toString()); } catch (_) {}
            final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
            final isSmall = MediaQuery.of(context).size.width < 360;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: date == null 
                    ? Icon(Icons.calendar_month, color: primary) 
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(months[date.month - 1].toUpperCase(), style: TextStyle(color: primary, fontSize: 9, fontWeight: FontWeight.bold)),
                          Text('${date.day}', style: TextStyle(color: primary, fontSize: 18, fontWeight: FontWeight.bold, height: 1.1)),
                        ],
                      ),
                ),
                title: Text(
                  e['title']?.toString() ?? '', 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      e['description']?.toString() ?? '', 
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (e['time'] != null) ...[
                          const Icon(Icons.schedule, size: 10, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(e['time'].toString(), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          const SizedBox(width: 12),
                        ],
                        if (e['location'] != null) ...[
                          const Icon(Icons.location_on, size: 10, color: Colors.grey),
                          const SizedBox(width: 4),
                          Flexible(child: Text(e['location'].toString(), style: const TextStyle(fontSize: 10, color: Colors.grey), overflow: TextOverflow.ellipsis)),
                        ],
                      ],
                    ),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 16),
                onTap: () {
                  // Optional: Show full details in a bottom sheet or dialog
                  showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (ctx) => Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                          const SizedBox(height: 8),
                          Row(children: [
                            Icon(Icons.calendar_today, size: 14, color: primary),
                            const SizedBox(width: 8),
                            Text(e['date']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                            if (e['time'] != null) ...[const SizedBox(width: 16), Icon(Icons.access_time, size: 14, color: primary), const SizedBox(width: 8), Text(e['time'].toString())],
                          ]),
                          const SizedBox(height: 16),
                          Text(e['description']?.toString() ?? '', style: const TextStyle(fontSize: 14, height: 1.5)),
                          if (e['location'] != null) ...[
                            const SizedBox(height: 16),
                            const Text('Location', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(e['location'].toString()),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          }),
      ]),
    );
  }
}
