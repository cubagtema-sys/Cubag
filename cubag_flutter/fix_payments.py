import re

with open('lib/pages/payments_page.dart', 'r') as f:
    content = f.read()

# Fix 1: line 202
old_snack = "backgroundColor: primary,"
new_snack = "backgroundColor: Theme.of(context).primaryColor,"
content = content.replace(old_snack, new_snack)

# Fix 2: line 573
old_col = "const Column(children: ["
new_col = "Column(children: ["
content = content.replace(old_col, new_col)

with open('lib/pages/payments_page.dart', 'w') as f:
    f.write(content)

