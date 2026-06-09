import re

# 1. Fix dashboard_page.dart
with open('lib/pages/dashboard_page.dart', 'r') as f:
    dashboard_content = f.read()

dashboard_old = "    return AppLayout(\n      title: 'Dashboard',\n      child: _loading && _tasks.isEmpty"
dashboard_new = "    return AppLayout(\n      title: 'Dashboard',\n      scrollable: false,\n      child: _loading && _tasks.isEmpty"

dashboard_content = dashboard_content.replace(dashboard_old, dashboard_new)

with open('lib/pages/dashboard_page.dart', 'w') as f:
    f.write(dashboard_content)

# 2. Fix admin_members_page.dart
with open('lib/pages/admin_members_page.dart', 'r') as f:
    members_content = f.read()

members_old = """    return AppLayout(
      title: 'Association Members',
      child: Stack(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: ["""

members_new = """    return AppLayout(
      title: 'Association Members',
      scrollable: false,
      child: Stack(children: [
        SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: ["""

members_content = members_content.replace(members_old, members_new)

members_old_2 = """          if (!_loading) Center(child: Text('${filtered.length} of ${_members.length} members shown', style: const TextStyle(fontSize: 12, color: Colors.grey))),
        ]),

        if (_selected != null)"""

members_new_2 = """          if (!_loading) Center(child: Text('${filtered.length} of ${_members.length} members shown', style: const TextStyle(fontSize: 12, color: Colors.grey))),
        ])),

        if (_selected != null)"""

members_content = members_content.replace(members_old_2, members_new_2)

with open('lib/pages/admin_members_page.dart', 'w') as f:
    f.write(members_content)

