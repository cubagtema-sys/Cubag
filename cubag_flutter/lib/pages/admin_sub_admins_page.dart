import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../components/app_layout.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

// All available permission modules — must match backend ALL_PERMISSIONS list.
const _kAllPermissions = [
  'members', 'payments', 'tickets', 'announcements',
  'schedules', 'events', 'surveys', 'intelligence', 'audit_log',
  'fees', 'settings',
];

const _kPermissionLabels = {
  'members':          'Member Management',
  'payments':         'Financial Center',
  'tickets':          'Support Tickets',
  'announcements':    'Announcements',
  'schedules':        'Cargo Schedules',
  'events':           'Events',
  'surveys':          'Surveys & Elections',
  'intelligence':     'Intelligence Hub',
  'audit_log':        'Audit Log',
  'fees':             'Platform Fees',
  'settings':         'Settings',
};

const _kPermissionIcons = {
  'members':          Icons.people_outline_rounded,
  'payments':         Icons.payments_outlined,
  'tickets':          Icons.support_agent_outlined,
  'announcements':    Icons.campaign_outlined,
  'schedules':        Icons.local_shipping_outlined,
  'events':           Icons.event_outlined,
  'surveys':          Icons.how_to_vote_outlined,
  'intelligence':     Icons.cell_tower_rounded,
  'audit_log':        Icons.history_outlined,
  'fees':             Icons.request_quote_outlined,
  'settings':         Icons.settings_outlined,
};

// Preset role templates
class _RoleTemplate {
  final String id, label, description;
  final IconData icon;
  final Color color;
  final List<String> permissions;
  const _RoleTemplate({required this.id, required this.label, required this.description, required this.icon, required this.color, required this.permissions});
}

const _kRoleTemplates = [
  _RoleTemplate(
    id: 'membership',
    label: 'Membership Officer',
    description: 'Member onboarding, status & support',
    icon: Icons.badge_outlined,
    color: Color(0xFF3b82f6),
    permissions: ['members', 'payments', 'tickets', 'announcements'],
  ),
  _RoleTemplate(
    id: 'finance',
    label: 'Finance Officer',
    description: 'Payments, dues & fee configuration',
    icon: Icons.account_balance_outlined,
    color: Color(0xFF10b981),
    permissions: ['payments', 'fees', 'members'],
  ),
  _RoleTemplate(
    id: 'communications',
    label: 'Communications',
    description: 'Announcements, events & public content',
    icon: Icons.campaign_outlined,
    color: Color(0xFFf59e0b),
    permissions: ['announcements', 'events', 'intelligence'],
  ),
  _RoleTemplate(
    id: 'operations',
    label: 'Operations Support',
    description: 'Tickets, schedules & member queries',
    icon: Icons.support_agent_outlined,
    color: Color(0xFF8b5cf6),
    permissions: ['tickets', 'schedules', 'members', 'announcements'],
  ),
];

class AdminSubAdminsPage extends StatefulWidget {
  const AdminSubAdminsPage({super.key});
  @override
  State<AdminSubAdminsPage> createState() => _AdminSubAdminsPageState();
}

