import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../components/admin_search_delegate.dart';
import '../components/member_search_delegate.dart';
import 'package:google_fonts/google_fonts.dart';
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
  bool _isSidebarCollapsed = false;

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
    final isSmall = size.width < 600;
    final primary = Theme.of(context).primaryColor;
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDesktop 
          ? (isThemeDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFf8fafc)) 
          : const Color(0xFFf8fafc),
      appBar: isDesktop ? null : AppBar(
        backgroundColor: primary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleSpacing: isSmall ? 16 : 24,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            const AppLogo(size: 28, borderRadius: 6, showShadow: false),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.title, 
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: isSmall ? 18 : 20, letterSpacing: -0.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (!widget.hideSearch)
            IconButton(
              icon: Icon(Icons.search_rounded, color: Colors.white, size: isSmall ? 22 : 24),
              onPressed: () => showSearch(
                context: context,
                delegate: authService.userRole == 'admin' ? AdminSearchDelegate() : MemberSearchDelegate(),
              ),
            ),
          _buildNotificationIcon(context, authService.userRole, isSmall, unreadCount, isDark: true),
          const SizedBox(width: 4),
          _buildProfileMenu(context, authService, isSmall, isDark: true),
          const SizedBox(width: 12),
        ],
      ),
      bottomNavigationBar: isDesktop ? null : _buildBottomNav(context, authService.userRole, currentRoute),
      body: Row(
        children: [
          if (isDesktop) _buildSidebar(context, authService.userRole),
          Expanded(
            child: isDesktop ? Column(
              children: [
                _buildDesktopHeader(context, authService, unreadCount),
                Expanded(
                  child: widget.scrollable
                      ? SingleChildScrollView(padding: const EdgeInsets.all(20), child: widget.child)
                      : Padding(padding: const EdgeInsets.all(20), child: widget.child),
                ),
              ],
            ) : Container(
              color: primary,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFf8fafc),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: widget.scrollable
                      ? SingleChildScrollView(padding: const EdgeInsets.all(16), child: widget.child)
                      : Padding(padding: const EdgeInsets.all(16), child: widget.child),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationIcon(BuildContext context, String? role, bool isSmall, int unreadCount, {bool isDark = false}) {
    // Point the notification icon to the notifications page
    final targetRoute = role == 'admin' ? '/admin/announcements' : '/notifications';
    final iconColor = isDark ? Colors.white : const Color(0xFF64748b);
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.notifications_none_rounded, color: iconColor, size: isSmall ? 22 : 26),
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

  Widget _buildProfileMenu(BuildContext context, AuthService authService, bool isSmall, {bool isDark = false}) {
    final photoUrl = authService.userPhotoUrl;
    final primary = Theme.of(context).primaryColor;
    final borderColor = isDark ? Colors.white30 : const Color(0xFFe2e8f0);
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    final dropdownBg = isThemeDark ? const Color(0xFF1e1f26) : Colors.white;
    final textColor = isThemeDark ? Colors.white : const Color(0xFF0f172a);
    final subTextColor = isThemeDark ? Colors.white70 : const Color(0xFF64748b);
    final borderThemeColor = isThemeDark ? const Color(0xFF2d2e38) : const Color(0xFFe2e8f0);
    
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: borderColor, width: 1.5)),
        child: CircleAvatar(
          radius: isSmall ? 14 : 16,
          backgroundColor: isThemeDark ? const Color(0xFF2a2b36) : const Color(0xFFf1f5f9),
          backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? CachedNetworkImageProvider(photoUrl) : null,
          child: (photoUrl == null || photoUrl.isEmpty) ? Icon(Icons.person_rounded, color: isDark ? Colors.white70 : const Color(0xFF94a3b8), size: isSmall ? 18 : 20) : null,
        ),
      ),
      offset: const Offset(0, 48),
      color: dropdownBg,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderThemeColor, width: 1.5),
      ),
      itemBuilder: (context) => [
        // User Details Header
        PopupMenuItem<String>(
          enabled: false,
          child: Container(
            width: 170,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: primary.withValues(alpha: 0.1),
                  backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? CachedNetworkImageProvider(photoUrl) : null,
                  child: (photoUrl == null || photoUrl.isEmpty)
                      ? Icon(Icons.person_rounded, color: primary, size: 22)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        authService.userName ?? 'Member',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        authService.userEmail ?? (authService.userRole ?? 'Member').toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: subTextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        PopupMenuItem<String>(
          enabled: false,
          height: 1,
          child: Divider(color: borderThemeColor, height: 1),
        ),
        // My Profile Item
        PopupMenuItem<String>(
          onTap: () => context.go('/profile'),
          child: Container(
            width: 170,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                     color: primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.person_outline_rounded, size: 18, color: primary),
                ),
                const SizedBox(width: 12),
                Text(
                  'My Profile',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Settings Item
        PopupMenuItem<String>(
          onTap: () => context.go(authService.userRole == 'admin' ? '/admin/settings' : '/settings'),
          child: Container(
            width: 170,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                     color: primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.settings_outlined, size: 18, color: primary),
                ),
                const SizedBox(width: 12),
                Text(
                  'Settings',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        PopupMenuItem<String>(
          enabled: false,
          height: 1,
          child: Divider(color: borderThemeColor, height: 1),
        ),
        // Sign Out Item
        PopupMenuItem<String>(
          onTap: () {
            authService.logout();
            context.go('/login');
          },
          child: Container(
            width: 170,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFef4444).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFFef4444)),
                ),
                const SizedBox(width: 12),
                Text(
                  'Sign Out',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                    color: const Color(0xFFef4444),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopHeader(BuildContext context, AuthService authService, int unreadCount) {
    final isAdmin = authService.userRole == 'admin' || authService.userRole == 'sub_admin';
    final isThemeDark = Theme.of(context).brightness == Brightness.dark;
    final headerBg = isThemeDark ? const Color(0xFF16171d) : Colors.white;
    final borderThemeColor = isThemeDark ? const Color(0xFF2d2e38) : const Color(0xFFf1f5f9);
    final textColor = isThemeDark ? Colors.white : const Color(0xFF0f172a);
    final iconColor = isThemeDark ? Colors.white70 : const Color(0xFF64748b);

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: headerBg,
        border: Border(bottom: BorderSide(color: borderThemeColor, width: 1.5)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _isSidebarCollapsed ? Icons.menu_rounded : Icons.menu_open_rounded,
              color: iconColor,
            ),
            onPressed: () {
              setState(() {
                _isSidebarCollapsed = !_isSidebarCollapsed;
              });
            },
            tooltip: _isSidebarCollapsed ? 'Expand Sidebar' : 'Collapse Sidebar',
          ),
          const SizedBox(width: 8),
          if (!isAdmin) ...[
            const AppLogo(size: 32, borderRadius: 8, showShadow: false), 
            const SizedBox(width: 12),
          ],
          Text(
            widget.title, 
            style: GoogleFonts.outfit(
              color: textColor, 
              fontWeight: FontWeight.w800, 
              fontSize: 20, 
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          if (!widget.hideSearch)
            IconButton(
              icon: Icon(Icons.search_rounded, color: iconColor),
              onPressed: () => showSearch(
                context: context,
                delegate: authService.userRole == 'admin' ? AdminSearchDelegate() : MemberSearchDelegate(),
              ),
            ),
          _buildNotificationIcon(context, authService.userRole, false, unreadCount, isDark: isThemeDark),
          const SizedBox(width: 4),
          _buildProfileMenu(context, authService, false, isDark: isThemeDark),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context, String? role, String currentRoute) {
    final isAdmin = role == 'admin' || role == 'sub_admin';
    final primary = Theme.of(context).primaryColor;
    
    int currentIndex = 0;
    if (isAdmin) {
      if (currentRoute.startsWith('/admin/members')) {
        currentIndex = 1;
      } else if (currentRoute.startsWith('/admin/payments') || currentRoute.startsWith('/admin/fees')) currentIndex = 2;
      else if (currentRoute == '/menu') currentIndex = 3;
    } else {
      if (currentRoute.startsWith('/networking')) {
        currentIndex = 1;
      } else if (currentRoute.startsWith('/payments')) currentIndex = 2;
      else if (currentRoute == '/menu') currentIndex = 3;
    }

    return BottomNavigationBar(
      currentIndex: currentIndex,
      selectedItemColor: primary,
      unselectedItemColor: Colors.grey.shade500,
      showUnselectedLabels: true,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      elevation: 16,
      onTap: (index) {
        if (isAdmin) {
          if (index == 0) context.go('/admin/dashboard');
          if (index == 1) context.go('/admin/members');
          if (index == 2) context.go('/admin/payments');
          if (index == 3) context.go('/menu');
        } else {
          if (index == 0) context.go('/dashboard');
          if (index == 1) context.go('/networking');
          if (index == 2) context.go('/payments');
          if (index == 3) context.go('/menu');
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.group_rounded), label: 'Members'),
        BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded), label: 'Finance'),
        BottomNavigationBarItem(icon: Icon(Icons.menu_rounded), label: 'Menu'),
      ],
    );
  }

  Widget _buildSidebar(BuildContext context, String? role) {
    final authService = Provider.of<AuthService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sidebarBg = isDark ? const Color(0xFF16171d) : Colors.white;
    final borderThemeColor = isDark ? const Color(0xFF2d2e38) : const Color(0xFFf1f5f9);
    final textColor = isDark ? Colors.white : const Color(0xFF0f172a);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: _isSidebarCollapsed ? 76 : 260,
      decoration: BoxDecoration(
        color: sidebarBg,
        border: Border(right: BorderSide(color: borderThemeColor, width: 1.5)),
      ),
      child: Column(
        children: [
          // Sidebar Header
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderThemeColor, width: 1.5)),
            ),
            child: _isSidebarCollapsed
                ? const Center(child: AppLogo(size: 32, borderRadius: 8, showShadow: false))
                : Row(
                    children: [
                      const AppLogo(size: 32, borderRadius: 8, showShadow: false),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'CUBAG',
                              style: GoogleFonts.outfit(
                                color: textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            _buildRoleBadge(context, role),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          // Sidebar Items
          Expanded(
            child: _buildNavItems(context, role),
          ),
          // Sidebar Footer
          _buildSidebarFooter(context, authService),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(BuildContext context, String? role) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayRole = (role ?? 'Member').replaceAll('_', ' ').toUpperCase();
    Color badgeBg;
    Color badgeText;
    
    if (role == 'admin') {
      badgeBg = isDark ? const Color(0xFF3e2723) : const Color(0xFFfff3e0);
      badgeText = isDark ? const Color(0xFFffb74d) : const Color(0xFFe65100);
    } else if (role == 'sub_admin') {
      badgeBg = isDark ? const Color(0xFF004d40) : const Color(0xFFe0f2f1);
      badgeText = isDark ? const Color(0xFF4db6ac) : const Color(0xFF004d40);
    } else {
      badgeBg = isDark ? const Color(0xFF334155) : const Color(0xFFf1f5f9);
      badgeText = isDark ? const Color(0xFFcbd5e1) : const Color(0xFF475569);
    }
    
    return UnconstrainedBox(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
        decoration: BoxDecoration(
          color: badgeBg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          displayRole,
          style: GoogleFonts.inter(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: badgeText,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarFooter(BuildContext context, AuthService authService) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderThemeColor = isDark ? const Color(0xFF2d2e38) : const Color(0xFFf1f5f9);
    final textColor = isDark ? Colors.white : const Color(0xFF0f172a);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF64748b);
    final photoUrl = authService.userPhotoUrl;
    final primary = Theme.of(context).primaryColor;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: borderThemeColor, width: 1.5)),
      ),
      child: _isSidebarCollapsed
          ? Center(
              child: GestureDetector(
                onTap: () => context.go('/profile'),
                child: Tooltip(
                  message: authService.userName ?? 'My Profile',
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: borderThemeColor, width: 1.5),
                    ),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: isDark ? const Color(0xFF2a2b36) : const Color(0xFFf1f5f9),
                      backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                          ? CachedNetworkImageProvider(photoUrl)
                          : null,
                      child: (photoUrl == null || photoUrl.isEmpty)
                          ? Icon(Icons.person_rounded, color: isDark ? Colors.white70 : const Color(0xFF94a3b8), size: 18)
                          : null,
                    ),
                  ),
                ),
              ),
            )
          : Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1e1f26) : const Color(0xFFf8fafc),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderThemeColor),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: primary.withValues(alpha: 0.1),
                    backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                        ? CachedNetworkImageProvider(photoUrl)
                        : null,
                    child: (photoUrl == null || photoUrl.isEmpty)
                        ? Icon(Icons.person_rounded, color: primary, size: 18)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          authService.userName ?? 'Member',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          authService.userEmail ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: subTextColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Sign Out',
                    child: IconButton(
                      icon: const Icon(Icons.logout_rounded, size: 16, color: Color(0xFFef4444)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        authService.logout();
                        context.go('/login');
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildNavItems(BuildContext context, String? role, {ScrollController? controller}) {
    final isAdmin = role == 'admin';
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? const Color(0xFF2d2e38) : const Color(0xFFf1f5f9);

    List<Widget> sections = [];
    if (isAdmin) {
      sections = [
        _buildSection(context, 'CORE MANAGEMENT', currentRoute, [
          _NavItemData('Dashboard', Icons.grid_view_rounded, '/admin/dashboard'),
          _NavItemData('Members', Icons.people_alt_rounded, '/admin/members'),
          _NavItemData('Announcements', Icons.campaign_rounded, '/admin/announcements'),
        ]),
        _buildSection(context, 'OPERATIONS & SUPPORT', currentRoute, [
          _NavItemData('Cargo Schedules', Icons.local_shipping_rounded, '/admin/cargo-schedules'),
          _NavItemData('Intelligence Hub', Icons.cell_tower_rounded, '/admin/intelligence'),
          _NavItemData('Support Tickets', Icons.support_agent_rounded, '/admin/tickets'),
        ]),
        _buildSection(context, 'FINANCIALS & RECORDS', currentRoute, [
          _NavItemData('Financial Center', Icons.account_balance_wallet_rounded, '/admin/payments'),
          _NavItemData('Payment Settings', Icons.payment_rounded, '/admin/payment-settings'),
          _NavItemData('Platform Fees', Icons.receipt_rounded, '/admin/fees'),
        ]),
        _buildSection(context, 'ENGAGEMENT & EVENTS', currentRoute, [
          _NavItemData('Events', Icons.event_rounded, '/admin/events'),
          _NavItemData('Surveys & Elections', Icons.how_to_vote_rounded, '/admin/surveys'),
        ]),
        _buildSection(context, 'ADMINISTRATION', currentRoute, [
          _NavItemData('Sub-Admins', Icons.admin_panel_settings_rounded, '/admin/sub-admins'),
          _NavItemData('Audit Log', Icons.history_rounded, '/admin/audit-log'),
        ]),
      ];
    } else if (role == 'sub_admin') {
      final auth = Provider.of<AuthService>(context, listen: false);
      final allAdminItems = <String, List<_NavItemData>>{
        'members':          [_NavItemData('Members', Icons.people_alt_rounded, '/admin/members')],
        'announcements':    [_NavItemData('Announcements', Icons.campaign_rounded, '/admin/announcements')],
        'schedules':        [_NavItemData('Cargo Schedules', Icons.local_shipping_rounded, '/admin/cargo-schedules')],
        'intelligence':     [_NavItemData('Intelligence Hub', Icons.cell_tower_rounded, '/admin/intelligence')],
        'tickets':          [_NavItemData('Support Tickets', Icons.support_agent_rounded, '/admin/tickets')],
        'payments':         [_NavItemData('Financial Center', Icons.account_balance_wallet_rounded, '/admin/payments')],
        'fees':             [_NavItemData('Platform Fees', Icons.receipt_rounded, '/admin/fees')],
        'events':           [_NavItemData('Events', Icons.event_rounded, '/admin/events')],
        'surveys':          [_NavItemData('Surveys & Elections', Icons.how_to_vote_rounded, '/admin/surveys')],
        'audit_log':        [_NavItemData('Audit Log', Icons.history_rounded, '/admin/audit-log')],
        'settings':         [_NavItemData('Settings', Icons.settings_rounded, '/admin/settings')],
      };
      
      final permittedItems = <_NavItemData>[];
      final orderedKeys = ['members', 'announcements', 'schedules', 'intelligence', 'tickets', 'payments', 'fees', 'events', 'surveys', 'audit_log', 'settings'];
      for (final key in orderedKeys) {
        if (auth.hasPermission(key)) permittedItems.addAll(allAdminItems[key] ?? []);
      }
      
      sections = [
        _buildSection(context, 'OVERVIEW', currentRoute, [
          _NavItemData('Dashboard', Icons.grid_view_rounded, '/admin/dashboard'),
        ]),
        if (permittedItems.isNotEmpty)
          _buildSection(context, 'MY MODULES', currentRoute, permittedItems),
      ];
    } else {
      sections = [
        _buildSection(context, 'MAIN', currentRoute, [
          _NavItemData('Dashboard', Icons.home_rounded, '/dashboard'),
          _NavItemData('Announcements', Icons.campaign_rounded, '/announcements'),
        ]),
        _buildSection(context, 'SERVICES', currentRoute, [
          _NavItemData('Payments', Icons.account_balance_wallet_rounded, '/payments'),
          _NavItemData('Tasks & Compliance', Icons.task_alt_rounded, '/tasks'),
          _NavItemData('License Renewal', Icons.verified_user_rounded, '/license-renewal'),
          _NavItemData('Networking', Icons.language_rounded, '/networking'),
          _NavItemData('Messaging', Icons.chat_bubble_outline_rounded, '/messaging'),
          _NavItemData('Events', Icons.event_rounded, '/events'),
        ]),
        _buildSection(context, 'RESOURCES', currentRoute, [
          _NavItemData('Live Logistics', Icons.analytics_rounded, '/live-data'),
          _NavItemData('Vessel Movements', Icons.directions_boat_rounded, '/vessel-movements'),
          _NavItemData('Vanning Schedules', Icons.calendar_today_rounded, '/vanning-schedules'),
        ]),
      ];
    }

    return ListView(
      controller: controller,
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        ...sections,
        Divider(
          indent: _isSidebarCollapsed ? 12 : 20,
          endIndent: _isSidebarCollapsed ? 12 : 20,
          color: dividerColor,
        ),
        _navTile(
          context, 
          'Settings', 
          Icons.settings_rounded, 
          (isAdmin || role == 'sub_admin') ? '/admin/settings' : '/settings', 
          currentRoute,
        ),
      ],
    );
  }

  Widget _buildSection(BuildContext context, String title, String currentRoute, List<_NavItemData> items) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? const Color(0xFF2d2e38) : const Color(0xFFf1f5f9);

    if (_isSidebarCollapsed) {
      return Column(
        children: [
          ...items.map((item) => _navTile(context, item.title, item.icon, item.route, currentRoute)),
          Divider(indent: 12, endIndent: 12, color: dividerColor, height: 16),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
          child: Text(
            title, 
            style: GoogleFonts.outfit(
              fontSize: 9.5, 
              fontWeight: FontWeight.w800, 
              color: const Color(0xFF94a3b8), 
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...items.map((item) => _navTile(context, item.title, item.icon, item.route, currentRoute)),
        const SizedBox(height: 2),
      ],
    );
  }

  Widget _navTile(BuildContext context, String title, IconData icon, String route, String current) {
    final active = current == route || (route != '/' && current.startsWith(route));
    final primary = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeBg = primary.withValues(alpha: 0.08);
    final hoverBg = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03);
    final activeIconColor = primary;
    final inactiveIconColor = isDark ? const Color(0xFF94a3b8) : const Color(0xFF64748b);
    final activeTextColor = primary;
    final inactiveTextColor = isDark ? const Color(0xFFcbd5e1) : const Color(0xFF334155);

    final tileContent = Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: active ? activeBg : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {
            context.go(route);
            if (Scaffold.maybeOf(context)?.isDrawerOpen == true) Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(8),
          hoverColor: hoverBg,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: _isSidebarCollapsed ? 0 : 14,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: _isSidebarCollapsed 
                      ? MainAxisAlignment.center 
                      : MainAxisAlignment.start,
                  children: [
                    Icon(
                      icon,
                      color: active ? activeIconColor : inactiveIconColor,
                      size: 20,
                    ),
                    if (!_isSidebarCollapsed) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.outfit(
                            color: active ? activeTextColor : inactiveTextColor,
                            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (active)
                Positioned(
                  left: 0,
                  top: 8,
                  bottom: 8,
                  child: Container(
                    width: 3.5,
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (_isSidebarCollapsed) {
      return Tooltip(
        message: title,
        preferBelow: false,
        verticalOffset: 20,
        margin: const EdgeInsets.only(left: 8),
        child: tileContent,
      );
    }
    return tileContent;
  }
}

class _NavItemData {
  final String title;
  final IconData icon;
  final String route;
  _NavItemData(this.title, this.icon, this.route);
}
