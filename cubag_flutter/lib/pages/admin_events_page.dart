import 'package:flutter/material.dart';
import '../components/app_layout.dart';
import '../services/api_service.dart';
import '../components/fetch_error_view.dart';
import '../components/shimmer_loader.dart';
import 'admin_qr_scanner_page.dart';
import 'admin_event_attendees_page.dart';

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
  bool _hasError = false;
  bool _loadingMore = false;
  bool _submitting = false;
  String _tab = 'upcoming';
  Map<String, dynamic>? _editingEvent;

  int _page = 1;
  int _total = 0;
  bool _hasMore = true;

  final ScrollController _scrollController = ScrollController();

  final _titleCtrl    = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _descCtrl     = TextEditingController();
  String _date = '', _time = '';

  final _eTitleCtrl    = TextEditingController();
  final _eLocationCtrl = TextEditingController();
  final _eDescCtrl     = TextEditingController();
  String _eDate = '', _eTime = '';

  @override void initState() { 
    super.initState(); 
    _fetch(); 
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _descCtrl.dispose();
    _eTitleCtrl.dispose();
    _eLocationCtrl.dispose();
    _eDescCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_loading && !_loadingMore && _hasMore && _tab != 'create') {
        _fetchMore();
      }
    }
  }

  Future<void> _fetch({bool refresh = false}) async {
    if (!mounted) return;
    if (refresh) {
      setState(() { _page = 1; _hasMore = true; _loading = true; _events = []; });
    } else {
      if (!_loading) setState(() => _loading = true);
    }
    
    await _api.fetchDataWithCache('/events/admin/all?page=$_page&per_page=20&status=$_tab', (data, isCached, {bool hasError = false}) {
      if (!mounted) return;
      if (hasError && _events.isEmpty) {
        setState(() { _loading = false; _hasError = true; });
        return;
      }
      if (data == null) { setState(() => _loading = false); return; }
      final d = data as Map<String, dynamic>;
      setState(() { 
        _loading = false;
          _hasError = false;
        _events = ApiService.ensureList(d); 
        if (d.containsKey('total')) {
          _total = d['total'];
          _hasMore = _events.length < _total;
        } else {
          _hasMore = false;
        }
      });
    });
  }

  Future<void> _fetchMore() async {
    setState(() => _loadingMore = true);
    _page++;
    try {
      final res = await _api.get('/events/admin/all?page=$_page&per_page=20&status=$_tab');
      if (res.statusCode == 200) {
        final d = res.data as Map<String, dynamic>;
        final newItems = ApiService.ensureList(d);
        setState(() {
          _events.addAll(newItems);
          if (d.containsKey('total')) {
            _hasMore = _events.length < d['total'];
          } else {
            _hasMore = newItems.isNotEmpty;
          }
        });
      }
    } catch (_) { _page--; }
    if (mounted) setState(() => _loadingMore = false);
  }

  void _onTabChanged(String newTab) {
    if (_tab == newTab) return;
    setState(() => _tab = newTab);
    if (newTab != 'create') {
      _fetch(refresh: true);
    }
  }

  Future<void> _createEvent() async {
    if (_titleCtrl.text.isEmpty || _locationCtrl.text.isEmpty || _date.isEmpty || _time.isEmpty) return;
    setState(() => _submitting = true);
    await _api.postData('events', {'title': _titleCtrl.text, 'location': _locationCtrl.text, 'description': _descCtrl.text, 'date': _date, 'time': _time});
    _titleCtrl.clear(); _locationCtrl.clear(); _descCtrl.clear();
    setState(() { _date = ''; _time = ''; _submitting = false; _tab = 'upcoming'; });
    await _fetch(refresh: true);
  }

  Future<void> _deleteEvent(int id) async {
    await _api.deleteData('events/$id');
    await _fetch(refresh: true);
  }

  Future<void> _saveEdit() async {
    if (_editingEvent == null) return;
    setState(() => _submitting = true);
    await _api.putData('events/${_editingEvent!['id']}', {'title': _eTitleCtrl.text, 'location': _eLocationCtrl.text, 'description': _eDescCtrl.text, 'date': _eDate, 'time': _eTime});
    setState(() { _editingEvent = null; _submitting = false; });
    await _fetch(refresh: true);
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
      scrollable: false,
      child: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                child: Row(children: tabs.map((t) {
                  final active = _tab == t['id'];
                  return Expanded(child: GestureDetector(
                    onTap: () => _onTabChanged(t['id']!),
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
              if (_tab != 'create')   _buildEventList(isPast: _tab == 'history'),
            ]),
          ),
          if (_editingEvent != null) _buildEditModal(),
        ],
      ),
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

  Widget _buildEventList({required bool isPast}) {
    if (_loading) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 8,
        separatorBuilder: (ctx, i) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) => const ShimmerListTile(),
      );
    }
    if (_hasError && _events.isEmpty) return FetchErrorView(onRetry: () => _fetch(refresh: true));
    if (_events.isEmpty) return Container(padding: const EdgeInsets.all(48), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)), child: const Center(child: Text('No events found.', style: TextStyle(color: Colors.grey))));
    
    return Column(children: [
      ..._events.map((ev) {
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
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _viewAttendees(ev['id'], ev['title'] ?? ''),
                    icon: const Icon(Icons.people_alt_outlined, size: 14),
                    label: const Text('Attendees', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                      side: BorderSide(color: Colors.blue.shade700),
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _openEdit(ev),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kOrange,
                      side: const BorderSide(color: _kOrange),
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Edit Event', style: TextStyle(fontSize: 12)),
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
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Delete Event', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ]),
            ])),
          ]),
        );
      }),
      if (_loadingMore) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
      if (!_loading) Center(child: Padding(padding: const EdgeInsets.only(bottom: 20), child: Text('${_events.length} events shown${_total > 0 ? " of $_total" : ""}', style: const TextStyle(fontSize: 12, color: Colors.grey)))),
    ]);
  }

  void _viewAttendees(int eventId, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminEventAttendeesPage(eventId: eventId, title: title),
      ),
    );
  }

  Future<void> _handleCheckIn(int eventId, String memberId) async {
    setState(() => _loading = true);
    try {
      final res = await _api.post('/events/$eventId/check-in', data: {'member_id': memberId});
      if (mounted) {
        final member = res.data['member'];
        if (member != null) {
          _showMemberVerification(member, res.statusCode == 200 || res.statusCode == 201, res.data['message']);
        } else {
          if (res.statusCode == 200 || res.statusCode == 201) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(res.data['message'] ?? 'Member checked in successfully!'),
              backgroundColor: const Color(0xFF10b981),
            ));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(res.data['message'] ?? 'Failed to check in member'),
              backgroundColor: _kRed,
            ));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        // Dio throws exceptions for non-2xx status codes
        if (e.toString().contains('DioException') || e.runtimeType.toString() == 'DioException') {
          try {
            // Try to extract the response if it's a DioException
            final dynamic dioErr = e;
            if (dioErr.response != null && dioErr.response.data != null) {
              final resData = dioErr.response.data;
              if (resData is Map && resData['member'] != null) {
                _showMemberVerification(resData['member'], false, resData['message']);
                setState(() => _loading = false);
                return;
              } else if (resData is Map && resData['message'] != null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(resData['message']),
                  backgroundColor: _kRed,
                ));
                setState(() => _loading = false);
                return;
              }
            }
          } catch (_) {}
        }
        
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to check in: $e'),
          backgroundColor: _kRed,
        ));
      }
    }
    setState(() => _loading = false);
  }

  void _showMemberVerification(Map<String, dynamic> member, bool isSuccess, String? message) {
    bool isDismissed = false;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        Future.delayed(const Duration(seconds: 4), () {
          if (!isDismissed && ctx.mounted) {
            Navigator.of(ctx).pop();
          }
        });

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Photo
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: member['profile_photo'] != null && member['profile_photo'].toString().isNotEmpty
                    ? NetworkImage(member['profile_photo'])
                    : null,
                child: member['profile_photo'] == null || member['profile_photo'].toString().isEmpty
                    ? Text((member['name'] ?? '?')[0].toUpperCase(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.grey))
                    : null,
              ),
              const SizedBox(height: 16),
              
              // Name & Company
              Text(member['name'] ?? 'Unknown Member', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(member['company'] ?? 'No Company', style: const TextStyle(fontSize: 14, color: Colors.grey), textAlign: TextAlign.center),
              if (member['license_number'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(member['license_number'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kOrange)),
                ),
              
              const SizedBox(height: 24),
              
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSuccess ? const Color(0xFF10b981).withAlpha(20) : _kRed.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSuccess ? const Color(0xFF10b981) : _kRed, width: 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(isSuccess ? Icons.check_circle : Icons.cancel, color: isSuccess ? const Color(0xFF10b981) : _kRed),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isSuccess ? 'ACCESS GRANTED' : (message ?? 'ACCESS DENIED'),
                        style: TextStyle(
                          color: isSuccess ? const Color(0xFF10b981) : _kRed,
                          fontWeight: FontWeight.bold,
                          fontSize: isSuccess ? 16 : 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    ).then((_) {
      isDismissed = true;
    });
  }

  Widget _buildEditModal() => Positioned.fill(
    child: Container(
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
    ),
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
