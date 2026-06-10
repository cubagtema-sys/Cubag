import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AdminEventAttendeesPage extends StatefulWidget {
  final int eventId;
  final String title;

  const AdminEventAttendeesPage({
    super.key,
    required this.eventId,
    required this.title,
  });

  @override
  State<AdminEventAttendeesPage> createState() => _AdminEventAttendeesPageState();
}

class _AdminEventAttendeesPageState extends State<AdminEventAttendeesPage> {
  bool _loading = true;
  List<dynamic> _allMembers = [];
  String _filter = 'all'; // 'all', 'attended', 'absent'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final res = await ApiService().get('/events/${widget.eventId}/attendees');
      if (mounted && res.statusCode == 200) {
        setState(() {
          _allMembers = res.data['attendees'] ?? [];
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to load attendees: ${res.data}'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        try {
          final dynamic dioErr = e;
          if (dioErr.response != null && dioErr.response.data != null) {
            msg = dioErr.response.data['message'] ?? dioErr.response.data.toString();
          }
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error loading attendees: $msg'),
          backgroundColor: Colors.red,
        ));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    List<dynamic> filtered = _allMembers.where((m) {
      final attended = m['checked_in_at'] != null;
      if (_filter == 'attended' && !attended) return false;
      if (_filter == 'absent' && attended) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = (m['name'] ?? '').toLowerCase();
        final company = (m['company'] ?? '').toLowerCase();
        if (!name.contains(q) && !company.contains(q)) return false;
      }
      return true;
    }).toList();

    int attendedCount = _allMembers.where((m) => m['checked_in_at'] != null).length;
    int absentCount = _allMembers.length - attendedCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Event Attendance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(widget.title, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip('All', 'all', _allMembers.length, primary),
                const SizedBox(width: 8),
                _buildFilterChip('Checked In', 'attended', attendedCount, const Color(0xFF10b981)),
                const SizedBox(width: 8),
                _buildFilterChip('Absent', 'absent', absentCount, const Color(0xFFef4444)),
              ],
            ),
          ),

          // Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search by name or company...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),

          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isEmpty ? 'No members found.' : 'No matches for "$_searchQuery".',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                          final a = filtered[i];
                          final bool isAttended = a['checked_in_at'] != null;
                          final nameStr = a['name']?.toString() ?? '';
                          final initial = nameStr.trim().isNotEmpty ? nameStr.trim()[0].toUpperCase() : '?';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: isAttended ? const Color(0xFF10b981).withAlpha(30) : Colors.grey.withAlpha(50),
                                child: Text(initial, style: TextStyle(color: isAttended ? const Color(0xFF10b981) : Colors.grey.shade700, fontWeight: FontWeight.bold)),
                              ),
                              title: Text(nameStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text('${a['email'] ?? ''}\n${a['company'] ?? ''}', style: const TextStyle(fontSize: 12, height: 1.4)),
                              isThreeLine: true,
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (isAttended) ...[
                                    const Icon(Icons.check_circle, color: Color(0xFF10b981), size: 20),
                                    const SizedBox(height: 4),
                                    const Text('Checked In', style: TextStyle(color: Color(0xFF10b981), fontSize: 10, fontWeight: FontWeight.bold)),
                                  ] else ...[
                                    Icon(Icons.cancel, color: Colors.grey.shade400, size: 20),
                                    const SizedBox(height: 4),
                                    Text('Absent', style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ]
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, int count, Color color) {
    final isSelected = _filter == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _filter = value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withAlpha(20) : Colors.transparent,
            border: Border.all(color: isSelected ? color : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(count.toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isSelected ? color : Colors.grey.shade800)),
              Text(label, style: TextStyle(fontSize: 10, color: isSelected ? color : Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }
}