class _AdminSubAdminsPageState extends State<AdminSubAdminsPage> {
  bool _loading = true;
  List<dynamic> _subAdmins = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final res = await ApiService().get('/sub-admins/');
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() { _subAdmins = res.data['sub_admins'] ?? []; });
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      backgroundColor: error ? const Color(0xFFef4444) : const Color(0xFF10b981),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _remove(Map<String, dynamic> sa, Color cardBg, Color borderColor, Color textColor, Color subTextColor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: borderColor)),
        title: Text('Remove Sub-Admin', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor)),
        content: Text('Demote ${sa['name']} back to a regular member?\nAll their permissions will be revoked.', style: GoogleFonts.outfit(color: subTextColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Cancel', style: GoogleFonts.outfit(color: subTextColor, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFef4444),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Remove', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final res = await ApiService().delete('/sub-admins/${sa['id']}');
      if (res.statusCode == 200) {
        _toast('${sa['name']} demoted to member');
        _fetch();
      } else {
        _toast(res.data['message'] ?? 'Error removing sub-admin', error: true);
      }
    } catch (_) {
      _toast('Network error', error: true);
    }
  }

  void _showCreateSheet(bool isDark, Color cardBg, Color borderColor, Color textColor, Color subTextColor, Color inputBg) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateSubAdminSheet(
        isDark: isDark, cardBg: cardBg, borderColor: borderColor, textColor: textColor, subTextColor: subTextColor, inputBg: inputBg,
        onCreated: () { Navigator.pop(ctx); _fetch(); }
      ),
    );
  }

  void _showEditSheet(Map<String, dynamic> sa, bool isDark, Color cardBg, Color borderColor, Color textColor, Color subTextColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditPermissionsSheet(
        subAdmin: sa,
        isDark: isDark, cardBg: cardBg, borderColor: borderColor, textColor: textColor, subTextColor: subTextColor,
        onSaved: () { Navigator.pop(ctx); _fetch(); }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final auth = Provider.of<AuthService>(context, listen: false);
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1e293b) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0);
    final textColor = isDark ? const Color(0xFFf8fafc) : const Color(0xFF0f172a);
    final subTextColor = isDark ? const Color(0xFF94a3b8) : const Color(0xFF475569);
    final inputBg = isDark ? const Color(0xFF0f172a).withValues(alpha: 0.4) : const Color(0xFFf8fafc);

    // Only full admins may access this page
    if (auth.userRole != 'admin') {
      return AppLayout(
        title: 'Sub-Admins',
        child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.lock_outline_rounded, size: 48, color: subTextColor.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text('Full admin access required', style: GoogleFonts.outfit(color: subTextColor, fontSize: 16)),
        ])),
      );
    }

    return AppLayout(
      title: 'Sub-Admin Management',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [primary, primary.withValues(alpha: isDark ? 0.4 : 0.7)]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Sub-Admin Accounts', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              Text('${_subAdmins.length} sub-admin(s) configured', style: GoogleFonts.outfit(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
            ])),
            ElevatedButton.icon(
              onPressed: () => _showCreateSheet(isDark, cardBg, borderColor, textColor, subTextColor, inputBg),
              icon: const Icon(Icons.person_add_rounded, size: 18, color: Colors.white),
              label: Text('Add Sub-Admin', style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 20),

        // Info card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primary.withValues(alpha: 0.3)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline_rounded, color: primary, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(
              'Sub-admins can log in and access only the modules you grant them. '
              'They cannot create other sub-admins, manage fees, or access the full audit trail unless explicitly permitted.',
              style: GoogleFonts.outfit(fontSize: 13, color: isDark ? Colors.white70 : const Color(0xFF475569), height: 1.5),
            )),
          ]),
        ),

        const SizedBox(height: 24),

        // List
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()))
        else if (_subAdmins.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(children: [
              Icon(Icons.admin_panel_settings_rounded, size: 56, color: subTextColor.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text('No sub-admins yet.\nTap "Add Sub-Admin" to create one.', textAlign: TextAlign.center, style: GoogleFonts.outfit(color: subTextColor, fontSize: 14)),
            ]),
          ))
        else
          ...(_subAdmins.map((sa) {
            final perms = List<String>.from(sa['permissions'] ?? []);
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.03), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Header row
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: primary.withValues(alpha: 0.15),
                      child: Text(
                        (sa['name']?.toString() ?? '?').substring(0, 1).toUpperCase(),
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: primary, fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(sa['name']?.toString() ?? '', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                      Text(sa['email']?.toString() ?? '', style: GoogleFonts.outfit(fontSize: 13, color: subTextColor)),
                      const SizedBox(height: 6),
                      Builder(builder: (_) {
                        // Match permissions to a template label
                        final permsSet = Set<String>.from(perms);
                        final match = _kRoleTemplates.cast<_RoleTemplate?>().firstWhere(
                          (t) => t != null && Set<String>.from(t.permissions).difference(permsSet).isEmpty && permsSet.difference(Set<String>.from(t.permissions)).isEmpty,
                          orElse: () => null,
                        );
                        final label = match?.label ?? (perms.isEmpty ? 'No access' : 'Custom');
                        final color = match?.color ?? (perms.isEmpty ? const Color(0xFFef4444) : const Color(0xFF6366f1));
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.3))),
                          child: Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5)),
                        );
                      }),
                    ])),
                    // Edit button
                    IconButton(
                      icon: Icon(Icons.edit_rounded, size: 20, color: subTextColor),
                      tooltip: 'Edit permissions',
                      onPressed: () => _showEditSheet(Map<String, dynamic>.from(sa), isDark, cardBg, borderColor, textColor, subTextColor),
                    ),
                    IconButton(
                      icon: const Icon(Icons.person_remove_rounded, size: 20, color: Color(0xFFef4444)),
                      tooltip: 'Remove sub-admin',
                      onPressed: () => _remove(Map<String, dynamic>.from(sa), cardBg, borderColor, textColor, subTextColor),
                    ),
                  ]),
                ),

                // Permissions chips
                if (perms.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text('No permissions granted', style: GoogleFonts.outfit(fontSize: 13, color: Colors.orange.shade700, fontStyle: FontStyle.italic)),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Wrap(spacing: 8, runSpacing: 8, children: perms.map((p) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: primary.withValues(alpha: 0.2))),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_kPermissionIcons[p] ?? Icons.check_rounded, size: 14, color: primary),
                        const SizedBox(width: 6),
                        Text(_kPermissionLabels[p] ?? p, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: primary)),
                      ]),
                    )).toList()),
                  ),
              ]),
            );
          })),
      ]),
    );
  }
}

