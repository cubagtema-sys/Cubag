import re

with open('lib/pages/networking_page.dart', 'r') as f:
    content = f.read()

# Replace onPressed handler
old_btn = """                        onPressed: () => setState(() => _selected = Map<String, dynamic>.from(m)),"""
new_btn = """                        onPressed: () {
                          setState(() => _selected = Map<String, dynamic>.from(m));
                          _showMemberDetails(context, m, primary);
                        },"""
content = content.replace(old_btn, new_btn)

# Remove the Positioned.fill bottom sheet logic from build()
# It starts at:
#         // Member Detail Bottom Sheet
#         if (_selected != null)
# and ends at the end of the Stack

sheet_code_old = """        // Member Detail Bottom Sheet
        if (_selected != null)
          Positioned.fill(child: GestureDetector(
            onTap: () => setState(() => _selected = null),
            child: Container(
              color: Colors.black.withValues(alpha: 0.6),
              alignment: Alignment.bottomCenter,
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
                  decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                    Expanded(child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: _buildDetailSheet(primary),
                    )),
                  ]),
                ),
              ),
            ),
          )),
      ]),
    );
  }

  Widget _buildDetailSheet(Color primary) {"""

sheet_code_new = """      ]),
    );
  }

  void _showMemberDetails(BuildContext context, Map<String, dynamic> m, Color primary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4, margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildDetailSheet(primary),
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _selected = null);
    });
  }

  Widget _buildDetailSheet(Color primary) {"""

content = content.replace(sheet_code_old, sheet_code_new)

with open('lib/pages/networking_page.dart', 'w') as f:
    f.write(content)

