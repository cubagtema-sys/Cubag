import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../components/app_layout.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../services/notification_service.dart';
import '../components/shimmer_loader.dart';

const _kOrange = Color(0xFFf08232);

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _loading = true;
  String _filter = 'all';
  List<Map<String, dynamic>> _notifications = [];
  final TextEditingController _searchCtrl = TextEditingController();

  final Map<String, Map<String, dynamic>> _categories = {
    'payment': {'icon': Icons.payments_outlined, 'color': const Color(0xFF10b981), 'label': 'Payment'},
    'meeting': {'icon': Icons.event_outlined, 'color': const Color(0xFF3b82f6), 'label': 'Meeting'},
    'compliance': {'icon': Icons.task_alt_outlined, 'color': const Color(0xFFf59e0b), 'label': 'Compliance'},
    'system': {'icon': Icons.info_outline, 'color': _kOrange, 'label': 'System'},
    'announcement': {'icon': Icons.campaign_outlined, 'color': const Color(0xFF8b5cf6), 'label': 'Announcement'},
  };

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final cachedData = await CacheService().fetchCached('/announcements');
      if (!mounted) return;
      final data = ApiService.ensureList(cachedData);
      final list = data.map((a) => {
        'id': a['id'],
        'type': a['category']?.toString().toLowerCase() ?? 'announcement',
        'title': a['title'] ?? '',
        'message': a['body'] ?? a['content'] ?? '',
        'time': a['created_at'] != null ? DateTime.tryParse(a['created_at'].toString())?.toLocal().toString().split(' ').first ?? '' : '',
        'created_at': a['created_at']?.toString() ?? '',
        'read': a['is_read'] == true,
      }).toList();
      
      setState(() => _notifications = list);
      
      // Sync global unread count
      final unreadCount = list.where((n) => n['read'] != true).length;
      if (Provider.of<NotificationService>(context, listen: false).unreadCount != unreadCount) {
        Provider.of<NotificationService>(context, listen: false).fetchUnreadCount();
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

  String _formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    try {
      final date = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);
      
      if (diff.inMinutes < 60) {
        return '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        return '${diff.inHours}h ago';
      } else if (diff.inDays < 7) {
        return '${diff.inDays}d ago';
      }
      
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (_) {
      return '';
    }
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isSelected ? _kOrange : const Color(0xFFf1f5f9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _kOrange : const Color(0xFFe2e8f0),
            width: 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: _kOrange.withAlpha(30), blurRadius: 8, offset: const Offset(0, 3))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF475569),
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String searchQuery) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFf8fafc),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 48,
                color: Color(0xFFcbd5e1),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Notifications',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              searchQuery.isNotEmpty
                  ? 'Try refining your keywords or clearing the search query.'
                  : 'You are all caught up! No active notifications found.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF94a3b8),
                height: 1.4,
              ),
            ),
            if (searchQuery.isNotEmpty || _filter != 'all') ...[
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => setState(() {
                  _searchCtrl.clear();
                  _filter = 'all';
                }),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFcbd5e1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Reset Filters',
                  style: TextStyle(
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> n) {
    final cat = _categories[n['type']] ?? _categories['system']!;
    final color = cat['color'] as Color;
    final isRead = n['read'] == true;
    final dateStr = _formatDate(n['created_at']?.toString() ?? n['time']?.toString());

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(
            color: isRead ? const Color(0xFFcbd5e1).withAlpha(120) : color,
            width: isRead ? 1.5 : 4.5,
          ),
          top: BorderSide(color: const Color(0xFFcbd5e1).withAlpha(120), width: 1.5),
          right: BorderSide(color: const Color(0xFFcbd5e1).withAlpha(120), width: 1.5),
          bottom: BorderSide(color: const Color(0xFFcbd5e1).withAlpha(120), width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isRead ? 6 : 12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _markRead(n['id']),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Icon
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    cat['icon'] as IconData,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                // Text Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category Badge and Date
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withAlpha(20),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              (cat['label'] as String).toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                color: color,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (dateStr.isNotEmpty)
                            Text(
                              dateStr,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF94a3b8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Title
                      Text(
                        n['title']?.toString() ?? '',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isRead ? FontWeight.w700 : FontWeight.w900,
                          color: const Color(0xFF0f172a),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Message
                      Text(
                        n['message']?.toString() ?? '',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF475569),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Actions row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (!isRead)
                            GestureDetector(
                              onTap: () => _markRead(n['id']),
                              child: const Text(
                                'Mark as read',
                                style: TextStyle(
                                  color: _kOrange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else
                            Row(
                              children: [
                                Icon(Icons.check_circle_outline_rounded, color: Colors.grey.shade400, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'Read',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: Colors.grey.shade500,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _delete(n['id']),
                            hoverColor: Colors.red.shade50,
                            splashRadius: 18,
                            tooltip: 'Delete Notification',
                          ),
                        ],
                      ),
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

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.where((n) => n['read'] != true).length;
    final searchQuery = _searchCtrl.text.toLowerCase().trim();

    final filtered = _notifications.where((n) {
      bool filterMatch = true;
      if (_filter == 'unread') {
        filterMatch = n['read'] != true;
      } else if (_filter != 'all') {
        filterMatch = n['type'] == _filter;
      }
      if (!filterMatch) return false;

      if (searchQuery.isEmpty) return true;
      final title = (n['title'] ?? '').toString().toLowerCase();
      final message = (n['message'] ?? '').toString().toLowerCase();
      return title.contains(searchQuery) || message.contains(searchQuery);
    }).toList();

    return AppLayout(
      title: 'Notifications',
      scrollable: false,
      child: RefreshIndicator(
        onRefresh: _fetch,
        color: _kOrange,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Title
                    Text(
                      'Activity Feed',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0f172a),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Latest system alerts and personal notifications.',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF64748b),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Search input
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFf1f5f9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TextFormField(
                        controller: _searchCtrl,
                        onChanged: (val) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search notifications by title or keyword...',
                          hintStyle: const TextStyle(color: Color(0xFF94a3b8), fontSize: 14),
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94a3b8)),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, color: Color(0xFF94a3b8)),
                                  onPressed: () => setState(() {
                                    _searchCtrl.clear();
                                  }),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildFilterChip('all', 'All Notifications'),
                          _buildFilterChip('unread', 'Unread Only'),
                          _buildFilterChip('payment', 'Payment'),
                          _buildFilterChip('meeting', 'Meeting'),
                          _buildFilterChip('compliance', 'Compliance'),
                          _buildFilterChip('system', 'System'),
                          _buildFilterChip('announcement', 'Announcement'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Header row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          searchQuery.isNotEmpty
                              ? 'SEARCH RESULTS (${filtered.length})'
                              : 'LATEST UPDATES (${filtered.length})',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: const Color(0xFF64748b),
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (unread > 0)
                          TextButton.icon(
                            onPressed: _markAllRead,
                            icon: const Icon(Icons.done_all_rounded, size: 16),
                            label: const Text('Mark All Read', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: TextButton.styleFrom(
                              foregroundColor: _kOrange,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Feed Items
                    if (_loading)
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 5,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) => const ShimmerListTile(),
                      )
                    else if (filtered.isEmpty)
                      _buildEmptyState(searchQuery)
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) {
                          final n = filtered[i];
                          return _buildNotificationCard(n);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
