import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Mobile bottom navigation shell for regular (non-admin) members.
/// Wraps member pages so a persistent bottom bar appears on mobile.
/// On desktop (>800px), the bottom bar is hidden — the sidebar handles nav.
class UserShell extends StatefulWidget {
  final Widget child;
  const UserShell({super.key, required this.child});

  @override
  State<UserShell> createState() => _UserShellState();
}

class _UserShellState extends State<UserShell> {
  int _currentIndex = 0;

  static const _tabs = [
    _TabItem('/dashboard',     'Home',     Icons.home_outlined,     Icons.home),
    _TabItem('/payments',      'Payments', Icons.payments_outlined, Icons.payments),
    _TabItem('/tasks',         'Tasks',    Icons.task_outlined,     Icons.task_alt),
    _TabItem('/messaging',     'Messages', Icons.chat_outlined,     Icons.chat),
    _TabItem('/profile',       'Profile',  Icons.person_outline,    Icons.person),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTabIndex();
  }

  void _syncTabIndex() {
    final location = GoRouterState.of(context).matchedLocation;
    for (int i = 0; i < _tabs.length; i++) {
      if (location == _tabs[i].route || location.startsWith('${_tabs[i].route}/')) {
        if (_currentIndex != i) setState(() => _currentIndex = i);
        return;
      }
    }
  }

  void _onTabTap(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    context.go(_tabs[index].route);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    // On desktop, skip the bottom bar — AppLayout sidebar handles navigation
    if (isDesktop) return widget.child;

    // On mobile: stack the child page on top of the bottom nav bar.
    // AppLayout already wraps its own Scaffold, so we avoid a double-Scaffold
    // by using a Column approach and injecting the bar below.
    return Column(
      children: [
        Expanded(child: widget.child),
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Material(
      color: Colors.white,
      elevation: 8,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFf0f0f0), width: 1)),
          boxShadow: [BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, -4))],
        ),
        child: SafeArea(
          top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_tabs.length, (i) {
              final tab = _tabs[i];
              final active = i == _currentIndex;
              return Expanded(
                child: InkWell(
                  onTap: () => _onTabTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: active ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            active ? tab.activeIcon : tab.icon,
                            color: active ? Theme.of(context).primaryColor : const Color(0xFF94a3b8),
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tab.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                            color: active ? Theme.of(context).primaryColor : const Color(0xFF94a3b8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    ),
  );
  }
}

class _TabItem {
  final String route;
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _TabItem(this.route, this.label, this.icon, this.activeIcon);
}
