import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../components/app_layout.dart';
import '../components/custom_dropdown.dart';
import '../services/api_service.dart';
import '../components/fetch_error_view.dart';
import '../components/shimmer_loader.dart';

const _kOrange = Color(0xFFf08232);
const _kGreen  = Color(0xFF10b981);

const _kAmber  = Color(0xFFf59e0b);
const _kSlate  = Color(0xFF94a3b8);

class AdminTicketsPage extends StatefulWidget {
  const AdminTicketsPage({super.key});
  @override State<AdminTicketsPage> createState() => _State();
}

class _State extends State<AdminTicketsPage> {
  final _api = ApiService();
  List<dynamic> _tickets = [];
  dynamic _selected;

  String _tab = 'inbox';
  bool _sending = false;
  bool _loading = true;
  bool _hasError = false;

  int _page = 1;
  int _total = 0;
  bool _hasMore = true;

  final _replyCtrl = TextEditingController();

  @override void initState() { 
    super.initState(); 
    _fetch(page: 1); 
  }

  @override void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  void _onTabChanged(String newTab) {
    if (_tab == newTab) return;
    setState(() {
      _tab = newTab;
      _selected = null;
    });
    _fetch(page: 1);
  }

  Future<void> _fetch({int page = 1}) async {
    if (!mounted) return;
    setState(() { _page = page; _loading = true; });
    
    await _api.fetchDataWithCache('/tickets/admin/all?page=$_page&per_page=10&status=$_tab', (data, isCached, {bool hasError = false}) {
      if (!mounted) return;
      if (hasError && _tickets.isEmpty) {
        setState(() { _loading = false; _hasError = true; });
        return;
      }
      if (data == null) { setState(() => _loading = false); return; }
      final d = data as Map<String, dynamic>;
      setState(() { 
        _loading = false;
        _hasError = false;
        _tickets = ApiService.ensureList(d); 
        if (d.containsKey('total')) {
          _total = d['total'];
          _hasMore = (_page * 10) < _total;
        } else {
          _hasMore = false;
        }
        if (_selected != null) {
          _selected = _tickets.firstWhere((t) => t['id'] == _selected['id'], orElse: () => null);
        }
      });
    });
  }

  Future<void> _updateStatus(String status) async {
    if (_selected == null) return;
    await _api.putData('tickets/admin/${_selected['id']}/status', {'status': status});
    if (status == 'archived') setState(() => _selected = null);
    await _fetch(page: _page);
  }

