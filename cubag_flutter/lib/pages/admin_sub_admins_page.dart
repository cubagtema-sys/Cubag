import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/app_layout.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

// All available permission modules — must match backend ALL_PERMISSIONS list.
const _kAllPermissions = [
  'members', 'payments', 'tickets', 'announcements',
  'schedules', 'events', 'intelligence', 'audit_log',
  'fees', 'settings',
];

const _kPermissionLabels = {
  'members':          'Member Management',
  'payments':         'Financial Center',
  'tickets':          'Support Tickets',
  'announcements':    'Announcements',
  'schedules':        'Cargo Schedules',
  'events':           'Events & Surveys',
  'intelligence':     'Intelligence Hub',
  'audit_log':        'Audit Log',
  'fees':             'Platform Fees',
  'settings':         'Settings',
};

const _kPermissionIcons = {
  'members':          Icons.people_outline,
  'payments':         Icons.payments_outlined,
  'tickets':          Icons.support_agent_outlined,
  'announcements':    Icons.campaign_outlined,
  'schedules':        Icons.local_shipping_outlined,
  'events':           Icons.event_outlined,
  'intelligence':     Icons.cell_tower,
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
      content: Text(msg),
      backgroundColor: error ? const Color(0xFFef4444) : const Color(0xFF10b981),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _remove(Map<String, dynamic> sa) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Remove Sub-Admin'),
        content: Text('Demote ${sa['name']} back to a regular member?\nAll their permissions will be revoked.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFef4444),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
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

  void _showCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateSubAdminSheet(onCreated: () { Navigator.pop(ctx); _fetch(); }),
    );
  }

  void _showEditSheet(Map<String, dynamic> sa) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditPermissionsSheet(subAdmin: sa, onSaved: () { Navigator.pop(ctx); _fetch(); }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final auth = Provider.of<AuthService>(context, listen: false);

    // Only full admins may access this page
    if (auth.userRole != 'admin') {
      return AppLayout(
        title: 'Sub-Admins',
        child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.lock_outline, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text('Full admin access required', style: TextStyle(color: Colors.grey)),
        ])),
      );
    }

    return AppLayout(
      title: 'Sub-Admin Management',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [primary, primary.withValues(alpha: 0.7)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Sub-Admin Accounts', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Text('${_subAdmins.length} sub-admin(s) configured', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ])),
            ElevatedButton.icon(
              onPressed: _showCreateSheet,
              icon: const Icon(Icons.person_add_outlined, size: 16, color: Colors.white),
              label: const Text('Add Sub-Admin', style: TextStyle(color: Colors.white, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withAlpha(40),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 16),

        // Info card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: primary.withAlpha(8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primary.withAlpha(30)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, color: primary, size: 18),
            const SizedBox(width: 10),
            const Expanded(child: Text(
              'Sub-admins can log in and access only the modules you grant them. '
              'They cannot create other sub-admins, manage fees, or access the full audit trail unless explicitly permitted.',
              style: TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.5),
            )),
          ]),
        ),

        const SizedBox(height: 16),

        // List
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()))
        else if (_subAdmins.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(children: [
              Icon(Icons.admin_panel_settings_outlined, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              const Text('No sub-admins yet.\nTap "Add Sub-Admin" to create one.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
            ]),
          ))
        else
          ...(_subAdmins.map((sa) {
            final perms = List<String>.from(sa['permissions'] ?? []);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Header row
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: primary.withAlpha(20),
                      child: Text(
                        (sa['name']?.toString() ?? '?').substring(0, 1).toUpperCase(),
                        style: TextStyle(fontWeight: FontWeight.bold, color: primary, fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(sa['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(sa['email']?.toString() ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF94a3b8))),
                      const SizedBox(height: 3),
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
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: color.withAlpha(18), borderRadius: BorderRadius.circular(12)),
                          child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.3)),
                        );
                      }),
                    ])),
                    // Edit button
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748b)),
                      tooltip: 'Edit permissions',
                      onPressed: () => _showEditSheet(Map<String, dynamic>.from(sa)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.person_remove_outlined, size: 18, color: Color(0xFFef4444)),
                      tooltip: 'Remove sub-admin',
                      onPressed: () => _remove(Map<String, dynamic>.from(sa)),
                    ),
                  ]),
                ),

                // Permissions chips
                if (perms.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Text('No permissions granted', style: TextStyle(fontSize: 12, color: Colors.orange.shade700, fontStyle: FontStyle.italic)),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Wrap(spacing: 6, runSpacing: 6, children: perms.map((p) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: primary.withAlpha(12), borderRadius: BorderRadius.circular(12)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_kPermissionIcons[p] ?? Icons.check, size: 11, color: primary),
                        const SizedBox(width: 4),
                        Text(_kPermissionLabels[p] ?? p, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: primary)),
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
  const _CreateSubAdminSheet({required this.onCreated});
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
          content: Text(res.data['message'] ?? 'Failed to create sub-admin'),
          backgroundColor: const Color(0xFFef4444),
        ));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Network error')));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 32),
      child: SingleChildScrollView(child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        const Text('New Sub-Admin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 4),
        const Text('This person will be able to log in and access only the modules you grant.', style: TextStyle(fontSize: 12, color: Color(0xFF94a3b8))),
        const SizedBox(height: 16),

        TextFormField(
          controller: _nameCtrl,
          decoration: _inputDeco(label: 'Full Name', icon: Icons.person_outline),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: _inputDeco(label: 'Email Address', icon: Icons.email_outlined),
          validator: (v) => (v == null || !v.contains('@')) ? 'Valid email required' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _passCtrl,
          obscureText: _obscure,
          decoration: _inputDeco(
            label: 'Temporary Password',
            icon: Icons.lock_outline,
            suffix: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
        ),

        const SizedBox(height: 16),
        const Text('Role Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 4),
        const Text('Pick a preset to auto-select permissions, or customise manually below.', style: TextStyle(fontSize: 11, color: Color(0xFF94a3b8))),
        const SizedBox(height: 10),

        // Template cards — 2×2 grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.6,
          children: _kRoleTemplates.map((tpl) {
            final isSelected = _selectedTemplate == tpl.id;
            return InkWell(
              onTap: () => _applyTemplate(tpl.id),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? tpl.color.withAlpha(20) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? tpl.color : const Color(0xFFe2e8f0),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(children: [
                  Icon(tpl.icon, size: 18, color: isSelected ? tpl.color : const Color(0xFF94a3b8)),
                  const SizedBox(width: 8),
                  Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tpl.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isSelected ? tpl.color : const Color(0xFF374151))),
                    Text(tpl.description, style: const TextStyle(fontSize: 9, color: Color(0xFF94a3b8)), overflow: TextOverflow.ellipsis),
                  ])),
                ]),
              ),
            );
          }).toList(),
        ),

        // Custom template tile
        const SizedBox(height: 8),
        InkWell(
          onTap: () => setState(() { _selectedTemplate = 'custom'; _selectedPerms.clear(); }),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _selectedTemplate == 'custom' ? const Color(0xFF6366f1).withAlpha(15) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedTemplate == 'custom' ? const Color(0xFF6366f1) : const Color(0xFFe2e8f0),
                width: _selectedTemplate == 'custom' ? 2 : 1,
              ),
            ),
            child: Row(children: [
              Icon(Icons.tune, size: 18, color: _selectedTemplate == 'custom' ? const Color(0xFF6366f1) : const Color(0xFF94a3b8)),
              const SizedBox(width: 10),
              const Text('Custom', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
              const SizedBox(width: 6),
              const Text('— pick permissions manually', style: TextStyle(fontSize: 11, color: Color(0xFF94a3b8))),
            ]),
          ),
        ),

        // Permission checkboxes (always visible so user can fine-tune after picking template)
        const SizedBox(height: 16),
        Row(children: [
          const Text('Module Access', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ]),
        const SizedBox(height: 4),

        ..._kAllPermissions.map((perm) => CheckboxListTile(
          dense: true,
          title: Text(_kPermissionLabels[perm] ?? perm, style: const TextStyle(fontSize: 13)),
          secondary: Icon(_kPermissionIcons[perm] ?? Icons.check, size: 18, color: const Color(0xFF64748b)),
          value: _selectedPerms.contains(perm),
          onChanged: (v) => setState(() {
            v == true ? _selectedPerms.add(perm) : _selectedPerms.remove(perm);
            _selectedTemplate = 'custom'; // moving a checkbox = custom
          }),
          controlAffinity: ListTileControlAffinity.leading,
        )),

        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Create Sub-Admin', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
      ]))),
    );
  }

  InputDecoration _inputDeco({required String label, required IconData icon, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18),
      suffixIcon: suffix,
      labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748b)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5)),
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
  const _EditPermissionsSheet({required this.subAdmin, required this.onSaved});
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
          content: Text(res.data['message'] ?? 'Failed to update permissions'),
          backgroundColor: const Color(0xFFef4444),
        ));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Network error')));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 32),
      child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Text('Edit: ${widget.subAdmin['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 4),
        const Text('Toggle which modules this sub-admin can access.', style: TextStyle(fontSize: 12, color: Color(0xFF94a3b8))),
        const SizedBox(height: 12),

        Row(children: [
          Checkbox(
            value: _selected.length == _kAllPermissions.length,
            tristate: true,
            onChanged: (_) {
              setState(() {
                if (_selected.length == _kAllPermissions.length) _selected.clear();
                else _selected.addAll(_kAllPermissions);
              });
            },
          ),
          const Text('Select All', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        ]),

        ..._kAllPermissions.map((perm) => CheckboxListTile(
          dense: true,
          title: Text(_kPermissionLabels[perm] ?? perm, style: const TextStyle(fontSize: 13)),
          secondary: Icon(_kPermissionIcons[perm] ?? Icons.check, size: 18, color: const Color(0xFF64748b)),
          value: _selected.contains(perm),
          onChanged: (v) => setState(() { v == true ? _selected.add(perm) : _selected.remove(perm); }),
          controlAffinity: ListTileControlAffinity.leading,
        )),

        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: _loading ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Save Permissions', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
      ])),
    );
  }
}
