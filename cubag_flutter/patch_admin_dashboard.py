import re

with open('lib/pages/admin_dashboard_page.dart', 'r') as f:
    admin_dash_content = f.read()

old_str = "      title: 'Admin Dashboard',\n      hideSearch: false,\n      scrollable: true,"
new_str = "      title: 'Admin Dashboard',\n      hideSearch: false,\n      scrollable: false,"

admin_dash_content = admin_dash_content.replace(old_str, new_str)

with open('lib/pages/admin_dashboard_page.dart', 'w') as f:
    f.write(admin_dash_content)

