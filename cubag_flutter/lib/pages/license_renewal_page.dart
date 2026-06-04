import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../components/app_layout.dart';
import '../services/cache_service.dart';

class LicenseRenewalPage extends StatefulWidget {
  const LicenseRenewalPage({super.key});
  @override
  State<LicenseRenewalPage> createState() => _LicenseRenewalPageState();
}

class _LicenseRenewalPageState extends State<LicenseRenewalPage> {
  bool _loading = true;
  List<dynamic> _history = [];
  Map<String, dynamic>? _memberInfo;
  final CacheService _cache = CacheService();

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final data = await _cache.fetchCachedMap('/members/license-history');
      if (mounted) {
        setState(() {
          _history = data['history'] ?? [];
          _memberInfo = data['member'] as Map<String, dynamic>?;
        });
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final user = _memberInfo ?? {};
    final isActive = user['status'] == 'active';
    final yr = DateTime.now().year;

    return AppLayout(
      title: 'License & Receipts',
      child: !isActive && !_loading && _history.isEmpty
        ? _buildLockedView(primary)
        : Column(children: [
            // ── Status Timeline ──
            if (!_loading && _history.isNotEmpty) ...[
              _buildStatusTimeline(primary, user),
              const SizedBox(height: 20),
            ],

            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            else if (_history.isEmpty)
              _buildEmptyState(primary)
            else
              ..._history.asMap().map((i, rec) => MapEntry(i, _buildRecordCard(rec, primary, yr))).values,

            const SizedBox(height: 24),
            Center(child: TextButton(onPressed: () => context.go('/engagement'), child: Text('Need help? Contact Support', style: TextStyle(color: primary, fontWeight: FontWeight.bold)))),
          ]),
    );
  }

