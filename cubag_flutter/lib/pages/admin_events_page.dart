import 'package:flutter/material.dart';
import '../components/app_layout.dart';
import '../services/api_service.dart';
import 'admin_qr_scanner_page.dart';

const _kOrange = Color(0xFFf08232);
const _kRed    = Color(0xFFef4444);

class AdminEventsPage extends StatefulWidget {
  const AdminEventsPage({super.key});
  @override State<AdminEventsPage> createState() => _State();
}

class _State extends State<AdminEventsPage> {
  final _api = ApiService();
  List<dynamic> _events = [];
  bool _loading = true;
  bool _submitting = false;
  String _tab = 'upcoming';
  Map<String, dynamic>? _editingEvent;

  final _titleCtrl    = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _descCtrl     = TextEditingController();
  String _date = '', _time = '';

  final _eTitleCtrl    = TextEditingController();
  final _eLocationCtrl = TextEditingController();
  final _eDescCtrl     = TextEditingController();
  String _eDate = '', _eTime = '';

  @override void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final data = await _api.fetchData('events/admin/all?per_page=200');
    if (mounted) setState(() { _events = ApiService.ensureList(data); _loading = false; });
  }

  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  List<dynamic> get _upcoming => _events.where((e) {
    if (e['date'] == null) return false;
    return e['date'].toString().split('T')[0].compareTo(_today()) >= 0;
  }).toList();
  List<dynamic> get _past => _events.where((e) {
    if (e['date'] == null) return false;
    return e['date'].toString().split('T')[0].compareTo(_today()) < 0;
  }).toList();

  Future<void> _createEvent() async {
    if (_titleCtrl.text.isEmpty || _locationCtrl.text.isEmpty || _date.isEmpty || _time.isEmpty) return;
    setState(() => _submitting = true);
    await _api.postData('events', {'title': _titleCtrl.text, 'location': _locationCtrl.text, 'description': _descCtrl.text, 'date': _date, 'time': _time});
    _titleCtrl.clear(); _locationCtrl.clear(); _descCtrl.clear();
    setState(() { _date = ''; _time = ''; _submitting = false; _tab = 'upcoming'; });
    await _fetch();
  }

  Future<void> _deleteEvent(int id) async {
    await _api.deleteData('events/$id');
    await _fetch();
  }

  Future<void> _saveEdit() async {
    if (_editingEvent == null) return;
    setState(() => _submitting = true);
    await _api.putData('events/${_editingEvent!['id']}', {'title': _eTitleCtrl.text, 'location': _eLocationCtrl.text, 'description': _eDescCtrl.text, 'date': _eDate, 'time': _eTime});
    setState(() { _editingEvent = null; _submitting = false; });
    await _fetch();
  }

  void _openEdit(Map ev) {
    _eTitleCtrl.text    = ev['title'] ?? '';
    _eLocationCtrl.text = ev['location'] ?? '';
    _eDescCtrl.text     = ev['description'] ?? '';
    _eDate = ev['date'] != null ? ev['date'].toString().split('T')[0] : '';
    _eTime = ev['time'] ?? '';
    setState(() => _editingEvent = Map<String, dynamic>.from(ev));
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      {'id': 'upcoming', 'label': 'Upcoming'},
      {'id': 'history',  'label': 'History'},
      {'id': 'create',   'label': 'New Event'},
    ];
    return AppLayout(
      title: 'Events Management',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
          child: Row(children: tabs.map((t) {
            final active = _tab == t['id'];
            return Expanded(child: GestureDetector(
              onTap: () => setState(() => _tab = t['id']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: active ? _kOrange : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: Text(t['label']!, style: TextStyle(color: active ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ));
          }).toList()),
        ),
        const SizedBox(height: 16),
        if (_tab == 'create')   _buildCreateForm(),
        if (_tab == 'upcoming') _buildEventList(_upcoming, isPast: false),
        if (_tab == 'history')  _buildEventList(_past, isPast: true),
        if (_editingEvent != null) _buildEditModal(),
      ]),
    );
  }

  Widget _buildCreateForm() => Container(
    constraints: const BoxConstraints(maxWidth: 600),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('New Event', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 16),
      _field('Event Title', _titleCtrl, hint: 'e.g. Annual Meeting'),
      const SizedBox(height: 14),
      _field('Venue', _locationCtrl, hint: 'e.g. Tema Secretariat'),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Date', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), const SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2099));
              if (picked != null) setState(() => _date = '${picked.year}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    _date.isEmpty ? 'Pick date' : _date,
                    style: TextStyle(color: _date.isEmpty ? Colors.grey.shade600 : Colors.black, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ])),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Time', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), const SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
              if (picked != null && mounted) setState(() => _time = picked.format(context));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    _time.isEmpty ? 'Pick time' : _time,
                    style: TextStyle(color: _time.isEmpty ? Colors.grey.shade600 : Colors.black, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ])),
      ]),
      const SizedBox(height: 14),
      _field('Description', _descCtrl, hint: 'Details...', maxLines: 3),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
        onPressed: _submitting ? null : _createEvent,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kOrange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Text(_submitting ? 'Publishing...' : 'Publish Event', style: const TextStyle(fontWeight: FontWeight.bold)),
      )),
    ]),
  );

  Widget _buildEventList(List events, {required bool isPast}) {
    if (_loading) return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: _kOrange)));
    if (events.isEmpty) return Container(padding: const EdgeInsets.all(48), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)), child: const Center(child: Text('No events found.', style: TextStyle(color: Colors.grey))));
    return Column(children: events.map((ev) {
      final dateStr = ev['date']?.toString().split('T')[0] ?? '';
      DateTime? dateObj; try { dateObj = DateTime.parse(dateStr); } catch (_) {}
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 6)]),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 44, height: 44, decoration: BoxDecoration(color: (isPast ? Colors.grey : _kOrange).withAlpha(20), borderRadius: BorderRadius.circular(12)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(dateObj != null ? ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][dateObj.month-1] : '', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: isPast ? Colors.grey : _kOrange)),
              Text(dateObj?.day.toString() ?? '', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: isPast ? Colors.grey : _kOrange, height: 1)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ev['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.access_time, size: 14, color: Colors.grey), const SizedBox(width: 4), Text(ev['time'] ?? 'TBD', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(width: 10),
              const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey), const SizedBox(width: 4), Expanded(child: Text(ev['location'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              if (!isPast) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => AdminQrScannerPage(
                        onScan: (memberId) => _handleCheckIn(ev['id'], memberId),
                      )));
                    },
                    icon: const Icon(Icons.qr_code_scanner, size: 14),
                    label: const Text('Check-in', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10b981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _openEdit(ev),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kOrange,
                    side: const BorderSide(color: _kOrange),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Edit', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _deleteEvent(ev['id']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kRed,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Delete', style: TextStyle(fontSize: 12)),
                ),
              ),
            ]),
          ])),
        ]),
      );
    }).toList());
  }

  Future<void> _handleCheckIn(int eventId, String memberId) async {
    setState(() => _loading = true);
    try {
      // In the future this should call a dedicated endpoint like:
      // await _api.postData('events/admin/$eventId/checkin', {'member_id': memberId});
      
      // For now, we simulate a successful API call
      await Future.delayed(const Duration(seconds: 1));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Member #$memberId checked in successfully!'),
          backgroundColor: const Color(0xFF10b981),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to check in: $e'),
          backgroundColor: _kRed,
        ));
      }
    }
    setState(() => _loading = false);
  }

  Widget _buildEditModal() => Container(
    color: Colors.black54,
    child: Center(child: Container(
      margin: const EdgeInsets.all(20), padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Text('Edit Event', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), const Spacer(), IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _editingEvent = null))]),
        const SizedBox(height: 16),
        _field('Title', _eTitleCtrl), const SizedBox(height: 12),
        _field('Venue', _eLocationCtrl), const SizedBox(height: 12),
        _field('Description', _eDescCtrl, maxLines: 3), const SizedBox(height: 16),
        SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
          onPressed: _submitting ? null : _saveEdit,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kOrange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: Text(_submitting ? 'Saving...' : 'Save Changes', style: const TextStyle(fontWeight: FontWeight.bold)),
        )),
      ]),
    )),
  );

  Widget _field(String label, TextEditingController ctrl, {String? hint, int maxLines = 1}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), const SizedBox(height: 6),
    TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748b)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kOrange, width: 2)),
      ),
    ),
  ]);
}
