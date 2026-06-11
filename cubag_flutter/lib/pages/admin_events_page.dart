import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../components/app_layout.dart';
import '../services/api_service.dart';
import '../components/fetch_error_view.dart';
import '../components/shimmer_loader.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1e293b) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0);
    final textColor = isDark ? const Color(0xFFf8fafc) : const Color(0xFF0f172a);
    final subTextColor = isDark ? const Color(0xFF94a3b8) : const Color(0xFF475569);
    final inputBg = isDark ? const Color(0xFF0f172a).withValues(alpha: 0.4) : const Color(0xFFf8fafc);

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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
                child: Row(children: tabs.map((t) {
                  final active = _tab == t['id'];
                  return Expanded(child: GestureDetector(
                    onTap: () => _onTabChanged(t['id']!),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: active ? _kOrange : Colors.transparent, 
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: active ? [BoxShadow(color: _kOrange.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
                      ),
                      alignment: Alignment.center,
                      child: Text(t['label']!, style: GoogleFonts.outfit(color: active ? Colors.white : subTextColor, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ));
                }).toList()),
              ),
              const SizedBox(height: 16),
              if (_tab == 'create')   _buildCreateForm(cardBg, borderColor, textColor, subTextColor, inputBg, isDark),
              if (_tab != 'create')   _buildEventList(isPast: _tab == 'history', cardBg: cardBg, borderColor: borderColor, textColor: textColor, subTextColor: subTextColor, isDark: isDark),
            ]),
          ),
          if (_editingEvent != null) _buildEditModal(cardBg, borderColor, textColor, subTextColor, inputBg, isDark),
        ],
      ),
    );
  }

  Widget _buildCreateForm(Color cardBg, Color borderColor, Color textColor, Color subTextColor, Color inputBg, bool isDark) => Container(
    constraints: const BoxConstraints(maxWidth: 600),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02), blurRadius: 10)]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('New Event', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
      const SizedBox(height: 20),
      _field('Event Title', _titleCtrl, hint: 'e.g. Annual Meeting', textColor: textColor, subTextColor: subTextColor, borderColor: borderColor, inputBg: inputBg),
      const SizedBox(height: 16),
      _field('Venue', _locationCtrl, hint: 'e.g. Tema Secretariat', textColor: textColor, subTextColor: subTextColor, borderColor: borderColor, inputBg: inputBg),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Date', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12, color: subTextColor)), const SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2099));
              if (picked != null) setState(() => _date = '${picked.year}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: inputBg,
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 18, color: subTextColor),
                  const SizedBox(width: 8),
                  Text(
                    _date.isEmpty ? 'Pick date' : _date,
                    style: GoogleFonts.outfit(color: _date.isEmpty ? subTextColor : textColor, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ])),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Time', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12, color: subTextColor)), const SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
              if (picked != null && mounted) setState(() => _time = picked.format(context));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: inputBg,
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 18, color: subTextColor),
                  const SizedBox(width: 8),
                  Text(
                    _time.isEmpty ? 'Pick time' : _time,
                    style: GoogleFonts.outfit(color: _time.isEmpty ? subTextColor : textColor, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ])),
      ]),
      const SizedBox(height: 16),
      _field('Description', _descCtrl, hint: 'Details...', maxLines: 3, textColor: textColor, subTextColor: subTextColor, borderColor: borderColor, inputBg: inputBg),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(
        onPressed: _submitting ? null : _createEvent,
        icon: _submitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded, size: 18),
        label: Text(_submitting ? 'Publishing...' : 'Publish Event', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _kOrange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      )),
    ]),
  );

  Widget _buildEventList({required bool isPast, required Color cardBg, required Color borderColor, required Color textColor, required Color subTextColor, required bool isDark}) {
    if (_loading) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 8,
        separatorBuilder: (ctx, i) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) => Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
          child: const ShimmerListTile(),
        ),
      );
    }
    if (_hasError && _events.isEmpty) return FetchErrorView(onRetry: () => _fetch(refresh: true));
    if (_events.isEmpty) return Container(padding: const EdgeInsets.all(48), decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)), child: Center(child: Text('No events found.', style: GoogleFonts.outfit(color: subTextColor, fontWeight: FontWeight.bold))));
    
    return Column(children: [
      ..._events.map((ev) {
        final dateStr = ev['date']?.toString().split('T')[0] ?? '';
        DateTime? dateObj; try { dateObj = DateTime.parse(dateStr); } catch (_) {}
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02), blurRadius: 8, offset: const Offset(0, 3))]),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 52, height: 52, 
              decoration: BoxDecoration(color: (isPast ? subTextColor : _kOrange).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(dateObj != null ? ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][dateObj.month-1] : '', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: isPast ? subTextColor : _kOrange)),
                Text(dateObj?.day.toString() ?? '', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: isPast ? subTextColor : _kOrange, height: 1)),
              ]),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ev['title'] ?? '', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: textColor), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.access_time_rounded, size: 14, color: subTextColor), const SizedBox(width: 4), Text(ev['time'] ?? 'TBD', style: GoogleFonts.outfit(fontSize: 13, color: subTextColor, fontWeight: FontWeight.w500)),
                const SizedBox(width: 12),
                Icon(Icons.location_on_outlined, size: 14, color: subTextColor), const SizedBox(width: 4), Expanded(child: Text(ev['location'] ?? '', style: GoogleFonts.outfit(fontSize: 13, color: subTextColor, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                if (!isPast) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => AdminQrScannerPage(
                          onScan: (memberId) => _handleCheckIn(ev['id'], memberId),
                        )));
                      },
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                      label: Text('Check-in', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold)),
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
                    icon: const Icon(Icons.people_alt_outlined, size: 16),
                    label: Text('Attendees', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade600,
                      side: BorderSide(color: Colors.blue.shade600.withValues(alpha: 0.5)),
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
                  child: OutlinedButton.icon(
                    onPressed: () => _openEdit(ev),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: Text('Edit', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kOrange,
                      side: BorderSide(color: _kOrange.withValues(alpha: 0.5)),
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _deleteEvent(ev['id']),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: Text('Delete', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kRed.withValues(alpha: 0.1),
                      foregroundColor: _kRed,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ]),
            ])),
          ]),
        );
      }),
      if (_loadingMore) Center(child: Padding(padding: const EdgeInsets.all(16), child: CircularProgressIndicator(color: _kOrange))),
      if (!_loading) Center(child: Padding(padding: const EdgeInsets.only(bottom: 24, top: 8), child: Text('${_events.length} events shown${_total > 0 ? " of $_total" : ""}', style: GoogleFonts.outfit(fontSize: 13, color: subTextColor, fontWeight: FontWeight.w500)))),
    ]);
  }

  void _viewAttendees(int eventId, String title) {
    context.push('/admin/events/$eventId/attendees?title=${Uri.encodeComponent(title)}');
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
              content: Text(res.data['message'] ?? 'Member checked in successfully!', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              backgroundColor: const Color(0xFF10b981),
            ));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(res.data['message'] ?? 'Failed to check in member', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              backgroundColor: _kRed,
            ));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('DioException') || e.runtimeType.toString() == 'DioException') {
          try {
            final dynamic dioErr = e;
            if (dioErr.response != null && dioErr.response.data != null) {
              final resData = dioErr.response.data;
              if (resData is Map && resData['member'] != null) {
                _showMemberVerification(resData['member'], false, resData['message']);
                setState(() => _loading = false);
                return;
              } else if (resData is Map && resData['message'] != null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(resData['message'], style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  backgroundColor: _kRed,
                ));
                setState(() => _loading = false);
                return;
              }
            }
          } catch (_) {}
        }
        
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to check in: $e', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
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

        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final cardBg = isDark ? const Color(0xFF1e293b) : Colors.white;
        final textColor = isDark ? const Color(0xFFf8fafc) : const Color(0xFF0f172a);
        final subTextColor = isDark ? const Color(0xFF94a3b8) : const Color(0xFF475569);

        return AlertDialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(32),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: subTextColor.withValues(alpha: 0.1),
                backgroundImage: member['profile_photo'] != null && member['profile_photo'].toString().isNotEmpty
                    ? NetworkImage(member['profile_photo'])
                    : null,
                child: member['profile_photo'] == null || member['profile_photo'].toString().isEmpty
                    ? Text((member['name'] ?? '?')[0].toUpperCase(), style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: subTextColor))
                    : null,
              ),
              const SizedBox(height: 20),
              
              Text(member['name'] ?? 'Unknown Member', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: textColor), textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(member['company'] ?? 'No Company', style: GoogleFonts.outfit(fontSize: 15, color: subTextColor), textAlign: TextAlign.center),
              if (member['license_number'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(member['license_number'], style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: _kOrange)),
                ),
              
              const SizedBox(height: 30),
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: isSuccess ? const Color(0xFF10b981).withValues(alpha: 0.1) : _kRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isSuccess ? const Color(0xFF10b981) : _kRed, width: 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(isSuccess ? Icons.check_circle_rounded : Icons.cancel_rounded, color: isSuccess ? const Color(0xFF10b981) : _kRed),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isSuccess ? 'ACCESS GRANTED' : (message ?? 'ACCESS DENIED'),
                        style: GoogleFonts.outfit(
                          color: isSuccess ? const Color(0xFF10b981) : _kRed,
                          fontWeight: FontWeight.bold,
                          fontSize: isSuccess ? 16 : 14,
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

  Widget _buildEditModal(Color cardBg, Color borderColor, Color textColor, Color subTextColor, Color inputBg, bool isDark) => Positioned.fill(
    child: Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(child: Container(
        margin: const EdgeInsets.all(20), padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Text('Edit Event', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)), const Spacer(), IconButton(icon: Icon(Icons.close_rounded, color: subTextColor), onPressed: () => setState(() => _editingEvent = null))]),
          const SizedBox(height: 20),
          _field('Title', _eTitleCtrl, textColor: textColor, subTextColor: subTextColor, borderColor: borderColor, inputBg: inputBg), const SizedBox(height: 16),
          _field('Venue', _eLocationCtrl, textColor: textColor, subTextColor: subTextColor, borderColor: borderColor, inputBg: inputBg), const SizedBox(height: 16),
          _field('Description', _eDescCtrl, maxLines: 3, textColor: textColor, subTextColor: subTextColor, borderColor: borderColor, inputBg: inputBg), const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(
            onPressed: _submitting ? null : _saveEdit,
            icon: _submitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_rounded, size: 18),
            label: Text(_submitting ? 'Saving...' : 'Save Changes', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          )),
        ]),
      )),
    ),
  );

  Widget _field(String label, TextEditingController ctrl, {String? hint, int maxLines = 1, required Color textColor, required Color subTextColor, required Color borderColor, required Color inputBg}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12, color: subTextColor)), const SizedBox(height: 6),
    TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: GoogleFonts.outfit(fontSize: 14, color: textColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.outfit(fontSize: 13, color: subTextColor),
        filled: true,
        fillColor: inputBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kOrange, width: 2)),
      ),
    ),
  ]);
}