  // ── License Status Timeline ──
  Widget _buildStatusTimeline(Color primary, Map<String, dynamic> user) {
    final status = user['status']?.toString() ?? 'pending';
    final steps = [
      _TimelineStep('Application', 'Submitted', _StepState.done),
      _TimelineStep('Payment', 'Dues Received', status == 'pending' ? _StepState.active : _StepState.done),
      _TimelineStep('Verification', 'Under Review', status == 'pending' ? _StepState.pending : status == 'suspended' ? _StepState.error : _StepState.done),
      _TimelineStep('License', 'Issued', status == 'active' ? _StepState.done : _StepState.pending),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primary, primary.withAlpha(200)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.timeline, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Renewal Progress', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Track your license renewal status', style: TextStyle(color: Colors.white70, fontSize: 11)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: status == 'active' ? const Color(0xFF10b981).withAlpha(40) : status == 'suspended' ? const Color(0xFFef4444).withAlpha(40) : Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.bold,
                color: status == 'active' ? const Color(0xFF10b981) : status == 'suspended' ? const Color(0xFFef4444) : Colors.white,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 20),
        // Timeline row
        Row(children: List.generate(steps.length, (i) {
          final step = steps[i];
          final isLast = i == steps.length - 1;
          return Expanded(child: Row(children: [
            Expanded(child: Column(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: _stepColor(step.state),
                  shape: BoxShape.circle,
                  border: step.state == _StepState.active ? Border.all(color: Colors.white, width: 2) : null,
                ),
                child: Icon(
                  step.state == _StepState.done ? Icons.check :
                  step.state == _StepState.error ? Icons.close :
                  step.state == _StepState.active ? Icons.autorenew : Icons.circle_outlined,
                  color: Colors.white, size: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(step.title, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              Text(step.subtitle, style: const TextStyle(color: Colors.white60, fontSize: 8), textAlign: TextAlign.center),
            ])),
            if (!isLast) Container(width: 20, height: 2, color: step.state == _StepState.done ? Colors.white : Colors.white30),
          ]));
        })),
      ]),
    );
  }

  Color _stepColor(_StepState state) {
    switch (state) {
      case _StepState.done: return const Color(0xFF10b981);
      case _StepState.active: return Colors.white.withAlpha(40);
      case _StepState.error: return const Color(0xFFef4444);
      case _StepState.pending: return Colors.white.withAlpha(20);
    }
  }

  Widget _buildLockedView(Color primary) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20)),
      child: Column(children: [
        Container(width: 80, height: 80, decoration: const BoxDecoration(color: Color(0x19ef4444), shape: BoxShape.circle), child: const Icon(Icons.lock, color: Color(0xFFef4444), size: 40)),
        const SizedBox(height: 20),
        const Text('Records Restricted', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        const SizedBox(height: 12),
        const Text('Your official receipts and membership licenses will appear here once your annual dues are settled and approved by the secretariat.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.6)),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ElevatedButton(onPressed: () => context.go('/payments'), style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, minimumSize: const Size(130, 48)), child: const Text('Make Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          const SizedBox(width: 12),
          OutlinedButton(onPressed: () => context.go('/dashboard'), style: OutlinedButton.styleFrom(minimumSize: const Size(130, 48)), child: const Text('Back to Dashboard')),
        ]),
      ]),
    );
  }

  Widget _buildEmptyState(Color primary) {
    return Container(
      padding: const EdgeInsets.all(48),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        const Icon(Icons.history, size: 48, color: Colors.grey),
        const SizedBox(height: 12),
        const Text('No Records', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 8),
        const Text("You don't have any receipts yet.", style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: () => context.go('/payments'), style: ElevatedButton.styleFrom(backgroundColor: primary, minimumSize: const Size(160, 48)), child: const Text('Make Payment', style: TextStyle(color: Colors.white))),
      ]),
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> rec, Color primary, int yr) {
    final approved = rec['approved'] == true;
    final suspended = rec['status'] == 'suspended';
    final statusColor = approved ? const Color(0xFF10b981) : suspended ? const Color(0xFFef4444) : const Color(0xFFf59e0b);
    final statusLabel = approved ? 'Active' : suspended ? 'Suspended' : 'In Approval';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).dividerColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(gradient: LinearGradient(colors: [primary, primary.withAlpha(178)]), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.badge, color: Colors.white, size: 22)),
          const SizedBox(width: 12),
          const Expanded(child: Text('Membership Record', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: statusColor.withAlpha(25), border: Border.all(color: statusColor.withAlpha(76)), borderRadius: BorderRadius.circular(8)), child: Text(statusLabel.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor))),
        ]),
        const SizedBox(height: 16),
        ...([
          {'icon': Icons.verified, 'label': 'License Number', 'val': rec['license_number'] ?? (approved ? 'Validating...' : 'Pending')},
          {'icon': Icons.business, 'label': 'Organization', 'val': rec['company']},
          {'icon': Icons.location_on, 'label': 'Port of Operation', 'val': rec['port_of_operation']},
        ].where((r) => r['val'] != null)).map((r) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: primary.withAlpha(25), borderRadius: BorderRadius.circular(8)), child: Icon(r['icon'] as IconData, color: primary, size: 18)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r['label'].toString().toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              Text(r['val'].toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ])),
          ]),
        )),
        const SizedBox(height: 8),
        if (approved)
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => _showCertificate(rec, yr), icon: const Icon(Icons.visibility, size: 16), label: const Text('View', style: TextStyle(fontSize: 13)))),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton.icon(onPressed: () => _showCertificate(rec, yr), icon: const Icon(Icons.download, size: 16, color: Colors.white), label: const Text('Download', style: TextStyle(color: Colors.white, fontSize: 13)), style: ElevatedButton.styleFrom(backgroundColor: primary))),
          ])
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0x19f59e0b), borderRadius: BorderRadius.circular(8)),
            child: const Text('Awaiting admin approval...', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFf59e0b), fontSize: 13, fontWeight: FontWeight.w600)),
          ),
      ]),
    );
  }

  void _showCertificate(Map<String, dynamic> rec, int yr) {
    final primary = Theme.of(context).primaryColor;
    final user = _memberInfo ?? {};
    showDialog(context: context, builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.verified, color: Colors.white)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('CUBAG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: primary)),
                const Text('Certificate of Membership', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
            ]),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ]),
          Container(margin: const EdgeInsets.symmetric(vertical: 16), height: 3, decoration: BoxDecoration(gradient: LinearGradient(colors: [primary, primary.withAlpha(127)]))),

          const Text('Certificate of', style: TextStyle(fontSize: 12, color: Colors.grey, letterSpacing: 2)),
          const SizedBox(height: 4),
          Text('Active Membership', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primary)),
          const SizedBox(height: 16),
          const Text('This is to certify that', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
          const SizedBox(height: 8),
          Text(user['company']?.toString() ?? rec['company']?.toString() ?? 'Company Name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          Text('represented by ${user['name']?.toString() ?? rec['name']?.toString() ?? 'Member Name'}', style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 13)),
          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).dividerColor)),
            child: Column(children: [
              _certRow('License Number', rec['license_number']?.toString() ?? 'VALIDATING...', primary),
              _certRow('Member Type', user['member_type']?.toString() ?? rec['member_type']?.toString() ?? '—', primary),
              _certRow('Port of Operation', user['port_of_operation']?.toString() ?? rec['port_of_operation']?.toString() ?? '—', primary),
              _certRow('Valid Period', 'January $yr – December $yr', primary),
            ]),
          ),
          const SizedBox(height: 20),
          Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.verified, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text('CUBAG OFFICIAL CERTIFICATE $yr', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
          ])),
        ])),
      ),
    ));
  }

  Widget _certRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

enum _StepState { done, active, error, pending }

class _TimelineStep {
  final String title;
  final String subtitle;
  final _StepState state;
  const _TimelineStep(this.title, this.subtitle, this.state);
}
