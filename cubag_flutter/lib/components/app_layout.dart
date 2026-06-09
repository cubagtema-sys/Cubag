import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationService>(context, listen: false).fetchUnreadCount();
    });
    _loadUserPhoto();
  }

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

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final notificationService = Provider.of<NotificationService>(context);
    final unreadCount = notificationService.unreadCount;
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
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: const Color(0xFFf1f5f9), height: 1)),
        title: Text(
          widget.title, 
          style: TextStyle(color: const Color(0xFF0f172a), fontWeight: FontWeight.w800, fontSize: isSmall ? 16 : 18, letterSpacing: -0.5),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (!widget.hideSearch)
            IconButton(
              icon: Icon(Icons.search_rounded, color: const Color(0xFF64748b), size: isSmall ? 22 : 24),
              onPressed: () => showSearch(
                context: context,
                delegate: authService.userRole == 'admin' ? AdminSearchDelegate() : MemberSearchDelegate(),
              ),
            ),
          _buildNotificationIcon(context, authService.userRole, isSmall, unreadCount),
          const SizedBox(width: 4),
          _buildProfileMenu(context, authService, isSmall),
          const SizedBox(width: 12),
        ],
      ),
      drawer: isDesktop ? null : _buildDrawer(context, authService.userRole),
      body: Row(
        children: [
          if (isDesktop) _buildSidebar(context, authService.userRole),
          Expanded(
            child: Column(
              children: [
                if (isDesktop) _buildDesktopHeader(context, authService, unreadCount),
                Expanded(
                  child: widget.scrollable
                      ? SingleChildScrollView(
                          padding: EdgeInsets.all(isSmall ? 16 : 20),
                          child: widget.child,
                        )
                      : Padding(
                          padding: EdgeInsets.all(isSmall ? 16 : 20),
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

  Widget _buildNotificationIcon(BuildContext context, String? role, bool isSmall, int unreadCount) {
    final targetRoute = role == 'admin' ? '/admin/announcements' : '/notifications';
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.notifications_none_rounded, color: const Color(0xFF64748b), size: isSmall ? 22 : 26),
          onPressed: () => context.go(targetRoute),
        ),
        if (unreadCount > 0)
          Positioned(
            right: 8, top: 10,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(color: const Color(0xFFef4444), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white, width: 2)),
              constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildProfileMenu(BuildContext context, AuthService authService, bool isSmall) {
    final photoUrl = authService.userPhotoUrl;
    final primary = Theme.of(context).primaryColor;

    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFe2e8f0), width: 1.5)),
        child: CircleAvatar(
          radius: isSmall ? 14 : 16,
          backgroundColor: const Color(0xFFf1f5f9),
          backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? CachedNetworkImageProvider(photoUrl) : null,
          child: (photoUrl == null || photoUrl.isEmpty) ? Icon(Icons.person_rounded, color: const Color(0xFF94a3b8), size: isSmall ? 18 : 20) : null,
        ),
      ),
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => [
        PopupMenuItem(child: const Row(children: [Icon(Icons.person_outline, size: 20), SizedBox(width: 12), Text('My Profile', style: TextStyle(fontWeight: FontWeight.w600))]), onTap: () => context.go('/profile')),
        PopupMenuItem(child: const Row(children: [Icon(Icons.settings_outlined, size: 20), SizedBox(width: 12), Text('Settings', style: TextStyle(fontWeight: FontWeight.w600))]), onTap: () => context.go(authService.userRole == 'admin' ? '/admin/settings' : '/settings')),
        const PopupMenuDivider(),
        PopupMenuItem(
          child: const Row(children: [Icon(Icons.logout_rounded, size: 20, color: Color(0xFFef4444)), SizedBox(width: 12), Text('Sign Out', style: TextStyle(color: Color(0xFFef4444), fontWeight: FontWeight.bold))]),
          onTap: () { authService.logout(); context.go('/login'); },
        ),
      ],
    );
  }

  Widget _buildDesktopHeader(BuildContext context, AuthService authService, int unreadCount) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFf1f5f9)))),
      child: Row(
        children: [
          Text(widget.title, style: const TextStyle(color: Color(0xFF0f172a), fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -0.5)),
          const Spacer(),
          if (!widget.hideSearch)
            IconButton(
              icon: const Icon(Icons.search_rounded, color: Color(0xFF64748b)),
              onPressed: () => showSearch(
                context: context,
                delegate: authService.userRole == 'admin' ? AdminSearchDelegate() : MemberSearchDelegate(),
              ),
            ),
          _buildNotificationIcon(context, authService.userRole, false, unreadCount),
          const SizedBox(width: 8),
          _buildProfileMenu(context, authService, false),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, String? role) {
    final primary = Theme.of(context).primaryColor;
    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [primary, const Color(0xFFe06920)])),
          child: const Row(children: [
            AppLogo(size: 48, borderRadius: 12, showShadow: true),
            SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('CUBAG', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              Text('Member Portal', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
            ])),
          ]),
        ),
        Expanded(child: _buildNavItems(context, role)),
      ]),
    );
  }

  Widget _buildSidebar(BuildContext context, String? role) {
    final primary = Theme.of(context).primaryColor;
    return Container(
      width: 260,
      decoration: const BoxDecoration(color: Colors.white, border: Border(right: BorderSide(color: Color(0xFFf1f5f9)))),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [primary, const Color(0xFFe06920)])),
          child: const Row(children: [
            AppLogo(size: 44, borderRadius: 11, showShadow: true),
            SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('CUBAG', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
              Text('Enterprise Platform', style: TextStyle(color: Colors.white70, fontSize: 11)),
            ])),
          ]),
        ),
        Expanded(child: _buildNavItems(context, role)),
      ]),
    );
  }

  Widget _buildNavItems(BuildContext context, String? role) {
    final isAdmin = role == 'admin';
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final primary = Theme.of(context).primaryColor;

    List<Widget> sections = [];
    if (isAdmin) {
      sections = [
        _buildSection(context, 'CORE', currentRoute, [
          _NavItemData('Dashboard', Icons.grid_view_rounded, '/admin/dashboard'),
          _NavItemData('Members', Icons.people_alt_rounded, '/admin/members'),
          _NavItemData('Announcements', Icons.campaign_rounded, '/admin/announcements'),
        ]),
        _buildSection(context, 'FINANCE', currentRoute, [
          _NavItemData('Financials', Icons.account_balance_wallet_rounded, '/admin/payments'),
          _NavItemData('Platform Fees', Icons.receipt_rounded, '/admin/fees'),
        ]),
      ];
    } else {
      sections = [
        _buildSection(context, 'MAIN', currentRoute, [
          _NavItemData('Dashboard', Icons.home_rounded, '/dashboard'),
          _NavItemData('Announcements', Icons.campaign_rounded, '/announcements'),
          _NavItemData('Notifications', Icons.notifications_rounded, '/notifications'),
        ]),
        _buildSection(context, 'SERVICES', currentRoute, [
          _NavItemData('Payments', Icons.account_balance_wallet_rounded, '/payments'),
          _NavItemData('Tasks & Compliance', Icons.task_alt_rounded, '/tasks'),
          _NavItemData('License Renewal', Icons.verified_user_rounded, '/license-renewal'),
          _NavItemData('Networking', Icons.language_rounded, '/networking'),
          _NavItemData('Messaging', Icons.chat_bubble_outline_rounded, '/messaging'),
        ]),
        _buildSection(context, 'RESOURCES', currentRoute, [
          _NavItemData('Live Logistics', Icons.analytics_rounded, '/live-data'),
          _NavItemData('Vessel Movements', Icons.directions_boat_rounded, '/vessel-movements'),
          _NavItemData('Vanning Schedules', Icons.calendar_today_rounded, '/vanning-schedules'),
        ]),
      ];
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        ...sections,
        const Divider(indent: 20, endIndent: 20, color: Color(0xFFf1f5f9)),
        _navTile(context, 'Settings', Icons.settings_rounded, isAdmin ? '/admin/settings' : '/settings', currentRoute),
      ],
    );
  }

  Widget _buildSection(BuildContext context, String title, String currentRoute, List<_NavItemData> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF94a3b8), letterSpacing: 1.2)),
        ),
        ...items.map((item) => _navTile(context, item.title, item.icon, item.route, currentRoute)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _navTile(BuildContext context, String title, IconData icon, String route, String current) {
    final active = current == route || (route != '/' && current.startsWith(route));
    final primary = Theme.of(context).primaryColor;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: active ? primary.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          onTap: () {
            context.go(route);
            if (Scaffold.of(context).isDrawerOpen) Navigator.pop(context);
          },
          dense: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: Icon(icon, color: active ? primary : const Color(0xFF64748b), size: 22),
          title: Text(title, style: TextStyle(color: active ? primary : const Color(0xFF334155), fontWeight: active ? FontWeight.w700 : FontWeight.w600, fontSize: 14)),
        ),
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
