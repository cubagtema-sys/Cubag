import re

with open('lib/components/app_layout.dart', 'r') as f:
    content = f.read()

# 1. Update build method
build_old = """  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final notificationService = Provider.of<NotificationService>(context);
    final unreadCount = notificationService.unreadCount;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 800;
    final isSmall = size.width < 600;

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
  }"""

build_new = """  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final notificationService = Provider.of<NotificationService>(context);
    final unreadCount = notificationService.unreadCount;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 800;
    final isSmall = size.width < 600;
    final primary = Theme.of(context).primaryColor;
    final currentRoute = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      backgroundColor: isDesktop ? Theme.of(context).scaffoldBackgroundColor : primary,
      appBar: isDesktop ? null : AppBar(
        backgroundColor: primary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleSpacing: isSmall ? 16 : 24,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.title, 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: isSmall ? 18 : 20, letterSpacing: -0.5),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
        ],
      ),
    );
  }"""

content = content.replace(build_old, build_new)

# 2. Update Notification Icon
noti_old = """  Widget _buildNotificationIcon(BuildContext context, String? role, bool isSmall, int unreadCount) {
    // Point the notification icon to the notifications page
    final targetRoute = role == 'admin' ? '/admin/announcements' : '/notifications';
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.notifications_none_rounded, color: const Color(0xFF64748b), size: isSmall ? 22 : 26),
          onPressed: () => context.go(targetRoute),
        ),"""

noti_new = """  Widget _buildNotificationIcon(BuildContext context, String? role, bool isSmall, int unreadCount, {bool isDark = false}) {
    // Point the notification icon to the notifications page
    final targetRoute = role == 'admin' ? '/admin/announcements' : '/notifications';
    final iconColor = isDark ? Colors.white : const Color(0xFF64748b);
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.notifications_none_rounded, color: iconColor, size: isSmall ? 22 : 26),
          onPressed: () => context.go(targetRoute),
        ),"""

content = content.replace(noti_old, noti_new)

# 3. Update Profile Menu
prof_old = """  Widget _buildProfileMenu(BuildContext context, AuthService authService, bool isSmall) {
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
      ),"""

prof_new = """  Widget _buildProfileMenu(BuildContext context, AuthService authService, bool isSmall, {bool isDark = false}) {
    final photoUrl = authService.userPhotoUrl;
    final primary = Theme.of(context).primaryColor;
    final borderColor = isDark ? Colors.white30 : const Color(0xFFe2e8f0);
    
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: borderColor, width: 1.5)),
        child: CircleAvatar(
          radius: isSmall ? 14 : 16,
          backgroundColor: const Color(0xFFf1f5f9),
          backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? CachedNetworkImageProvider(photoUrl) : null,
          child: (photoUrl == null || photoUrl.isEmpty) ? Icon(Icons.person_rounded, color: isDark ? Colors.black26 : const Color(0xFF94a3b8), size: isSmall ? 18 : 20) : null,
        ),
      ),"""

content = content.replace(prof_old, prof_new)

# 4. Remove drawer and add bottom nav
drawer_old = """  Widget _buildDrawer(BuildContext context, String? role) {
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
  }"""

bottom_new = """  Widget _buildBottomNav(BuildContext context, String? role, String currentRoute) {
    final isAdmin = role == 'admin' || role == 'sub_admin';
    final primary = Theme.of(context).primaryColor;
    
    int currentIndex = 0;
    if (isAdmin) {
      if (currentRoute.startsWith('/admin/members')) currentIndex = 1;
      else if (currentRoute.startsWith('/admin/payments') || currentRoute.startsWith('/admin/fees')) currentIndex = 2;
      else if (currentRoute == '/menu') currentIndex = 3;
    } else {
      if (currentRoute.startsWith('/networking')) currentIndex = 1;
      else if (currentRoute.startsWith('/payments')) currentIndex = 2;
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
          if (index == 3) _showMobileMenu(context, role, currentRoute);
        } else {
          if (index == 0) context.go('/dashboard');
          if (index == 1) context.go('/networking');
          if (index == 2) context.go('/payments');
          if (index == 3) _showMobileMenu(context, role, currentRoute);
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

  void _showMobileMenu(BuildContext context, String? role, String currentRoute) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 16),
            const Text('Menu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Expanded(child: _buildNavItems(context, role, controller: scrollController)),
          ],
        ),
      ),
    );
  }"""

content = content.replace(drawer_old, bottom_new)

# 5. Update _buildNavItems to accept ScrollController
nav_old = """  Widget _buildNavItems(BuildContext context, String? role) {"""
nav_new = """  Widget _buildNavItems(BuildContext context, String? role, {ScrollController? controller}) {"""
content = content.replace(nav_old, nav_new)

list_old = """    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),"""
list_new = """    return ListView(
      controller: controller,
      padding: const EdgeInsets.symmetric(vertical: 16),"""
content = content.replace(list_old, list_new)

with open('lib/components/app_layout.dart', 'w') as f:
    f.write(content)
