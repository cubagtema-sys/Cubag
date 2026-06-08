import 'package:provider/provider.dart';
import '../components/app_layout.dart';
import '../components/custom_dropdown.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _loading = true;
  String _filter = 'all';
  List<Map<String, dynamic>> _notifications = [];

  final Map<String, Map<String, dynamic>> _categories = {
    'payment': {'icon': Icons.payments, 'color': const Color(0xFF10b981), 'label': 'Payment'},
    'meeting': {'icon': Icons.event, 'color': const Color(0xFF3b82f6), 'label': 'Meeting'},
    'compliance': {'icon': Icons.task_alt, 'color': const Color(0xFFf59e0b), 'label': 'Compliance'},
    'system': {'icon': Icons.info, 'color': const Color(0xFFf08232), 'label': 'System'},
    'announcement': {'icon': Icons.campaign, 'color': const Color(0xFF8b5cf6), 'label': 'Announcement'},
  };

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().get('/announcements');
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = ApiService.ensureList(res.data);
        final list = data.map((a) => {
          'id': a['id'],
          'type': a['category']?.toString().toLowerCase() ?? 'announcement',
          'title': a['title'] ?? '',
          'message': a['body'] ?? a['content'] ?? '',
          'time': a['created_at'] != null ? DateTime.tryParse(a['created_at'].toString())?.toLocal().toString().split(' ').first ?? '' : '',
          'read': a['is_read'] == true,
        }).toList();
        
        setState(() => _notifications = list);
        
        // Sync global unread count
        final unreadCount = list.where((n) => n['read'] != true).length;
        if (Provider.of<NotificationService>(context, listen: false).unreadCount != unreadCount) {
          Provider.of<NotificationService>(context, listen: false).fetchUnreadCount();
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _markAllRead() async {
    try {
      await ApiService().post('/announcements/mark-read', data: {});
      if (!mounted) return;
      setState(() => _notifications = _notifications.map((n) => {...n, 'read': true}).toList());
      Provider.of<NotificationService>(context, listen: false).clearCount();
    } catch (_) {}
  }

  Future<void> _markRead(dynamic id) async {
    final notification = _notifications.firstWhere((n) => n['id'] == id, orElse: () => {});
    if (notification.isNotEmpty && notification['read'] != true) {
      try {
        await ApiService().post('/announcements/mark-read', data: {'announcement_id': id});
        if (!mounted) return;
        setState(() => _notifications = _notifications.map((n) => n['id'] == id ? {...n, 'read': true} : n).toList());
        Provider.of<NotificationService>(context, listen: false).decrementCount();
      } catch (_) {}
    }
  }

  // F-36 fix: delete from server first, then remove locally
  Future<void> _delete(dynamic id) async {
    try {
      await ApiService().delete('/announcements/$id');
    } catch (_) {
      // If server call fails, still remove locally (graceful degradation)
    }
    if (mounted) {
      setState(() => _notifications = _notifications.where((n) => n['id'] != id).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final unread = _notifications.where((n) => n['read'] != true).length;
    final filtered = _filter == 'all' ? _notifications : _filter == 'unread' ? _notifications.where((n) => n['read'] != true).toList() : _notifications.where((n) => n['type'] == _filter).toList();

    return AppLayout(
      title: 'Notifications',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Activity Feed', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const Text('Latest system alerts and personal notifications.', style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: CustomDropdown<String>(
            value: _filter,
            items: const [
              DropdownItem(value: 'all', label: 'All Notifications'),
              DropdownItem(value: 'unread', label: 'Unread Only'),
              DropdownItem(value: 'payment', label: 'Payment'),
              DropdownItem(value: 'meeting', label: 'Meeting'),
              DropdownItem(value: 'compliance', label: 'Compliance'),
              DropdownItem(value: 'announcement', label: 'Announcement'),
            ],
            onChanged: (v) => setState(() => _filter = v),
            prefixIcon: const Icon(Icons.filter_list),
          )),
          if (unread > 0) ...[
            const SizedBox(width: 12),
            TextButton(onPressed: _markAllRead, child: Text('Clear Unread', style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 13))),
          ]
        ]),
        const SizedBox(height: 16),
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
        else if (filtered.isEmpty)
          Container(padding: const EdgeInsets.all(60), alignment: Alignment.center, decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)), child: const Column(children: [Icon(Icons.notifications_none, size: 48, color: Colors.grey), SizedBox(height: 12), Text('No notifications yet.', style: TextStyle(color: Colors.grey))]))
        else
          Column(children: filtered.map((n) {
            final cat = _categories[n['type']] ?? _categories['system']!;
            final color = cat['color'] as Color;
            final isRead = n['read'] == true;
            return GestureDetector(
              onTap: () => _markRead(n['id']),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border(left: BorderSide(color: isRead ? Colors.transparent : color, width: 3)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
                ),
                child: Row(children: [
                  Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(cat['icon'] as IconData, color: color, size: 18)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(n['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis)),
                      Text(n['time']?.toString() ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ]),
                    const SizedBox(height: 4),
                    Text(n['message']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: Text((cat['label'] as String).toUpperCase(), style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold))),
                      GestureDetector(onTap: () => _delete(n['id']), child: const Icon(Icons.delete_outline, size: 18, color: Colors.grey)),
                    ]),
                  ])),
                ]),
              ),
            );
          }).toList()),
      ]),
    );
  }
}