// ── Create Sub-Admin bottom sheet ──────────────────────────────────────────────
class _CreateSubAdminSheet extends StatefulWidget {
  final VoidCallback onCreated;
  final bool isDark;
  final Color cardBg;
  final Color borderColor;
  final Color textColor;
  final Color subTextColor;
  final Color inputBg;

  const _CreateSubAdminSheet({
    required this.onCreated,
    required this.isDark,
    required this.cardBg,
    required this.borderColor,
    required this.textColor,
    required this.subTextColor,
    required this.inputBg,
  });
  @override
  State<_CreateSubAdminSheet> createState() => _CreateSubAdminSheetState();
}

class _CreateSubAdminSheetState extends State<_CreateSubAdminSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final Set<String> _selectedPerms = {};
  String? _selectedTemplate; // id of active template
  bool _loading = false;
  bool _obscure = true;

  void _applyTemplate(String templateId) {
    final tpl = _kRoleTemplates.firstWhere((t) => t.id == templateId, orElse: () => _kRoleTemplates.first);
    setState(() {
      _selectedTemplate = templateId;
      _selectedPerms.clear();
      _selectedPerms.addAll(tpl.permissions);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final res = await ApiService().post('/sub-admins/', data: {
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim().toLowerCase(),
        'password': _passCtrl.text.trim(),
        'permissions': _selectedPerms.toList(),
      });
      if (!mounted) return;
      if (res.statusCode == 201) {
        widget.onCreated();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res.data['message'] ?? 'Failed to create sub-admin', style: GoogleFonts.outfit()),
          backgroundColor: const Color(0xFFef4444),
        ));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Network error', style: GoogleFonts.outfit())));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return Container(
      decoration: BoxDecoration(
        color: widget.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: SingleChildScrollView(child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 48, height: 6, decoration: BoxDecoration(color: widget.borderColor, borderRadius: BorderRadius.circular(3)))),
        const SizedBox(height: 20),
        Text('New Sub-Admin', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 22, color: widget.textColor)),
        const SizedBox(height: 6),
        Text('This person will be able to log in and access only the modules you grant.', style: GoogleFonts.outfit(fontSize: 13, color: widget.subTextColor)),
        const SizedBox(height: 24),

        TextFormField(
          controller: _nameCtrl,
          style: GoogleFonts.outfit(color: widget.textColor, fontSize: 14),
          decoration: _inputDeco(label: 'Full Name', icon: Icons.person_outline_rounded),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: GoogleFonts.outfit(color: widget.textColor, fontSize: 14),
          decoration: _inputDeco(label: 'Email Address', icon: Icons.email_outlined),
          validator: (v) => (v == null || !v.contains('@')) ? 'Valid email required' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passCtrl,
          obscureText: _obscure,
          style: GoogleFonts.outfit(color: widget.textColor, fontSize: 14),
          decoration: _inputDeco(
            label: 'Temporary Password',
            icon: Icons.lock_outline_rounded,
            suffix: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: widget.subTextColor),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
        ),

        const SizedBox(height: 24),
        Text('Role Template', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: widget.textColor)),
        const SizedBox(height: 6),
        Text('Pick a preset to auto-select permissions, or customise manually below.', style: GoogleFonts.outfit(fontSize: 12, color: widget.subTextColor)),
        const SizedBox(height: 12),

        // Template cards — 2×2 grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.2,
          children: _kRoleTemplates.map((tpl) {
            final isSelected = _selectedTemplate == tpl.id;
            return InkWell(
              onTap: () => _applyTemplate(tpl.id),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? tpl.color.withValues(alpha: 0.1) : widget.inputBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? tpl.color.withValues(alpha: 0.5) : widget.borderColor,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(children: [
                  Icon(tpl.icon, size: 22, color: isSelected ? tpl.color : widget.subTextColor),
                  const SizedBox(width: 10),
                  Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tpl.label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? tpl.color : widget.textColor)),
                    Text(tpl.description, style: GoogleFonts.outfit(fontSize: 10, color: widget.subTextColor), overflow: TextOverflow.ellipsis),
                  ])),
                ]),
              ),
            );
          }).toList(),
        ),

        // Custom template tile
        const SizedBox(height: 10),
        InkWell(
          onTap: () => setState(() { _selectedTemplate = 'custom'; _selectedPerms.clear(); }),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _selectedTemplate == 'custom' ? const Color(0xFF6366f1).withValues(alpha: 0.1) : widget.inputBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedTemplate == 'custom' ? const Color(0xFF6366f1).withValues(alpha: 0.5) : widget.borderColor,
                width: _selectedTemplate == 'custom' ? 2 : 1,
              ),
            ),
            child: Row(children: [
              Icon(Icons.tune_rounded, size: 22, color: _selectedTemplate == 'custom' ? const Color(0xFF6366f1) : widget.subTextColor),
              const SizedBox(width: 12),
              Text('Custom', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: widget.textColor)),
              const SizedBox(width: 8),
              Text('— pick permissions manually', style: GoogleFonts.outfit(fontSize: 12, color: widget.subTextColor)),
            ]),
          ),
        ),

        const SizedBox(height: 24),
        Row(children: [
          Text('Module Access', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: widget.textColor)),
          const Spacer(),
          TextButton(
            onPressed: () => setState(() {
              if (_selectedPerms.length == _kAllPermissions.length) {
                _selectedPerms.clear(); _selectedTemplate = 'custom';
              } else {
                _selectedPerms.addAll(_kAllPermissions); _selectedTemplate = null;
              }
            }),
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: Text(
              _selectedPerms.length == _kAllPermissions.length ? 'Clear all' : 'Select all',
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ]),
        const SizedBox(height: 8),

        ..._kAllPermissions.map((perm) => CheckboxListTile(
          dense: true,
          title: Text(_kPermissionLabels[perm] ?? perm, style: GoogleFonts.outfit(fontSize: 14, color: widget.textColor)),
          secondary: Icon(_kPermissionIcons[perm] ?? Icons.check_rounded, size: 20, color: widget.subTextColor),
          value: _selectedPerms.contains(perm),
          activeColor: primary,
          side: BorderSide(color: widget.subTextColor.withValues(alpha: 0.5)),
          onChanged: (v) => setState(() {
            v == true ? _selectedPerms.add(perm) : _selectedPerms.remove(perm);
            _selectedTemplate = 'custom';
          }),
          controlAffinity: ListTileControlAffinity.leading,
        )),

        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity, height: 56,
          child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _loading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('Create Sub-Admin', style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ]))),
    );
  }

  InputDecoration _inputDeco({required String label, required IconData icon, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: widget.subTextColor),
      suffixIcon: suffix,
      filled: true,
      fillColor: widget.inputBg,
      labelStyle: GoogleFonts.outfit(fontSize: 14, color: widget.subTextColor),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: widget.borderColor, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 2)),
    );
  }
}

