import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../components/app_layout.dart';
import '../components/custom_dropdown.dart';
import '../components/fetch_error_view.dart';
import '../services/api_service.dart';
import '../components/shimmer_loader.dart';

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
  bool _hasError = false;
  String _tab = 'upload';
  String _type = 'vanning', _status = 'Scheduled';
  String _filterStatus = 'All', _filterType = 'All';

  int _page = 1;
  int _total = 0;
  bool _hasMore = true;

  final _containerCtrl    = TextEditingController();
  final _vesselCtrl       = TextEditingController();
  final _cargoCtrl        = TextEditingController();
  final _dateCtrl         = TextEditingController();
  final _portCtrl         = TextEditingController();
  final _originCtrl       = TextEditingController();
  final _destinationCtrl  = TextEditingController();

  @override void initState() { 
    super.initState(); 
    _fetch(page: 1); 
  }

  @override void dispose() {
    _containerCtrl.dispose();
    _vesselCtrl.dispose();
    _cargoCtrl.dispose();
    _dateCtrl.dispose();
    _portCtrl.dispose();
    _originCtrl.dispose();
    _destinationCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch({int page = 1}) async {
    if (!mounted) return;
    setState(() { _fetching = true; _page = page; });
    
    final String typeQuery = _filterType == 'All' ? '' : 'type=$_filterType&';
    final String statusQuery = 'status=$_filterStatus';
    
    await _api.fetchDataWithCache('schedules?$typeQuery$statusQuery&page=$_page&per_page=10', (data, isCached, {bool hasError = false}) {
      if (!mounted) return;
      if (hasError && _schedules.isEmpty) {
        setState(() { _fetching = false; _hasError = true; });
        return;
      }
      if (data == null) {
        setState(() => _fetching = false);
        return;
      }
      setState(() {
        _fetching = false;
        _hasError = false;
        if (data is Map) {
          _schedules = ApiService.ensureList(data);
          if (data.containsKey('total')) {
            _total = data['total'];
            _hasMore = (_page * 10) < _total;
          } else {
            _hasMore = false;
          }
        } else {
          _schedules = ApiService.ensureList(data);
          _hasMore = false;
        }
      });
    });
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
    await _fetch(page: 1);
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

  List<dynamic> get _displayed => _schedules;

  @override
  Widget build(BuildContext context) {
    final tabs = [{'id': 'upload', 'label': 'New Entry'}, {'id': 'history', 'label': 'History'}];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1e293b) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0);
    final textColor = isDark ? const Color(0xFFcbd5e1) : const Color(0xFF0f172a);
    final subTextColor = isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b);

    return AppLayout(
      title: 'Cargo Schedules',
      scrollable: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Tab bar
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0f172a) : Colors.grey.shade100, 
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(children: tabs.map((t) {
            final active = _tab == t['id'];
            return Expanded(child: GestureDetector(
              onTap: () {
                if (_tab != t['id']) {
                  setState(() => _tab = t['id']!);
                  if (t['id'] == 'history') _fetch(page: 1);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? _kOrange : Colors.transparent, 
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: active ? [
                    BoxShadow(
                      color: _kOrange.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ] : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  t['label']!, 
                  style: GoogleFonts.outfit(
                    color: active ? Colors.white : subTextColor, 
                    fontWeight: FontWeight.bold, 
                    fontSize: 12,
                  ),
                ),
              ),
            ));
          }).toList()),
        ),
        const SizedBox(height: 16),

        if (_tab == 'upload') _buildUploadTab(isDark, cardBg, borderColor, textColor, subTextColor),
        if (_tab == 'history') _buildHistoryTab(isDark, cardBg, borderColor, textColor, subTextColor),
      ]),
    );
  }

  Widget _buildUploadTab(bool isDark, Color cardBg, Color borderColor, Color textColor, Color subTextColor) => Container(
    constraints: const BoxConstraints(maxWidth: 700),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: cardBg, 
      borderRadius: BorderRadius.circular(16), 
      border: Border.all(color: borderColor),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_success) 
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 16), 
          padding: const EdgeInsets.all(12), 
          decoration: BoxDecoration(
            color: _kGreen.withValues(alpha: isDark ? 0.15 : 0.08), 
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kGreen.withValues(alpha: 0.3)),
          ), 
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: _kGreen, size: 18),
              const SizedBox(width: 8),
              Text(
                'Published successfully!', 
                style: GoogleFonts.outfit(color: _kGreen, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        ),
      _label('Type', subTextColor), const SizedBox(height: 8),
      CustomDropdown<String>(
        value: _type,
        items: const [
          DropdownItem(value: 'vanning',   label: 'Vanning (Loading)'),
          DropdownItem(value: 'devanning', label: 'Devanning (Unloading)'),
          DropdownItem(value: 'movement',  label: 'Vessel Movement'),
        ],
        onChanged: (v) => setState(() => _type = v),
      ),
      const SizedBox(height: 18),
      _label('Container ID', subTextColor), const SizedBox(height: 8),
      TextField(
        controller: _containerCtrl, 
        style: GoogleFonts.outfit(fontSize: 13, color: textColor),
        decoration: _deco(hint: 'MSCU...', isDark: isDark, borderColor: borderColor, subTextColor: subTextColor),
      ),
      const SizedBox(height: 18),
      _label('Vessel Name', subTextColor), const SizedBox(height: 8),
      TextField(
        controller: _vesselCtrl, 
        style: GoogleFonts.outfit(fontSize: 13, color: textColor),
        decoration: _deco(hint: 'Vessel...', isDark: isDark, borderColor: borderColor, subTextColor: subTextColor),
      ),
      const SizedBox(height: 18),
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label('Date', subTextColor), 
          const SizedBox(height: 8), 
          TextField(
            controller: _dateCtrl, 
            style: GoogleFonts.outfit(fontSize: 13, color: textColor),
            decoration: _deco(hint: '10 May', isDark: isDark, borderColor: borderColor, subTextColor: subTextColor),
          ),
        ])),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label('Port', subTextColor), 
          const SizedBox(height: 8), 
          TextField(
            controller: _portCtrl, 
            style: GoogleFonts.outfit(fontSize: 13, color: textColor),
            decoration: _deco(hint: 'Tema', isDark: isDark, borderColor: borderColor, subTextColor: subTextColor),
          ),
        ])),
      ]),
      const SizedBox(height: 18),
      _label('Status', subTextColor), const SizedBox(height: 8),
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
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Origin', subTextColor), 
            const SizedBox(height: 8), 
            TextField(
              controller: _originCtrl, 
              style: GoogleFonts.outfit(fontSize: 13, color: textColor),
              decoration: _deco(hint: 'Origin port...', isDark: isDark, borderColor: borderColor, subTextColor: subTextColor),
            ),
          ])),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Destination', subTextColor), 
            const SizedBox(height: 8), 
            TextField(
              controller: _destinationCtrl, 
              style: GoogleFonts.outfit(fontSize: 13, color: textColor),
              decoration: _deco(hint: 'Destination port...', isDark: isDark, borderColor: borderColor, subTextColor: subTextColor),
            ),
          ])),
        ]),
      ],
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(
        onPressed: _loading ? null : _upload,
        icon: Icon(_loading ? Icons.sync_rounded : Icons.upload_rounded, size: 18),
        label: Text(_loading ? 'Publishing...' : 'Upload to Portal', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _kOrange, 
          foregroundColor: Colors.white, 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      )),
    ]),
  );

  Widget _buildHistoryTab(bool isDark, Color cardBg, Color borderColor, Color textColor, Color subTextColor) {
    if (_fetching) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 8,
        separatorBuilder: (ctx, i) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) => const ShimmerListTile(),
      );
    }
    if (_hasError) {
      return FetchErrorView(onRetry: () => _fetch(page: _page));
    }
    return Column(children: [
      Row(children: [
        Expanded(
          child: CustomDropdown<String>(
            value: _filterType,
            items: const [
              DropdownItem(value: 'All', label: 'All Types'),
              DropdownItem(value: 'vanning', label: 'Vanning'),
              DropdownItem(value: 'devanning', label: 'Devanning'),
              DropdownItem(value: 'movement', label: 'Vessel Movement'),
            ],
            onChanged: (v) {
              setState(() => _filterType = v);
              _fetch(page: 1);
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: CustomDropdown<String>(
            value: _filterStatus,
            items: const [
              DropdownItem(value: 'All', label: 'All Statuses'),
              DropdownItem(value: 'Scheduled', label: 'Scheduled'),
              DropdownItem(value: 'In Progress', label: 'In Progress'),
              DropdownItem(value: 'Completed', label: 'Completed'),
              DropdownItem(value: 'Cancelled', label: 'Cancelled'),
            ],
            onChanged: (v) {
              setState(() => _filterStatus = v);
              _fetch(page: 1);
            },
          ),
        ),
      ]),
      const SizedBox(height: 16),

      if (_displayed.isEmpty) 
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24), 
          decoration: BoxDecoration(
            color: cardBg, 
            borderRadius: BorderRadius.circular(16), 
            border: Border.all(color: borderColor),
          ), 
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _kOrange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.inventory_2_outlined, size: 32, color: _kOrange),
              ),
              const SizedBox(height: 16),
              Text(
                'No schedules found.', 
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 4),
              Text(
                'Schedules added will list here.',
                style: GoogleFonts.outfit(fontSize: 12, color: subTextColor),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        )
      else
        ..._displayed.map((s) {
          final color = _statusColor(s['status'] ?? 'Scheduled');
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: cardBg, 
              borderRadius: BorderRadius.circular(16), 
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(height: 4, color: color),
              Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 44, 
                    height: 44, 
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1), 
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withValues(alpha: 0.15)),
                    ), 
                    child: Icon(_typeIcon(s['type'] ?? ''), color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      s['vessel'] ?? '', 
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14, color: textColor), 
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s['container'] ?? '', 
                      style: GoogleFonts.outfit(fontSize: 11, color: subTextColor, fontWeight: FontWeight.w600),
                    ),
                  ])),
                ]),
                const SizedBox(height: 14),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _pill(Icons.location_on_outlined, s['port'] ?? '', subTextColor),
                  _pill(Icons.calendar_today_rounded, s['date'] ?? '', subTextColor),
                  _pill(
                    Icons.category_rounded, 
                    s['type']?.toString().toUpperCase() ?? '', 
                    _kOrange,
                    color: _kOrange,
                    isDark: isDark,
                  ),
                ]),
                const Divider(height: 28),
                Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: () => _showStatusPicker(s, isDark, cardBg, borderColor, textColor, subTextColor),
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
                        color: color.withValues(alpha: 0.08),
                      ),
                      child: Row(children: [
                        Container(
                          width: 8, 
                          height: 8, 
                          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(
                          s['status'] ?? 'Scheduled', 
                          style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: color),
                        )),
                        Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: color),
                      ]),
                    ),
                  )),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: _kRed), 
                    onPressed: () => _delete(s['id']),
                    splashRadius: 22,
                    tooltip: 'Delete Entry',
                  ),
                ]),
              ])),
            ]),
          );
        }),
      
      // Pagination Controls
      if (_displayed.isNotEmpty) ...[
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _page > 1 ? () => _fetch(page: _page - 1) : null,
              icon: const Icon(Icons.chevron_left_rounded, size: 16),
              label: Text('Previous', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kOrange,
                disabledForegroundColor: subTextColor.withValues(alpha: 0.5),
                side: BorderSide(color: _page > 1 ? _kOrange.withValues(alpha: 0.5) : borderColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0f172a) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: Text(
                'Page $_page', 
                style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12, color: textColor),
              ),
            ),
            const SizedBox(width: 16),
            OutlinedButton.icon(
              onPressed: _hasMore ? () => _fetch(page: _page + 1) : null,
              icon: const Icon(Icons.chevron_right_rounded, size: 16),
              label: Text('Next', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kOrange,
                disabledForegroundColor: subTextColor.withValues(alpha: 0.5),
                side: BorderSide(color: _hasMore ? _kOrange.withValues(alpha: 0.5) : borderColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    ]);
  }

  void _showStatusPicker(dynamic schedule, bool isDark, Color cardBg, Color borderColor, Color textColor, Color subTextColor) {
    const statuses = ['Scheduled', 'In Progress', 'Completed', 'Cancelled'];
    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      barrierColor: Colors.black.withValues(alpha: isDark ? 0.6 : 0.4),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Update Cargo Status', 
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16, color: textColor),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: subTextColor, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                  splashRadius: 20,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...statuses.map((s) {
              final isActive = schedule['status'] == s;
              final color = _statusColor(s);
              return GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  _updateStatus(schedule['id'], s);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isActive ? color.withValues(alpha: isDark ? 0.2 : 0.08) : (isDark ? const Color(0xFF0f172a) : Colors.grey.withValues(alpha: 0.02)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive ? color : borderColor, 
                      width: isActive ? 2 : 1,
                    ),
                  ),
                  child: Row(children: [
                    Container(
                      width: 10, 
                      height: 10, 
                      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(
                      s, 
                      style: GoogleFonts.outfit(
                        fontWeight: isActive ? FontWeight.bold : FontWeight.w600, 
                        color: isActive ? color : textColor,
                        fontSize: 13,
                      ),
                    )),
                    if (isActive) Icon(Icons.check_circle_rounded, color: color, size: 18),
                  ]),
                ),
              );
            }),
          ]),
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String text, Color defaultColor, {Color? color, bool isDark = false}) {
    final textColor = color ?? defaultColor;
    final bg = color != null ? color.withValues(alpha: isDark ? 0.15 : 0.08) : Colors.transparent;
    final borderCol = color != null ? color.withValues(alpha: 0.25) : Colors.transparent;
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: color != null ? 8 : 0, vertical: color != null ? 3 : 0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: color != null ? Border.all(color: borderCol) : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: textColor),
        const SizedBox(width: 4),
        Text(text, style: GoogleFonts.outfit(fontSize: 11, color: textColor, fontWeight: color != null ? FontWeight.bold : FontWeight.w600)),
      ]),
    );
  }

  Widget _label(String t, Color color) => Text(
    t.toUpperCase(), 
    style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 10, color: color, letterSpacing: 0.5),
  );

  InputDecoration _deco({required String hint, required bool isDark, required Color borderColor, required Color subTextColor}) => InputDecoration(
    fillColor: isDark ? const Color(0xFF0f172a) : Colors.grey.withValues(alpha: 0.02),
    filled: true,
    hintText: hint, 
    hintStyle: GoogleFonts.outfit(fontSize: 13, color: subTextColor),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12), 
      borderSide: BorderSide(color: borderColor, width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12), 
      borderSide: const BorderSide(color: _kOrange, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}
