import re

with open('lib/pages/dashboard_page.dart', 'r') as f:
    content = f.read()

old_quick_action_usage = """                    // Quick Shortcuts
                    _sectionCard(
                      title: 'Quick Shortcuts',
                      icon: Icons.apps,
                      child: GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: isMobile ? 2 : 4,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: isMobile ? 2.5 : 1.3,
                        padding: const EdgeInsets.all(12),
                        children: [
                          _quickAction(context, Icons.payments, 'Pay Dues', '/payments', isMobile),
                          _quickAction(context, Icons.bar_chart, 'Live Data', '/live-data', isMobile),
                          _quickAction(context, Icons.group, 'Networking', '/networking', isMobile),
                          _quickAction(context, Icons.support_agent, 'Support', '/engagement', isMobile),
                        ],
                      ),
                    ),"""

new_quick_action_usage = """                    // Quick Shortcuts (ECG Style Grid)
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: isMobile ? 2 : 4,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: isMobile ? 1.4 : 1.3,
                      padding: EdgeInsets.zero,
                      children: [
                        _quickAction(context, Icons.payments_outlined, 'Pay Dues', '/payments', isMobile, color: const Color(0xFF3b82f6), subtext: 'Renew your license'),
                        _quickAction(context, Icons.receipt_long_outlined, 'Statement', '/payments', isMobile, color: const Color(0xFFef4444), subtext: 'View transactions'),
                        _quickAction(context, Icons.bar_chart_rounded, 'Live Data', '/live-data', isMobile, color: const Color(0xFF10b981), subtext: 'Platform stats'),
                        _quickAction(context, Icons.support_agent_rounded, 'Support', '/engagement', isMobile, color: const Color(0xFF8b5cf6), subtext: 'Create a ticket'),
                      ],
                    ),"""

content = content.replace(old_quick_action_usage, new_quick_action_usage)

old_quick_action_def = """  Widget _quickAction(BuildContext context, IconData icon, String label, String route, bool isMobile) {
    final primary = Theme.of(context).primaryColor;
    return InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primary.withValues(alpha: 0.1)),
        ),
        child: isMobile 
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: primary, size: 18),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label, 
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 40, height: 40, decoration: BoxDecoration(color: primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: primary, size: 20)),
                  const SizedBox(height: 6),
                  Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                ],
              ),
      ),
    );
  }"""

new_quick_action_def = """  Widget _quickAction(BuildContext context, IconData icon, String label, String route, bool isMobile, {required Color color, String? subtext}) {
    return InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const Spacer(),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800), textAlign: TextAlign.center, maxLines: 1),
            if (subtext != null) ...[
              const SizedBox(height: 4),
              Text(subtext, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
            ]
          ],
        ),
      ),
    );
  }"""

content = content.replace(old_quick_action_def, new_quick_action_def)

# Remove the sectionCard border to look cleaner
old_section_card = """  Widget _sectionCard({required String title, required IconData icon, required Widget child}) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.withAlpha(20))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [Icon(icon, color: Theme.of(context).primaryColor, size: 20), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }"""

new_section_card = """  Widget _sectionCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [Icon(icon, color: Theme.of(context).primaryColor, size: 20), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))]),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }"""

content = content.replace(old_section_card, new_section_card)

with open('lib/pages/dashboard_page.dart', 'w') as f:
    f.write(content)

