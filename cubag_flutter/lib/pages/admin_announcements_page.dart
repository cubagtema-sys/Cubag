import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../components/app_layout.dart';
import '../components/custom_dropdown.dart';
import '../services/api_service.dart';
import '../components/shimmer_loader.dart';

const _kOrange = Color(0xFFf08232);
const _kGreen  = Color(0xFF10b981);
const _kRed    = Color(0xFFef4444);

class AdminAnnouncementsPage extends StatefulWidget {
  const AdminAnnouncementsPage({super.key});
  @override State<AdminAnnouncementsPage> createState() => _State();
}

class _State extends State<AdminAnnouncementsPage> {
  final _api = ApiService();
  
  String _tab = 'history';
  String _category = 'General';
  String _msg = '';
  bool _submitting = false;

  final _titleCtrl = TextEditingController();
  final _bodyCtrl  = TextEditingController();
  
  // Pagination State for Active
  List<dynamic> _active = [];
  bool _loadingActive = true;
  int _pageActive = 1;
  bool _hasMoreActive = true;

  // Pagination State for Archived
  List<dynamic> _archived = [];
  bool _loadingArchived = true;
  int _pageArchived = 1;
  bool _hasMoreArchived = true;

  @override void initState() { 
    super.initState(); 
    _fetchActive(page: 1); 
    _fetchArchived(page: 1);
  }

  Future<void> _fetchActive({int page = 1}) async {
    setState(() { _pageActive = page; _loadingActive = true; });
    try {
      final res = await _api.get('/announcements/admin/all?archived=false&page=$_pageActive&limit=10');
      if (res.statusCode == 200) {
        final data = res.data;
        if (mounted) {
          setState(() {
          _active = ApiService.ensureList(data);
          if (data is Map && data.containsKey('total')) {
            _hasMoreActive = (_pageActive * 10) < data['total'];
          } else {
            _hasMoreActive = _active.length == 10;
          }
        });
        }
      }
    } catch (e) {
      debugPrint('Error fetching active announcements: $e');
    } finally {
      if (mounted) setState(() => _loadingActive = false);
    }
  }