  Future<void> _sendReply() async {
    if (_replyCtrl.text.trim().isEmpty || _selected == null) return;
    setState(() => _sending = true);
    await _api.postData('tickets/admin/${_selected['id']}/reply', {'message': _replyCtrl.text.trim()});
    _replyCtrl.clear();
    setState(() { _sending = false; });
    await _fetch(page: _page);
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'open':     return _kOrange;
      case 'pending':  return _kAmber;
      case 'resolved': return _kGreen;
      default:         return _kSlate;
    }
  }

  String _statusLabel(String s) => s[0].toUpperCase() + s.substring(1);

  List<dynamic> get _displayed => _tickets;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1e293b) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0);
    final textColor = isDark ? const Color(0xFFf8fafc) : const Color(0xFF0f172a);
    final subTextColor = isDark ? const Color(0xFF94a3b8) : const Color(0xFF475569);

    final tabs = [
      {'id': 'inbox',    'label': 'Inbox'},
      {'id': 'archived', 'label': 'Archived'},
    ];
    return AppLayout(
      title: 'Support Tickets',
      scrollable: _selected != null, // Make unscrollable when showing list to allow listview to scroll
      child: _selected != null 
          ? _buildReplyPanel(isDark, cardBg, borderColor, textColor, subTextColor) 
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        onTap: () => _onTabChanged(t['id']!),
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
                  _buildTicketList(isDark, cardBg, borderColor, textColor, subTextColor),
                ],
              ),
            ),
    );
  }

  Widget _buildTicketList(bool isDark, Color cardBg, Color borderColor, Color textColor, Color subTextColor) {
    if (_loading) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 8,
        separatorBuilder: (ctx, i) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) => const ShimmerListTile(),
      );
    }
    if (_displayed.isEmpty) {
      if (_hasError && _tickets.isEmpty) return FetchErrorView(onRetry: () => _fetch(page: 1));
      return Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: cardBg, 
          borderRadius: BorderRadius.circular(16), 
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            _tab == 'inbox' ? 'No open tickets.' : 'No archived tickets.', 
            style: GoogleFonts.outfit(color: subTextColor, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
    return Column(children: [
      Column(children: List.generate(_displayed.length, (i) {
        final ticket = _displayed[i];
        final color  = _statusColor(ticket['status'] ?? 'open');
        final idString = ticket['id'].toString();
        final shortId = idString.length > 6 
            ? idString.substring(idString.length - 6) 
            : idString;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => setState(() => _selected = ticket),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                // Status color bar indicator
                Container(
                  width: 4,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 14),
                // Main Content
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(
                      '#$shortId', 
                      style: GoogleFonts.outfit(
                        fontSize: 11, 
                        color: subTextColor, 
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), 
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08), 
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: color.withValues(alpha: 0.2)),
                      ), 
                      child: Text(
                        _statusLabel(ticket['status'] ?? 'open').toUpperCase(), 
                        style: GoogleFonts.outfit(
                          fontSize: 10, 
                          fontWeight: FontWeight.w800, 
                          color: color,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    ticket['member_name'] ?? '', 
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold, 
                      color: _kOrange, 
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    ticket['subject'] ?? '', 
                    overflow: TextOverflow.ellipsis, 
                    style: GoogleFonts.outfit(
                      fontSize: 13, 
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Opened: ${ticket['date'] ?? ''}', 
                    style: GoogleFonts.outfit(
                      fontSize: 11, 
                      color: subTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ])),
                const SizedBox(width: 12),
                Icon(Icons.chevron_right_rounded, color: subTextColor),
              ]),
            ),
          ),
        );
      })),
      
      // Pagination Controls
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: _page > 1 ? cardBg : Colors.transparent,
              border: Border.all(color: _page > 1 ? borderColor : borderColor.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              onPressed: _page > 1 ? () => _fetch(page: _page - 1) : null,
              icon: const Icon(Icons.chevron_left_rounded, size: 20),
              color: _kOrange,
              disabledColor: subTextColor.withValues(alpha: 0.4),
              tooltip: 'Previous Page',
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: cardBg,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.01),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Text(
              'Page $_page', 
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            decoration: BoxDecoration(
              color: _hasMore ? cardBg : Colors.transparent,
              border: Border.all(color: _hasMore ? borderColor : borderColor.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              onPressed: _hasMore ? () => _fetch(page: _page + 1) : null,
              icon: const Icon(Icons.chevron_right_rounded, size: 20),
              color: _kOrange,
              disabledColor: subTextColor.withValues(alpha: 0.4),
              tooltip: 'Next Page',
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
    ]);
  }

  Widget _buildReplyPanel(bool isDark, Color cardBg, Color borderColor, Color textColor, Color subTextColor) {
    final t = _selected!;
    final statusOptions = ['open', 'pending', 'resolved', 'archived'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1e293b) : Colors.grey.shade100,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 18), 
            color: textColor,
            onPressed: () => setState(() => _selected = null),
            tooltip: 'Back to list',
          ),
        ),
        const Spacer(),
        CustomDropdown<String>(
          value: t['status'] ?? 'open',
          width: 140,
          dense: true,
          items: statusOptions.map((s) => DropdownItem<String>(value: s, label: _statusLabel(s))).toList(),
          onChanged: (v) => _updateStatus(v),
        ),
      ]),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0f172a).withValues(alpha: 0.4) : const Color(0xFFf8fafc), 
          borderRadius: BorderRadius.circular(16), 
          border: Border.all(color: borderColor),
        ),
        child: Row(children: [
          Expanded(child: _meta('From', t['member_name'] ?? '', Icons.person_outline_rounded, isDark, textColor, subTextColor)),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: _meta('Subject', t['subject'] ?? '', Icons.mail_outline_rounded, isDark, textColor, subTextColor)),
          const SizedBox(width: 12),
          Expanded(child: _meta('Date', t['date'] ?? '', Icons.calendar_month_outlined, isDark, textColor, subTextColor)),
        ]),
      ),
      const SizedBox(height: 20),

      // Original message
      _bubble(t['message'] ?? '', 'MEMBER MESSAGE', false, isDark, cardBg, borderColor, textColor, subTextColor),

      // Replies
      if (t['replies'] != null) ...List<Widget>.from((t['replies'] as List).map((r) => _bubble(
        r['message'] ?? '',
        '${(r['author'] ?? 'User').toString().toUpperCase()} (${r['date'] ?? ''})',
        r['author']?.toString().toLowerCase() == 'admin',
        isDark,
        cardBg,
        borderColor,
        textColor,
        subTextColor,
      ))),

      const SizedBox(height: 20),
      // Archive button
      if (t['status'] != 'archived') Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.archive_outlined, size: 16), 
          label: Text('Move to Archive', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)), 
          onPressed: () => _updateStatus('archived'), 
          style: OutlinedButton.styleFrom(
            foregroundColor: subTextColor,
            side: BorderSide(color: borderColor),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ),
      const SizedBox(height: 16),

      // Reply form
      TextField(
        controller: _replyCtrl, 
        maxLines: 4, 
        style: GoogleFonts.outfit(color: textColor, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Type your reply...', 
          hintStyle: GoogleFonts.outfit(color: subTextColor),
          filled: true,
          fillColor: isDark ? const Color(0xFF0f172a).withValues(alpha: 0.4) : const Color(0xFFf8fafc),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), 
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), 
            borderSide: const BorderSide(color: _kOrange, width: 1.5),
          ),
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(
        onPressed: _sending ? null : _sendReply,
        icon: _sending 
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.send_rounded, size: 18),
        label: Text(
          _sending ? 'Sending...' : 'Send Reply', 
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _kOrange, 
          foregroundColor: Colors.white, 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      )),
      const SizedBox(height: 24),
    ]);
  }

  Widget _meta(String label, String val, IconData icon, bool isDark, Color textColor, Color subTextColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _kOrange.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: _kOrange),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label, 
                style: GoogleFonts.outfit(
                  fontSize: 10, 
                  fontWeight: FontWeight.bold, 
                  color: subTextColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                val, 
                style: GoogleFonts.outfit(
                  fontSize: 12, 
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bubble(String msg, String header, bool isMe, bool isDark, Color cardBg, Color borderColor, Color textColor, Color subTextColor) {
    final bubbleBg = isMe
        ? (isDark ? const Color(0xFF7c2d12).withValues(alpha: 0.15) : const Color(0xFFfff7ed))
        : (isDark ? const Color(0xFF1e293b) : const Color(0xFFf1f5f9));

    final bubbleBorderColor = isMe
        ? _kOrange.withValues(alpha: 0.3)
        : borderColor;

    final headerColor = isMe
        ? _kOrange
        : subTextColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: bubbleBg,
                border: Border.all(color: bubbleBorderColor),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.01),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    header, 
                    style: GoogleFonts.outfit(
                      fontSize: 10, 
                      fontWeight: FontWeight.bold, 
                      color: headerColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    msg, 
                    style: GoogleFonts.outfit(
                      fontSize: 13, 
                      color: textColor,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
