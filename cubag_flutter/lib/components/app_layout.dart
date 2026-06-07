import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../components/admin_search_delegate.dart';
import '../components/member_search_delegate.dart';
import 'app_logo.dart';

class AppLayout extends StatefulWidget {
  final Widget child;
  final String title;
  final bool hideSearch;
  final bool scrollable;

  const AppLayout({
    super.key,
    required this.child,
    required this.title,
    this.hideSearch = true,
    this.scrollable = true,
  });

  @override
  State<AppLayout> createState() => _AppLayoutState();
}

class _AppLayoutState extends State<AppLayout> {
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchUnreadCount();
    _loadUserPhoto();
  }

  /// Fetch /auth/me on every page mount so the header avatar
  /// is always up to date — even on first login before any upload.
  Future<void> _loadUserPhoto() async {
    try {
      final res = await ApiService().get('/auth/me');
      if (res.statusCode == 200 && mounted) {
        final photoUrl = res.data['profile_photo']?.toString() ?? '';
        if (photoUrl.isNotEmpty) {
          // ignore: use_build_context_synchronously
          await Provider.of<AuthService>(context, listen: false).updatePhoto(photoUrl);
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final res = await ApiService().get('/announcements');
      if (res.statusCode == 200) {
        final data = ApiService.ensureList(res.data);
        final count = data.where((a) => a['is_read'] != true).length;
        if (mounted) {
          setState(() => _unreadCount = count);
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 800;
    final isSmall = size.width < 360;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: isDesktop ? null : AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleSpacing: isSmall ? 0 : 16,
        shadowColor: Colors.black.withAlpha(20),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: const Color(0xFFf0f0f0), height: 1)),
        title: Text(
          widget.title, 
          style: TextStyle(color: const Color(0xFF0f172a), fontWeight: FontWeight.bold, fontSize: isSmall ? 15 : 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (!widget.hideSearch)
            IconButton(
              icon: Icon(Icons.search, color: const Color(0xFF64748b), size: isSmall ? 20 : 24),
              tooltip: 'Search',
              onPressed: () => showSearch(
                context: context,
                delegate: authService.userRole == 'admin'
                    ? AdminSearchDelegate()
                    : MemberSearchDelegate(),
              ),
            ),
          _buildNotificationIcon(context, authService.userRole, isSmall),
          Padding(
            padding: EdgeInsets.only(right: isSmall ? 4 : 8),
            child: _buildProfileMenu(context, authService, isSmall),
          ),
        ],
      ),
      drawer: isDesktop ? null : _buildDrawer(context, authService.userRole),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isDesktop) _buildSidebar(context, authService.userRole),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isDesktop) _buildDesktopHeader(context, authService),
                Expanded(
                  child: widget.scrollable
                      ? SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(isSmall ? 12 : 16, isSmall ? 12 : 16, isSmall ? 12 : 16, 16),
                          child: widget.child,
                        )
                      : Padding(
                          padding: EdgeInsets.fromLTRB(isSmall ? 12 : 16, isSmall ? 12 : 16, isSmall ? 12 : 16, 16),
                          child: widget.child,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationIcon(BuildContext context, String? role, bool isSmall) {
    final isAdmin = role == 'admin';
    final targetRoute = isAdmin ? '/admin/announcements' : '/notifications';
    
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.notifications_outlined, color: const Color(0xFF64748b), size: isSmall ? 20 : 24),
          onPressed: () => context.go(targetRoute),
        ),
        if (_unreadCount > 0)
          Positioned(
            right: isSmall ? 6 : 8,
            top: isSmall ? 6 : 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: const Color(0xFFef4444),
                borderRadius: BorderRadius.circular(8),
              ),
              constraints: const BoxConstraints(
                minWidth: 14,
                minHeight: 14,
              ),
              child: Text(
                '$_unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProfileMenu(BuildContext context, AuthService authService, bool isSmall) {
    final photoUrl = authService.userPhotoUrl;
    final primary = Theme.of(context).primaryColor;
    // Cache-bust so Flutter Web doesn't serve a stale image after upload
    final imageUrl = (photoUrl != null && photoUrl.isNotEmpty)
        ? '$photoUrl?v=${photoUrl.hashCode}'
        : null;

    return PopupMenuButton<String>(
      icon: CircleAvatar(
        radius: isSmall ? 14 : 16,
        backgroundColor: primary,
        backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
        child: imageUrl == null
            ? Icon(Icons.person, color: Colors.white, size: isSmall ? 16 : 18)
            : null,
      ),
      offset: const Offset(0, 48),
      itemBuilder: (context) => [
        PopupMenuItem(child: const Row(children: [Icon(Icons.person_outline, size: 18, color: Color(0xFF64748b)), SizedBox(width: 10), Text('Profile')]), onTap: () => context.go('/profile')),
        PopupMenuItem(child: const Row(children: [Icon(Icons.settings_outlined, size: 18, color: Color(0xFF64748b)), SizedBox(width: 10), Text('Settings')]), onTap: () => context.go(authService.userRole == 'admin' ? '/admin/settings' : '/settings')),
        PopupMenuItem<String>(enabled: false, height: 1, child: const Divider(height: 1, color: Color(0xFFE2E8F0))),
        PopupMenuItem(
          child: const Row(children: [Icon(Icons.logout, size: 18, color: Color(0xFFef4444)), SizedBox(width: 10), Text('Logout', style: TextStyle(color: Color(0xFFef4444)))]),
          onTap: () { authService.logout(); context.go('/login'); },
        ),
      ],
    );
  }

  Widget _buildDesktopHeader(BuildContext context, AuthService authService) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFf0f0f0))),
      ),
      child: Row(
        children: [
          Text(widget.title, style: const TextStyle(color: Color(0xFF0f172a), fontWeight: FontWeight.bold, fontSize: 18)),
          const Spacer(),
          if (!widget.hideSearch)
            IconButton(
              icon: const Icon(Icons.search, color: Color(0xFF64748b)),
              tooltip: 'Search',
              onPressed: () => showSearch(
                context: context,
                delegate: authService.userRole == 'admin'
                    ? AdminSearchDelegate()
                    : MemberSearchDelegate(),
              ),
            ),
          _buildNotificationIcon(context, authService.userRole, false),
          const SizedBox(width: 8),
          _buildProfileMenu(context, authService, false),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, String? role) {
    final primary = Theme.of(context).primaryColor;
    return Drawer(
      child: Builder(
        builder: (drawerContext) => Column(children: [
          // Drawer header with logo
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [primary, primary.withValues(alpha: 0.8)])),
            child: Row(children: [
            const AppLogo(size: 44, borderRadius: 11, showShadow: true),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('CUBAG', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  SizedBox(height: 2),
                  Text('Enterprise Platform', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ]),
        ),
        Expanded(child: _buildNavItems(drawerContext, role)),
      ]),
    ),
  );
  }

  Widget _buildSidebar(BuildContext context, String? role) {
    final primary = Theme.of(context).primaryColor;
    return Container(
      width: 240,
      decoration: BoxDecoration(color: Colors.white, border: Border(right: BorderSide(color: const Color(0xFFf0f0f0)))),
      child: Column(children: [
        // Sidebar logo header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [primary, primary.withValues(alpha: 0.8)])),
          child: Row(children: [
          const AppLogo(size: 40, borderRadius: 10, showShadow: true),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('CUBAG', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                SizedBox(height: 2),
                Text('Enterprise Platform', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ]),
      ),
      Expanded(child: _buildNavItems(context, role)),
    ]),
  );
  }

  Widget _buildNavItems(BuildContext context, String? role) {
    final isAdmin = role == 'admin';
    final currentRoute = GoRouterState.of(context).matchedLocation;

    if (isAdmin) {
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _NavSection(
            title: 'Core Management',
            currentRoute: currentRoute,
            items: [
              _NavItemData('Dashboard', Icons.dashboard_outlined, '/admin/dashboard'),
              _NavItemData('Members', Icons.people_outline, '/admin/members'),
              _NavItemData('Announcements', Icons.campaign_outlined, '/admin/announcements'),
            ],
            context: context,
            buildNavItem: _navItem,
          ),
          _NavSection(
            title: 'Operations & Support',
            currentRoute: currentRoute,
            items: [
              _NavItemData('Cargo Schedules', Icons.local_shipping_outlined, '/admin/cargo-schedules'),
              _NavItemData('Intelligence Hub', Icons.cell_tower, '/admin/intelligence'),
              _NavItemData('Support Tickets', Icons.support_agent_outlined, '/admin/tickets'),
            ],
            context: context,
            buildNavItem: _navItem,
          ),
          _NavSection(
            title: 'Financials & Records',
            currentRoute: currentRoute,
            items: [
              _NavItemData('Financial Center', Icons.payments_outlined, '/admin/payments'),
              _NavItemData('Payment Settings', Icons.payment_outlined, '/admin/payment-settings'),
              _NavItemData('Platform Fees', Icons.request_quote_outlined, '/admin/fees'),
            ],
            context: context,
            buildNavItem: _navItem,
          ),
          _NavSection(
            title: 'Engagement & Events',
            currentRoute: currentRoute,
            items: [
              _NavItemData('Events', Icons.event_outlined, '/admin/events'),
              _NavItemData('Surveys & Elections', Icons.how_to_vote_outlined, '/admin/surveys'),
            ],
            context: context,
            buildNavItem: _navItem,
          ),
          _NavSection(
            title: 'Administration',
            currentRoute: currentRoute,
            items: [
              _NavItemData('Sub-Admins', Icons.admin_panel_settings_outlined, '/admin/sub-admins'),
              _NavItemData('Audit Log', Icons.history_outlined, '/admin/audit-log'),
              _NavItemData('Settings', Icons.settings_outlined, '/admin/settings'),
            ],
            context: context,
            buildNavItem: _navItem,
          ),
        ],
      );
    } else if (role == 'sub_admin') {
      // ── Sub-admin sidebar: only show items the user has permission for ──
      final auth = Provider.of<AuthService>(context, listen: false);

      // Map from permission key → nav item(s)
      final allAdminItems = <String, List<_NavItemData>>{
        'members':          [_NavItemData('Members', Icons.people_outline, '/admin/members')],
        'announcements':    [_NavItemData('Announcements', Icons.campaign_outlined, '/admin/announcements')],
        'schedules':        [_NavItemData('Cargo Schedules', Icons.local_shipping_outlined, '/admin/cargo-schedules')],
        'intelligence':     [_NavItemData('Intelligence Hub', Icons.cell_tower, '/admin/intelligence')],
        'tickets':          [_NavItemData('Support Tickets', Icons.support_agent_outlined, '/admin/tickets')],
        'payments':         [_NavItemData('Financial Center', Icons.payments_outlined, '/admin/payments')],
        'fees':             [_NavItemData('Platform Fees', Icons.request_quote_outlined, '/admin/fees')],
        'events':           [_NavItemData('Events', Icons.event_outlined, '/admin/events')],
        'surveys':          [_NavItemData('Surveys & Elections', Icons.how_to_vote_outlined, '/admin/surveys')],
        'audit_log':        [_NavItemData('Audit Log', Icons.history_outlined, '/admin/audit-log')],
        'settings':         [_NavItemData('Settings', Icons.settings_outlined, '/admin/settings')],
      };

      // Collect permitted items in a consistent display order
      final orderedKeys = [
        'members', 'announcements', 'schedules', 'intelligence', 'tickets',
        'payments', 'fees', 'events', 'surveys', 'audit_log', 'settings',
      ];
      final permittedItems = <_NavItemData>[];
      for (final key in orderedKeys) {
        if (auth.hasPermission(key)) {
          permittedItems.addAll(allAdminItems[key] ?? []);
        }
      }

      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Role indicator pill
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF8b5cf6).withAlpha(15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF8b5cf6).withAlpha(50)),
            ),
            child: Row(children: [
              const Icon(Icons.badge_outlined, size: 14, color: Color(0xFF8b5cf6)),
              const SizedBox(width: 6),
              const Text('Sub-Admin Access', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8b5cf6))),
            ]),
          ),

          // Dashboard always visible
          _NavSection(
            title: 'Overview',
            currentRoute: currentRoute,
            items: [_NavItemData('Dashboard', Icons.dashboard_outlined, '/admin/dashboard')],
            context: context,
            buildNavItem: _navItem,
          ),

          if (permittedItems.isNotEmpty)
            _NavSection(
              title: 'My Modules',
              currentRoute: currentRoute,
              items: permittedItems,
              context: context,
              buildNavItem: _navItem,
            ),

          if (permittedItems.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Icon(Icons.lock_outline, size: 32, color: Color(0xFFcbd5e1)),
                const SizedBox(height: 8),
                const Text('No modules assigned yet.\nContact your admin.', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Color(0xFF94a3b8))),
              ]),
            ),
        ],
      );
    } else {
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _NavSection(
            title: 'Main',
            currentRoute: currentRoute,
            items: [
              _NavItemData('Dashboard', Icons.home_outlined, '/dashboard'),
              _NavItemData('Announcements', Icons.campaign_outlined, '/announcements'),
              _NavItemData('Events', Icons.event_outlined, '/events'),
            ],
            context: context,
            buildNavItem: _navItem,
          ),
          _NavSection(
            title: 'Member Services',
            currentRoute: currentRoute,
            items: [
              _NavItemData('Networking', Icons.group_outlined, '/networking'),
              _NavItemData('Messaging', Icons.chat_outlined, '/messaging'),
              _NavItemData('Payments', Icons.payments_outlined, '/payments'),
              _NavItemData('Payment History', Icons.receipt_long_outlined, '/payment-history'),
              _NavItemData('Surveys & Elections', Icons.ballot_outlined, '/surveys'),
              _NavItemData('Tasks & Compliance', Icons.task_outlined, '/tasks'),
              _NavItemData('License Renewal', Icons.card_membership_outlined, '/license-renewal'),
            ],
            context: context,
            buildNavItem: _navItem,
          ),
          _NavSection(
            title: 'Data & Analytics',
            currentRoute: currentRoute,
            items: [
              _NavItemData('Live Logistics Data', Icons.show_chart, '/live-data'),
              _NavItemData('Vessels', Icons.directions_boat_outlined, '/vessel-movements'),
              _NavItemData('Vanning Schedules', Icons.schedule_outlined, '/vanning-schedules'),
            ],
            context: context,
            buildNavItem: _navItem,
          ),
          _NavSection(
            title: 'Support & Services',
            currentRoute: currentRoute,
            items: [
              _NavItemData('Contact Support', Icons.support_agent_outlined, '/engagement'),
              _NavItemData('Settings', Icons.settings_outlined, '/settings'),
            ],
            context: context,
            buildNavItem: _navItem,
          ),
        ],
      );
    }
  }

  Widget _navItem(BuildContext context, String title, IconData icon, String route) {
    final current = GoRouterState.of(context).matchedLocation;
    final active = current == route || (route != '/' && current.startsWith(route));
    final primary = Theme.of(context).primaryColor;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: active ? primary.withAlpha(20) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        leading: Icon(icon, color: active ? primary : const Color(0xFF64748b), size: 20),
        title: Text(title, style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? primary : const Color(0xFF374151))),
        trailing: (title == 'Announcements' && _unreadCount > 0)
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFef4444),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        selected: active,
        onTap: () {
          context.go(route);
          final scaffold = Scaffold.maybeOf(context);
          if (scaffold != null && scaffold.hasDrawer && scaffold.isDrawerOpen) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }
}

