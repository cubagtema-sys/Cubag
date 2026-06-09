import re

# 1. Update AppLayout
with open('lib/components/app_layout.dart', 'r') as f:
    content = f.read()

# Add Logo to Mobile AppBar title
mobile_title_old = """        title: Text(
          widget.title, 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: isSmall ? 18 : 20, letterSpacing: -0.5),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),"""

mobile_title_new = """        title: Row(
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
        ),"""

content = content.replace(mobile_title_old, mobile_title_new)

# Add Logo to Desktop Header
desktop_title_old = "Text(widget.title, style: const TextStyle(color: Color(0xFF0f172a), fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -0.5)),"
desktop_title_new = "Row(children: [const AppLogo(size: 32, borderRadius: 8, showShadow: false), const SizedBox(width: 12), Text(widget.title, style: const TextStyle(color: Color(0xFF0f172a), fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -0.5))]),"
content = content.replace(desktop_title_old, desktop_title_new)

# Remove space between notifications and profile (desktop)
desktop_space_old = """          _buildNotificationIcon(context, authService.userRole, false, unreadCount),
          const SizedBox(width: 8),
          _buildProfileMenu(context, authService, false),"""
desktop_space_new = """          _buildNotificationIcon(context, authService.userRole, false, unreadCount),
          _buildProfileMenu(context, authService, false),"""
content = content.replace(desktop_space_old, desktop_space_new)

# Remove space between notifications and profile (mobile)
mobile_space_old = """          _buildNotificationIcon(context, authService.userRole, true, unreadCount),
          const SizedBox(width: 12),
          _buildProfileMenu(context, authService, true, isDark: true),
          SizedBox(width: isSmall ? 16 : 24),"""
mobile_space_new = """          _buildNotificationIcon(context, authService.userRole, true, unreadCount),
          _buildProfileMenu(context, authService, true, isDark: true),
          SizedBox(width: isSmall ? 16 : 24),"""
content = content.replace(mobile_space_old, mobile_space_new)

# Make Sidebar More Compact
# _navTile margin and font size
navtile_old = """    return Container(
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
    );"""
navtile_new = """    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      child: Material(
        color: active ? primary.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: ListTile(
          onTap: () {
            context.go(route);
            if (Scaffold.of(context).isDrawerOpen) Navigator.pop(context);
          },
          dense: true,
          minLeadingWidth: 20,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          visualDensity: const VisualDensity(vertical: -4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          leading: Icon(icon, color: active ? primary : const Color(0xFF64748b), size: 18),
          title: Text(title, style: TextStyle(color: active ? primary : const Color(0xFF334155), fontWeight: active ? FontWeight.w700 : FontWeight.w600, fontSize: 12)),
        ),
      ),
    );"""
content = content.replace(navtile_old, navtile_new)

# _buildSection padding and height
section_old = """        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF94a3b8), letterSpacing: 1.2)),
        ),
        ...items.map((item) => _navTile(context, item.title, item.icon, item.route, currentRoute)),
        const SizedBox(height: 8),"""
section_new = """        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
          child: Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF94a3b8), letterSpacing: 1.0)),
        ),
        ...items.map((item) => _navTile(context, item.title, item.icon, item.route, currentRoute)),
        const SizedBox(height: 2),"""
content = content.replace(section_old, section_new)

with open('lib/components/app_layout.dart', 'w') as f:
    f.write(content)

