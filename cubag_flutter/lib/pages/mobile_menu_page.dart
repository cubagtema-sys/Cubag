import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../components/app_layout.dart';

class MobileMenuPage extends StatelessWidget {
  const MobileMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final role = auth.userRole;
    final isAdmin = role == 'admin';

    // Same logic as AppLayout's _buildNavItems
    List<Widget> sections = [];
    if (isAdmin) {
      sections = [
        _buildSection(context, 'CORE MANAGEMENT', [
          _MenuItem('Dashboard', Icons.grid_view_rounded, '/admin/dashboard'),
          _MenuItem('Members', Icons.people_alt_rounded, '/admin/members'),
          _MenuItem('Announcements', Icons.campaign_rounded, '/admin/announcements'),
        ]),
        _buildSection(context, 'OPERATIONS & SUPPORT', [
          _MenuItem('Cargo Schedules', Icons.local_shipping_rounded, '/admin/cargo-schedules'),
          _MenuItem('Intelligence Hub', Icons.cell_tower_rounded, '/admin/intelligence'),
          _MenuItem('Support Tickets', Icons.support_agent_rounded, '/admin/tickets'),
        ]),
        _buildSection(context, 'FINANCIALS & RECORDS', [
          _MenuItem('Financial Center', Icons.account_balance_wallet_rounded, '/admin/payments'),
          _MenuItem('Payment Settings', Icons.payment_rounded, '/admin/payment-settings'),
          _MenuItem('Platform Fees', Icons.receipt_rounded, '/admin/fees'),
        ]),
        _buildSection(context, 'ENGAGEMENT & EVENTS', [
          _MenuItem('Events', Icons.event_rounded, '/admin/events'),
          _MenuItem('Surveys & Elections', Icons.how_to_vote_rounded, '/admin/surveys'),
        ]),
        _buildSection(context, 'ADMINISTRATION', [
          _MenuItem('Sub-Admins', Icons.admin_panel_settings_rounded, '/admin/sub-admins'),
          _MenuItem('Audit Log', Icons.history_rounded, '/admin/audit-log'),
        ]),
      ];
    } else if (role == 'sub_admin') {
      final allAdminItems = <String, List<_MenuItem>>{
        'members':          [_MenuItem('Members', Icons.people_alt_rounded, '/admin/members')],
        'announcements':    [_MenuItem('Announcements', Icons.campaign_rounded, '/admin/announcements')],
        'schedules':        [_MenuItem('Cargo Schedules', Icons.local_shipping_rounded, '/admin/cargo-schedules')],
        'intelligence':     [_MenuItem('Intelligence Hub', Icons.cell_tower_rounded, '/admin/intelligence')],
        'tickets':          [_MenuItem('Support Tickets', Icons.support_agent_rounded, '/admin/tickets')],
        'payments':         [_MenuItem('Financial Center', Icons.account_balance_wallet_rounded, '/admin/payments')],
        'fees':             [_MenuItem('Platform Fees', Icons.receipt_rounded, '/admin/fees')],
        'events':           [_MenuItem('Events', Icons.event_rounded, '/admin/events')],
        'surveys':          [_MenuItem('Surveys & Elections', Icons.how_to_vote_rounded, '/admin/surveys')],
        'audit_log':        [_MenuItem('Audit Log', Icons.history_rounded, '/admin/audit-log')],
        'settings':         [_MenuItem('Settings', Icons.settings_rounded, '/admin/settings')],
      };
      
      final permittedItems = <_MenuItem>[];
      final orderedKeys = ['members', 'announcements', 'schedules', 'intelligence', 'tickets', 'payments', 'fees', 'events', 'surveys', 'audit_log', 'settings'];
      for (final key in orderedKeys) {
        if (auth.hasPermission(key)) permittedItems.addAll(allAdminItems[key] ?? []);
      }
      
      sections = [
        _buildSection(context, 'OVERVIEW', [
          _MenuItem('Dashboard', Icons.grid_view_rounded, '/admin/dashboard'),
        ]),
        if (permittedItems.isNotEmpty)
          _buildSection(context, 'MY MODULES', permittedItems),
      ];
    } else {
      sections = [
        _buildSection(context, 'MAIN', [
          _MenuItem('Dashboard', Icons.home_rounded, '/dashboard'),
          _MenuItem('Announcements', Icons.campaign_rounded, '/announcements'),
        ]),
        _buildSection(context, 'SERVICES', [
          _MenuItem('Payments', Icons.account_balance_wallet_rounded, '/payments'),
          _MenuItem('Tasks & Compliance', Icons.task_alt_rounded, '/tasks'),
          _MenuItem('License Renewal', Icons.verified_user_rounded, '/license-renewal'),
          _MenuItem('Networking', Icons.language_rounded, '/networking'),
          _MenuItem('Messaging', Icons.chat_bubble_outline_rounded, '/messaging'),
          _MenuItem('Events', Icons.event_rounded, '/events'),
        ]),
        _buildSection(context, 'RESOURCES', [
          _MenuItem('Live Logistics', Icons.analytics_rounded, '/live-data'),
          _MenuItem('Vessel Movements', Icons.directions_boat_rounded, '/vessel-movements'),
          _MenuItem('Vanning Schedules', Icons.calendar_today_rounded, '/vanning-schedules'),
        ]),
      ];
    }

    final isSubOrAdmin = isAdmin || role == 'sub_admin';

    return AppLayout(
      title: 'Menu',
      scrollable: true,
      child: Container(
        color: const Color(0xFFf1f5f9),
        child: Column(
          children: [
            ...sections,
            _buildSection(context, 'ACCOUNT', [
              _MenuItem('Settings', Icons.settings_rounded, isSubOrAdmin ? '/admin/settings' : '/settings'),
              _MenuItem('Sign Out', Icons.logout_rounded, '/login', isLogout: true),
            ]),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<_MenuItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748b),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Column(
                children: [
                  _navTile(context, item),
                  if (index != items.length - 1)
                    const Divider(height: 1, indent: 56, endIndent: 0, color: Color(0xFFf1f5f9)),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _navTile(BuildContext context, _MenuItem item) {
    final primary = Theme.of(context).primaryColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (item.isLogout) {
            Provider.of<AuthService>(context, listen: false).logout();
          }
          context.go(item.route);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                item.icon,
                color: item.isLogout ? Colors.red : primary,
                size: 22,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: item.isLogout ? Colors.red : const Color(0xFF1e293b),
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFcbd5e1),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem {
  final String title;
  final IconData icon;
  final String route;
  final bool isLogout;
  _MenuItem(this.title, this.icon, this.route, {this.isLogout = false});
}
