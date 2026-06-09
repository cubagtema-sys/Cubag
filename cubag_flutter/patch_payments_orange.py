import re

with open('lib/pages/payments_page.dart', 'r') as f:
    content = f.read()

# Replace pulsing icon gradient
old_pulse = "gradient: LinearGradient(colors: [Colors.orange.shade400, Colors.orange.shade700]),"
new_pulse = "gradient: LinearGradient(colors: [primary.withValues(alpha: 0.6), primary]),"
content = content.replace(old_pulse, new_pulse)

# Replace info box
old_box1 = "color: Colors.orange.shade50,"
new_box1 = "color: primary.withValues(alpha: 0.05),"
content = content.replace(old_box1, new_box1)

old_box2 = "border: Border.all(color: Colors.orange.shade200),"
new_box2 = "border: Border.all(color: primary.withValues(alpha: 0.2)),"
content = content.replace(old_box2, new_box2)

old_box_icon = "Icon(Icons.info, color: Colors.orange, size: 14),"
new_box_icon = "Icon(Icons.info, color: primary, size: 14),"
content = content.replace(old_box_icon, new_box_icon)

old_box_text = "Text('MTN MoMo Approval Notice', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),"
new_box_text = "Text('MTN MoMo Approval Notice', style: TextStyle(color: primary, fontSize: 11, fontWeight: FontWeight.bold)),"
content = content.replace(old_box_text, new_box_text)

# Replace progress bar
old_prog1 = "backgroundColor: Colors.orange.shade100,"
new_prog1 = "backgroundColor: primary.withValues(alpha: 0.1),"
content = content.replace(old_prog1, new_prog1)

old_prog2 = "valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade600),"
new_prog2 = "valueColor: AlwaysStoppedAnimation<Color>(primary),"
content = content.replace(old_prog2, new_prog2)

# Also fix the floating snackbar if it's orange
old_snack = "backgroundColor: Colors.orange.shade800,"
new_snack = "backgroundColor: primary,"
content = content.replace(old_snack, new_snack)

with open('lib/pages/payments_page.dart', 'w') as f:
    f.write(content)