// ── Edit permissions bottom sheet ──────────────────────────────────────────────
class _EditPermissionsSheet extends StatefulWidget {
  final Map<String, dynamic> subAdmin;
  final VoidCallback onSaved;
  final bool isDark;
  final Color cardBg;
  final Color borderColor;
  final Color textColor;
  final Color subTextColor;

  const _EditPermissionsSheet({
    required this.subAdmin,
    required this.onSaved,
    required this.isDark,
    required this.cardBg,
    required this.borderColor,
    required this.textColor,
    required this.subTextColor,
  });
  @override
  State<_EditPermissionsSheet> createState() => _EditPermissionsSheetState();
}

class _EditPermissionsSheetState extends State<_EditPermissionsSheet> {
  late Set<String> _selected;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.subAdmin['permissions'] ?? []);
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().put(
        '/sub-admins/${widget.subAdmin['id']}/permissions',
        data: {'permissions': _selected.toList()},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        widget.onSaved();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res.data['message'] ?? 'Failed to update permissions', style: GoogleFonts.outfit()),
          backgroundColor: const Color(0xFFef4444),
        ));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Network error', style: GoogleFonts.outfit())));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return Container(
      decoration: BoxDecoration(
        color: widget.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 48, height: 6, decoration: BoxDecoration(color: widget.borderColor, borderRadius: BorderRadius.circular(3)))),
        const SizedBox(height: 20),
        Text('Edit: ${widget.subAdmin['name']}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 22, color: widget.textColor)),
        const SizedBox(height: 6),
        Text('Toggle which modules this sub-admin can access.', style: GoogleFonts.outfit(fontSize: 13, color: widget.subTextColor)),
        const SizedBox(height: 24),

        Row(children: [
          Checkbox(
            value: _selected.length == _kAllPermissions.length,
            tristate: true,
            activeColor: primary,
            side: BorderSide(color: widget.subTextColor.withValues(alpha: 0.5)),
            onChanged: (_) {
              setState(() {
                if (_selected.length == _kAllPermissions.length) {
                  _selected.clear();
                } else {
                  _selected.addAll(_kAllPermissions);
                }
              });
            },
          ),
          Text('Select All', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: widget.textColor)),
        ]),

        ..._kAllPermissions.map((perm) => CheckboxListTile(
          dense: true,
          title: Text(_kPermissionLabels[perm] ?? perm, style: GoogleFonts.outfit(fontSize: 14, color: widget.textColor)),
          secondary: Icon(_kPermissionIcons[perm] ?? Icons.check_rounded, size: 20, color: widget.subTextColor),
          value: _selected.contains(perm),
          activeColor: primary,
          side: BorderSide(color: widget.subTextColor.withValues(alpha: 0.5)),
          onChanged: (v) => setState(() { v == true ? _selected.add(perm) : _selected.remove(perm); }),
          controlAffinity: ListTileControlAffinity.leading,
        )),

        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity, height: 56,
          child: ElevatedButton(
            onPressed: _loading ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _loading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('Save Permissions', style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ])),
    );
  }
}
