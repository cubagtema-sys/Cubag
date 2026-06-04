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
      if (res.statusCode == 200) setState(() => _events = List.from(res.data ?? []));
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
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: IntrinsicHeight(child: Row(children: [
                Container(
                  width: 76,
                  decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [primary, primary.withValues(alpha: 0.7)]), borderRadius: const BorderRadius.horizontal(left: Radius.circular(14))),
                  alignment: Alignment.center,
                  child: date == null ? const Icon(Icons.calendar_month, color: Colors.white) : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(months[date.month - 1].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    Text('${date.day}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, height: 1)),
                  ]),
                ),
                Expanded(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(e['description']?.toString() ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Wrap(spacing: 12, children: [
                    if (e['time'] != null) Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.schedule, size: 14, color: Colors.grey), const SizedBox(width: 4), Text(e['time'].toString(), style: const TextStyle(fontSize: 11, color: Colors.grey))]),
                    if (e['location'] != null) Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.location_on, size: 14, color: Colors.grey), const SizedBox(width: 4), Text(e['location'].toString(), style: const TextStyle(fontSize: 11, color: Colors.grey))]),
                  ]),
                ]))),
              ])),
            );
          }),
      ]),
    );
  }
}