  Future<void> _fetchArchived({int page = 1}) async {
    setState(() { _pageArchived = page; _loadingArchived = true; });
    try {
      final res = await _api.get('/announcements/admin/all?archived=true&page=$_pageArchived&limit=10');
      if (res.statusCode == 200) {
        final data = res.data;
        if (mounted) {
          setState(() {
          _archived = ApiService.ensureList(data);
          if (data is Map && data.containsKey('total')) {
            _hasMoreArchived = (_pageArchived * 10) < data['total'];
          } else {
            _hasMoreArchived = _archived.length == 10;
          }
        });
        }
      }
    } catch (e) {
      debugPrint('Error fetching archived announcements: $e');
    } finally {
      if (mounted) setState(() => _loadingArchived = false);
    }
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.isEmpty || _bodyCtrl.text.isEmpty) return;
    setState(() => _submitting = true);
    await _api.postData('announcements', {'title': _titleCtrl.text, 'body': _bodyCtrl.text, 'category': _category, 'posted_by': 'System Administrator'});
    _titleCtrl.clear(); _bodyCtrl.clear();
    setState(() => _category = 'General');
    await _fetchActive(page: 1);
    if (mounted) setState(() { _submitting = false; _msg = 'Announcement broadcasted!'; _tab = 'history'; });
    Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _msg = ''); });
  }

  Future<void> _delete(int id) async {
    // Optimistic update
    setState(() => _active.removeWhere((a) => a['id'] == id));
    try {
      await _api.deleteData('announcements/$id');
      setState(() => _msg = 'Archived successfully.');
      Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _msg = ''); });
      _fetchArchived(page: 1);
    } catch (_) {
      _fetchActive(page: _pageActive);
    }
  }

  Future<void> _restore(int id) async {
    // Optimistic update
    setState(() => _archived.removeWhere((a) => a['id'] == id));
    try {
      await _api.patchData('announcements/$id/restore', {});
      setState(() => _msg = 'Restored.');
      Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _msg = ''); });
      _fetchActive(page: 1);
    } catch (_) {
      _fetchArchived(page: _pageArchived);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1e293b) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0);
    final textColor = isDark ? const Color(0xFFcbd5e1) : const Color(0xFF0f172a);
    final subTextColor = isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b);

    final tabs = [
      {'id': 'create',   'label': 'New Broadcast'},
      {'id': 'history',  'label': 'History'},
      {'id': 'archived', 'label': 'Archived'},
    ];
    return AppLayout(
      title: 'Announcements',
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
                setState(() => _tab = t['id']!);
                if (t['id'] == 'history') _fetchActive(page: 1);
                if (t['id'] == 'archived') _fetchArchived(page: 1);
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

        // Toast
        if (_msg.isNotEmpty) AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), 
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: _kGreen.withValues(alpha: isDark ? 0.15 : 0.08), 
            borderRadius: BorderRadius.circular(12), 
            border: Border.all(color: _kGreen.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: _kGreen, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _msg, 
                  style: GoogleFonts.outfit(color: _kGreen, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
        ),

        if (_tab == 'create') _buildCreate(isDark, cardBg, borderColor, textColor, subTextColor),
        if (_tab == 'history') _buildList(_active, archived: false, loading: _loadingActive, page: _pageActive, hasMore: _hasMoreActive, onPage: (p) => _fetchActive(page: p), isDark: isDark, cardBg: cardBg, borderColor: borderColor, textColor: textColor, subTextColor: subTextColor),
        if (_tab == 'archived') _buildList(_archived, archived: true, loading: _loadingArchived, page: _pageArchived, hasMore: _hasMoreArchived, onPage: (p) => _fetchArchived(page: p), isDark: isDark, cardBg: cardBg, borderColor: borderColor, textColor: textColor, subTextColor: subTextColor),
      ]),
    );
  }

  Widget _buildCreate(bool isDark, Color cardBg, Color borderColor, Color textColor, Color subTextColor) => Container(
    constraints: const BoxConstraints(maxWidth: 600),
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
      Text(
        'Compose Broadcast Message', 
        style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16, color: textColor),
      ),
      const SizedBox(height: 20),
      Text(
        'ALERT TYPE', 
        style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 10, color: subTextColor, letterSpacing: 0.5),
      ),
      const SizedBox(height: 8),
      CustomDropdown<String>(
        value: _category,
        items: const [
          DropdownItem(value: 'General',             label: 'General'),
          DropdownItem(value: 'Urgent Alert',        label: 'Urgent Alert'),
          DropdownItem(value: 'System Maintenance',  label: 'System Maintenance'),
          DropdownItem(value: 'Event',               label: 'Event'),
        ],
        onChanged: (v) => setState(() => _category = v),
      ),
      const SizedBox(height: 18),
      Text(
        'SUBJECT', 
        style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 10, color: subTextColor, letterSpacing: 0.5),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _titleCtrl,
        style: GoogleFonts.outfit(fontSize: 13, color: textColor),
        decoration: InputDecoration(
          fillColor: isDark ? const Color(0xFF0f172a) : Colors.grey.withValues(alpha: 0.02),
          filled: true,
          hintText: 'Enter title...',
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
        ),
      ),
      const SizedBox(height: 18),
      Text(
        'CONTENT', 
        style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 10, color: subTextColor, letterSpacing: 0.5),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _bodyCtrl,
        maxLines: 5,
        style: GoogleFonts.outfit(fontSize: 13, color: textColor),
        decoration: InputDecoration(
          fillColor: isDark ? const Color(0xFF0f172a) : Colors.grey.withValues(alpha: 0.02),
          filled: true,
          hintText: 'Broadcast details...',
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
        ),
      ),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(
        onPressed: _submitting ? null : _submit,
        icon: _submitting 
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
            : const Icon(Icons.send_rounded, size: 18),
        label: Text('Broadcast Now', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _kOrange, 
          foregroundColor: Colors.white, 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), 
          elevation: 0,
        ),
      )),
    ]),
  );

  Widget _buildList(
    List items, {
    required bool archived, 
    required bool loading, 
    required int page, 
    required bool hasMore, 
    required Function(int) onPage,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color subTextColor,
  }) {
    if (loading) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        separatorBuilder: (ctx, i) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) => const ShimmerListTile(),
      );
    }
    if (items.isEmpty) {
      return Container(
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
                color: (archived ? _kRed : _kOrange).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                archived ? Icons.archive_outlined : Icons.campaign_outlined, 
                size: 32, 
                color: archived ? _kRed : _kOrange,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              archived ? 'No archived announcements.' : 'No announcements history.', 
              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 4),
            Text(
              archived ? 'Announcements you archive will appear here.' : 'Broadcasted announcements will be displayed in this feed.',
              style: GoogleFonts.outfit(fontSize: 12, color: subTextColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final catStyles = {
      'Urgent Alert':        {'bg': _kRed.withValues(alpha: 0.1), 'border': _kRed.withValues(alpha: 0.3), 'color': _kRed},
      'System Maintenance':  {'bg': Colors.amber.withValues(alpha: 0.1), 'border': Colors.amber.withValues(alpha: 0.3), 'color': Colors.amber.shade700},
      'Event':               {'bg': Colors.purple.withValues(alpha: 0.1), 'border': Colors.purple.withValues(alpha: 0.3), 'color': Colors.purple},
      'General':             {'bg': Colors.blue.withValues(alpha: 0.1), 'border': Colors.blue.withValues(alpha: 0.3), 'color': Colors.blue},
    };

    return Column(children: [
      ...items.map((ann) {
        final cat = ann['category'] ?? 'General';
        final style = catStyles[cat] ?? catStyles['General']!;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), 
                decoration: BoxDecoration(
                  color: style['bg'] as Color, 
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: style['border'] as Color),
                ), 
                child: Text(
                  cat.toUpperCase(), 
                  style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.w800, color: style['color'] as Color, letterSpacing: 0.5),
                ),
              ),
              const Spacer(),
              if (!archived) 
                IconButton(
                  icon: const Icon(Icons.archive_outlined, color: _kRed, size: 18), 
                  onPressed: () => _delete(ann['id']),
                  tooltip: 'Archive Announcement',
                  splashRadius: 20,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              if (archived) 
                OutlinedButton.icon(
                  icon: const Icon(Icons.settings_backup_restore_rounded, size: 14, color: _kGreen), 
                  label: Text('Restore', style: GoogleFonts.outfit(color: _kGreen, fontSize: 11, fontWeight: FontWeight.bold)), 
                  onPressed: () => _restore(ann['id']),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _kGreen.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
            ]),
            const SizedBox(height: 12),
            Text(
              ann['title'] ?? '', 
              style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 15, color: textColor),
            ),
            const SizedBox(height: 6),
            Text(
              ann['body'] ?? '', 
              maxLines: 3, 
              overflow: TextOverflow.ellipsis, 
              style: GoogleFonts.outfit(fontSize: 13, color: subTextColor, height: 1.4),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (isDark ? Colors.white24 : Colors.grey.shade200),
                  ),
                  child: Icon(Icons.person, size: 12, color: subTextColor),
                ),
                const SizedBox(width: 8),
                Text(
                  'Posted by: ${ann['posted_by'] ?? 'System Administrator'}', 
                  style: GoogleFonts.outfit(fontSize: 11, color: subTextColor, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ]),
        );
      }),
      
      // Pagination Controls
      if (items.isNotEmpty) ...[
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: page > 1 ? () => onPage(page - 1) : null,
              icon: const Icon(Icons.chevron_left_rounded, size: 16),
              label: Text('Previous', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kOrange,
                disabledForegroundColor: subTextColor.withValues(alpha: 0.5),
                side: BorderSide(color: page > 1 ? _kOrange.withValues(alpha: 0.5) : borderColor),
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
                'Page $page', 
                style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12, color: textColor),
              ),
            ),
            const SizedBox(width: 16),
            OutlinedButton.icon(
              onPressed: hasMore ? () => onPage(page + 1) : null,
              icon: const Icon(Icons.chevron_right_rounded, size: 16),
              label: Text('Next', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kOrange,
                disabledForegroundColor: subTextColor.withValues(alpha: 0.5),
                side: BorderSide(color: hasMore ? _kOrange.withValues(alpha: 0.5) : borderColor),
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
}
