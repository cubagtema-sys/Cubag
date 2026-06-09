import 'package:flutter/material.dart';
import '../components/app_layout.dart';
import '../components/custom_dropdown.dart';
import '../services/api_service.dart';

const _kOrange = Color(0xFFf08232);
const _kGreen  = Color(0xFF10b981);
const _kRed    = Color(0xFFef4444);

class AdminCargoSchedulesPage extends StatefulWidget {
  const AdminCargoSchedulesPage({super.key});
  @override State<AdminCargoSchedulesPage> createState() => _State();
}

class _State extends State<AdminCargoSchedulesPage> {
  final _api = ApiService();
  List<dynamic> _schedules = [];
  bool _loading = false, _success = false;
  bool _fetching = true;
  String _tab = 'upload';
  String _type = 'vanning', _status = 'Scheduled';
  final String _filterStatus = 'All', _filterType = 'All';

  final _containerCtrl    = TextEditingController();
  final _vesselCtrl       = TextEditingController();
  final _cargoCtrl        = TextEditingController();
  final _dateCtrl         = TextEditingController();
  final _portCtrl         = TextEditingController();
  final _originCtrl       = TextEditingController();
  final _destinationCtrl  = TextEditingController();

  @override void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() => _fetching = true);
    try {
      final raw = await _api.fetchData('schedules');
      final data = ApiService.ensureList(raw);
      if (mounted) setState(() => _schedules = data);
    } catch (_) {}
    if (mounted) setState(() => _fetching = false);
  }

  Future<void> _upload() async {
    setState(() => _loading = true);
    await _api.postData('schedules', {
      'type': _type, 'container': _containerCtrl.text,
      'vessel': _vesselCtrl.text, 'cargo': _cargoCtrl.text,
      'date': _dateCtrl.text, 'port': _portCtrl.text,
      'status': _status, 'origin': _originCtrl.text, 'destination': _destinationCtrl.text,
    });
    // Clear form fields
    _containerCtrl.clear();
    _vesselCtrl.clear();
    _cargoCtrl.clear();
    _dateCtrl.clear();
    _portCtrl.clear();
    _originCtrl.clear();
    _destinationCtrl.clear();
    setState(() { _type = 'vanning'; _status = 'Scheduled'; });
    // Fetch latest data THEN switch tab
    await _fetch();
    if (mounted) setState(() { _loading = false; _success = true; _tab = 'history'; });
    Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _success = false); });
  }

  Future<void> _updateStatus(dynamic id, String s) async {
    setState(() => _schedules = _schedules.map((sc) => sc['id'] == id ? {...sc, 'status': s} : sc).toList());
    await _api.patchData('schedules/$id', {'status': s});
  }

  Future<void> _delete(dynamic id) async {
    await _api.deleteData('schedules/$id');
    setState(() => _schedules.removeWhere((s) => s['id'] == id));
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'In Progress': return const Color(0xFFf59e0b);
      case 'Completed':   return _kGreen;
      case 'Cancelled':   return _kRed;
      default:            return const Color(0xFF3b82f6);
    }
  }

  IconData _typeIcon(String t) {
    switch (t) {
      case 'devanning': return Icons.unarchive;
      case 'movement':  return Icons.directions_boat;
      default:          return Icons.inventory_2;
    }
  }

  List<dynamic> get _displayed => _schedules.where((s) {
    final sm = _filterStatus == 'All' || s['status'] == _filterStatus;
    final tm = _filterType == 'All'   || s['type']   == _filterType;
    return sm && tm;
  }).toList();

  @override
  Widget build(BuildContext context) {
    final tabs = [{'id': 'upload', 'label': 'New Entry'}, {'id': 'history', 'label': 'History (${_schedules.length})'}];
    return AppLayout(
      title: 'Cargo Schedules',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [


        // Tab bar
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
                decoration: BoxDecoration(color: active ? _kOrange : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center,
                child: Text(t['label']!, style: TextStyle(color: active ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ));
          }).toList()),
        ),
        const SizedBox(height: 16),

        if (_tab == 'upload') _buildUploadTab(),
        if (_tab == 'history') _buildHistoryTab(),
      ]),
    );
  }

  Widget _buildUploadTab() => Container(
    constraints: const BoxConstraints(maxWidth: 700),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_success) Container(margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _kGreen.withAlpha(25), borderRadius: BorderRadius.circular(10)), child: const Text('Published successfully!', style: TextStyle(color: _kGreen, fontWeight: FontWeight.w700))),
      _label('Type'), const SizedBox(height: 6),
      CustomDropdown<String>(
        value: _type,
        items: const [
          DropdownItem(value: 'vanning',   label: 'Vanning (Loading)'),
          DropdownItem(value: 'devanning', label: 'Devanning (Unloading)'),
          DropdownItem(value: 'movement',  label: 'Vessel Movement'),
        ],
        onChanged: (v) => setState(() => _type = v),
      ),
      const SizedBox(height: 14),
      _label('Container ID'), const SizedBox(height: 6),
      TextField(controller: _containerCtrl, decoration: _deco(hint: 'MSCU...')),
      const SizedBox(height: 14),
      _label('Vessel Name'), const SizedBox(height: 6),
      TextField(controller: _vesselCtrl, decoration: _deco(hint: 'Vessel...')),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('Date'), const SizedBox(height: 6), TextField(controller: _dateCtrl, decoration: _deco(hint: '10 May'))])),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('Port'), const SizedBox(height: 6), TextField(controller: _portCtrl, decoration: _deco(hint: 'Tema'))])),
      ]),
      const SizedBox(height: 14),
      _label('Status'), const SizedBox(height: 6),
      CustomDropdown<String>(
        value: _status,
        items: const [
          DropdownItem(value: 'Scheduled',   label: 'Scheduled'),
          DropdownItem(value: 'In Progress', label: 'In Progress'),
          DropdownItem(value: 'Completed',   label: 'Completed'),
          DropdownItem(value: 'Cancelled',   label: 'Cancelled'),
        ],
        onChanged: (v) => setState(() => _status = v),
      ),
      if (_type == 'movement') ...[
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('Origin'), const SizedBox(height: 6), TextField(controller: _originCtrl, decoration: _deco())])),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('Destination'), const SizedBox(height: 6), TextField(controller: _destinationCtrl, decoration: _deco())])),
        ]),
      ],
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(
        onPressed: _loading ? null : _upload,
        icon: const Icon(Icons.upload),
        label: Text(_loading ? 'Publishing...' : 'Upload to Portal', style: const TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(backgroundColor: _kOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      )),
    ]),
  );

  Widget _buildHistoryTab() {
    if (_fetching) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator(color: _kOrange)),
      );
    }
    if (_displayed.isEmpty) return Container(padding: const EdgeInsets.all(48), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)), child: const Center(child: Text('No schedules found.', style: TextStyle(color: Colors.grey))));
    return Column(children: _displayed.map((s) {
      final color = _statusColor(s['status'] ?? 'Scheduled');
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(height: 3, color: color),
          Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(10)), child: Icon(_typeIcon(s['type'] ?? ''), color: color, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s['vessel'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
                Text(s['container'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ])),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 12, children: [
              _pill(Icons.location_on_outlined, s['port'] ?? ''),
              _pill(Icons.calendar_today, s['date'] ?? ''),
              _pill(Icons.category, s['type']?.toString().toUpperCase() ?? '', color: _kOrange),
            ]),
            const Divider(height: 20),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => _showStatusPicker(s),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _statusColor(s['status'] ?? 'Scheduled'), width: 1.5),
                    color: _statusColor(s['status'] ?? 'Scheduled').withAlpha(15),
                  ),
                  child: Row(children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: _statusColor(s['status'] ?? 'Scheduled'))),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s['status'] ?? 'Scheduled', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _statusColor(s['status'] ?? 'Scheduled')))),
                    Icon(Icons.keyboard_arrow_down, size: 18, color: _statusColor(s['status'] ?? 'Scheduled')),
                  ]),
                ),
              )),
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.delete_outline, color: _kRed), onPressed: () => _delete(s['id'])),
            ]),
          ])),
        ]),
      );
    }).toList());
  }

  void _showStatusPicker(dynamic schedule) {
    const statuses = ['Scheduled', 'In Progress', 'Completed', 'Cancelled'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Update Status', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 12),
            ...statuses.map((s) {
              final isActive = schedule['status'] == s;
              final color = _statusColor(s);
              return GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  _updateStatus(schedule['id'], s);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isActive ? color.withAlpha(20) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isActive ? color : Colors.grey.shade200, width: isActive ? 2 : 1),
                  ),
                  child: Row(children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(s, style: TextStyle(fontWeight: isActive ? FontWeight.w800 : FontWeight.w600, color: isActive ? color : const Color(0xFF0f172a)))),
                    if (isActive) Icon(Icons.check_circle, color: color, size: 20),
                  ]),
                ),
              );
            }),
          ]),
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String text, {Color? color}) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: color ?? Colors.grey), const SizedBox(width: 4), Text(text, style: TextStyle(fontSize: 12, color: color ?? Colors.grey))]);
  Widget _label(String t) => Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12));
  InputDecoration _deco({String? hint}) => InputDecoration(hintText: hint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.all(12));
}
