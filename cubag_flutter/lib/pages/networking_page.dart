import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../components/app_layout.dart';
import '../components/custom_dropdown.dart';
import '../services/api_service.dart';

class NetworkingPage extends StatefulWidget {
  const NetworkingPage({super.key});
  @override
  State<NetworkingPage> createState() => _NetworkingPageState();
}

class _NetworkingPageState extends State<NetworkingPage> {
  bool _loading = true;
  List<dynamic> _members = [];
  String _search = '';
  String _filterType = 'All';
  Map<String, dynamic>? _selected;

  final Map<String, Color> _typeColors = {
    'Corporate Agency':  const Color(0xFF3b82f6),
    'Individual Broker': const Color(0xFFf08232),
    'Freight Forwarder': const Color(0xFF10b981),
    'Shipping Line':     const Color(0xFF8b5cf6),
  };

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().get('/members');
      if (!mounted) return;
      if (res.statusCode == 200) setState(() => _members = ApiService.ensureList(res.data));
    } catch (_) {}
    if (mounted) setState(() => _loading = false);  // BUG-F15 fix
  }

  String _initials(String name) => name.trim().isEmpty ? '?' : name.split(' ').where((n) => n.isNotEmpty).map((n) => n[0]).take(2).join().toUpperCase();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    final filtered = _members.where((m) {
      // BUG-F17 fix: hide both admins AND sub_admins from the member directory
      if (m['role'] == 'admin' || m['role'] == 'sub_admin') return false;
      final q = _search.toLowerCase();
      final matchSearch = (m['name'] ?? '').toString().toLowerCase().contains(q) || (m['company'] ?? '').toString().toLowerCase().contains(q);
      final matchType = _filterType == 'All' || m['member_type'] == _filterType;
      return matchSearch && matchType;
    }).toList();

    return AppLayout(
      title: 'Member Directory',
      child: Stack(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Search
          TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Search members...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true, fillColor: Theme.of(context).cardColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).dividerColor)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).dividerColor)),
            ),
          ),
          const SizedBox(height: 10),

          // Type filter
          CustomDropdown<String>(
            value: _filterType,
            items: const [
              DropdownItem(value: 'All', label: 'All Types'),
              DropdownItem(value: 'Corporate Agency', label: 'Corporate Agency'),
              DropdownItem(value: 'Individual Broker', label: 'Individual Broker'),
              DropdownItem(value: 'Freight Forwarder', label: 'Freight Forwarder'),
              DropdownItem(value: 'Shipping Line', label: 'Shipping Line'),
            ],
            onChanged: (v) => setState(() => _filterType = v),
            prefixIcon: const Icon(Icons.work_outline),
          ),
          const SizedBox(height: 8),

          if (!_loading) Text('Found ${filtered.length} members', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),

          // Grid
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: Column(children: [CircularProgressIndicator(), SizedBox(height: 12), Text('SYNCING DIRECTORY', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 12))])))
          else if (filtered.isEmpty)
            Container(padding: const EdgeInsets.all(60), alignment: Alignment.center, decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)), child: const Column(children: [Icon(Icons.search_off, size: 48, color: Colors.grey), SizedBox(height: 12), Text('No members match your search.', style: TextStyle(color: Colors.grey))]))
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 280, childAspectRatio: 1.1, mainAxisSpacing: 12, crossAxisSpacing: 12),
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final m = filtered[i];
                final color = _typeColors[m['member_type']] ?? primary;
                final initials = _initials(m['name']?.toString() ?? '');
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Hero(
                        tag: 'avatar_${m['id']}',
                        child: Material(
                          type: MaterialType.transparency,
                          child: CircleAvatar(radius: 22, backgroundColor: color.withValues(alpha: 0.1), child: Text(initials, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(m['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                        Text((m['member_type']?.toString() ?? '').split(' ').first, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
                      ])),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [const Icon(Icons.business, size: 14, color: Colors.grey), const SizedBox(width: 4), Expanded(child: Text(m['company']?.toString() ?? 'Independent', style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis))]),
                    const Spacer(),
                    SizedBox(width: double.infinity, child: ElevatedButton(
                      onPressed: () => setState(() => _selected = Map<String, dynamic>.from(m)),
                      style: ElevatedButton.styleFrom(backgroundColor: primary, padding: const EdgeInsets.symmetric(vertical: 8)),
                      child: const Text('View', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    )),
                  ]),
                );
              },
            ),
        ]),

        // Member Detail Bottom Sheet
        if (_selected != null)
          Positioned.fill(child: GestureDetector(
            onTap: () => setState(() => _selected = null),
            child: Container(
              color: Colors.black.withValues(alpha: 0.6),
              alignment: Alignment.bottomCenter,
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
                  decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                    Expanded(child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: _buildDetailSheet(primary),
                    )),
                  ]),
                ),
              ),
            ),
          )),
      ]),
    );
  }

  Widget _buildDetailSheet(Color primary) {
    final m = _selected!;
    final color = _typeColors[m['member_type']] ?? primary;
    final initials = _initials(m['name']?.toString() ?? '');
    final isActive = m['status'] == 'active';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Hero(
          tag: 'avatar_${m['id']}',
          child: Material(
            type: MaterialType.transparency,
            child: CircleAvatar(radius: 30, backgroundColor: color.withValues(alpha: 0.1), child: Text(initials, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20))),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)), child: Text((m['member_type']?.toString() ?? '').toUpperCase(), style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold))),
        ])),
      ]),
      const SizedBox(height: 16),


      // Info rows
      ...([
        {'icon': Icons.business, 'label': 'Organisation', 'val': m['company']},
        {'icon': Icons.location_on, 'label': 'Port / Operation', 'val': m['port_of_operation']},
        {'icon': Icons.badge, 'label': 'License No.', 'val': m['license_number']},
        {'icon': Icons.mail, 'label': 'Email', 'val': m['email']},
        {'icon': Icons.phone, 'label': 'Phone', 'val': m['phone']},
      ].where((r) => r['val'] != null && r['val'].toString().isNotEmpty)).map((row) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(row['icon'] as IconData, color: color, size: 18)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(row['label'].toString().toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            Text(row['val'].toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
        ]),
      )),

      const SizedBox(height: 16),
      Row(children: [
        Expanded(flex: 2, child: ElevatedButton.icon(
          onPressed: () {
            final id = m['id']?.toString() ?? '';
            final name = m['name']?.toString() ?? '';
            final company = m['company']?.toString() ?? '';
            final uri = Uri(path: '/messaging', queryParameters: {
              'id': id,
              'name': name,
              'company': company,
            });
            context.go(uri.toString());
            setState(() => _selected = null);
          },
          style: ElevatedButton.styleFrom(backgroundColor: primary, minimumSize: const Size(0, 46)),
          icon: const Icon(Icons.chat, color: Colors.white, size: 18),
          label: const Text('Message', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        )),
        const SizedBox(width: 10),
        Expanded(child: OutlinedButton.icon(
          onPressed: () {},
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
          icon: const Icon(Icons.mail, size: 16),
          label: const Text('Email'),
        )),
      ]),
    ]);
  }
}