class _NavItemData {
  final String title;
  final IconData icon;
  final String route;
  _NavItemData(this.title, this.icon, this.route);
}

class _NavSection extends StatefulWidget {
  final String title;
  final String currentRoute;
  final List<_NavItemData> items;
  final BuildContext context;
  final Widget Function(BuildContext, String, IconData, String) buildNavItem;

  const _NavSection({
    required this.title,
    required this.currentRoute,
    required this.items,
    required this.context,
    required this.buildNavItem,
  });

  @override
  State<_NavSection> createState() => _NavSectionState();
}

class _NavSectionState extends State<_NavSection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    // Expand initially if any item matches the current route
    _isExpanded = widget.items.any((item) {
      final route = item.route;
      return widget.currentRoute == route || (route != '/' && widget.currentRoute.startsWith(route));
    });
  }

  @override
  void didUpdateWidget(covariant _NavSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the route changed and matches a child item, expand it
    final hasMatchingRoute = widget.items.any((item) {
      final route = item.route;
      return widget.currentRoute == route || (route != '/' && widget.currentRoute.startsWith(route));
    });
    if (hasMatchingRoute) {
      _isExpanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Theme.of(context).primaryColor, letterSpacing: 1),
                ),
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 14,
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: _isExpanded
              ? Column(
                  children: widget.items.map((item) {
                    return widget.buildNavItem(widget.context, item.title, item.icon, item.route);
                  }).toList(),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
