import re

with open('lib/components/app_layout.dart', 'r') as f:
    content = f.read()

# Fix scaffold background to be slate so the bottom is slate
old_bg = "backgroundColor: isDesktop ? Theme.of(context).scaffoldBackgroundColor : primary,"
new_bg = "backgroundColor: isDesktop ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFf8fafc),"
content = content.replace(old_bg, new_bg)

# Put a small primary background behind the top corners
old_body = """            ) : Container(
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
            ),"""
new_body = """            ) : Container(
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
            ),"""
content = content.replace(old_body, new_body)

with open('lib/components/app_layout.dart', 'w') as f:
    f.write(content)

