import re

with open('lib/pages/admin_members_page.dart', 'r') as f:
    content = f.read()

# We'll pull out the InkWell logic into a helper function so we can use it in both Grid and List
builder_old = """              itemBuilder: (ctx, i) {
                final m = filtered[i];
                final ss = _statusStyle[m['status']] ?? _statusStyle['inactive']!;
                final c  = _typeColors[m['member_type']] ?? primary;
                final starRating = double.tryParse(m['star_rating']?.toString() ?? '') ?? 5.0;
                final score = int.tryParse(m['compliance_score']?.toString() ?? '') ?? 100;
                final tier = StandingTier.getFromStars(starRating);

                return InkWell(
                  onTap: () => _selectMember(m),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Theme.of(ctx).cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(ctx).dividerColor)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start, 
                      children: [
                        Row(children: [
                          CircleAvatar(radius: 18, backgroundColor: c.withValues(alpha: 0.1), child: Text(_initials(m['name']?.toString() ?? ''), style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12))),
                          const Spacer(),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: ss['bg'] as Color, borderRadius: BorderRadius.circular(20)), child: Text((ss['label'] as String).toUpperCase(), style: TextStyle(fontSize: 8, color: ss['color'] as Color, fontWeight: FontWeight.bold))),
                        ]),
                        const SizedBox(height: 8),
                        Text(m['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                        Text(m['email']?.toString() ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Color(0xFFFFD700), size: 14),
                            const SizedBox(width: 4),
                            Text(
                              starRating.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '($score%)',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                tier.label,
                                style: TextStyle(fontSize: 10, color: tier.color, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(child: OutlinedButton(onPressed: () => _selectMember(m), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 4), minimumSize: const Size(0, 36), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Details', style: TextStyle(fontSize: 11)))),
                          if (m['status'] == 'pending') ...[const SizedBox(width: 6), Expanded(child: ElevatedButton(onPressed: _updating ? null : () => _updateStatus(m['id'], 'active'), style: ElevatedButton.styleFrom(backgroundColor: primary, padding: const EdgeInsets.symmetric(vertical: 4), minimumSize: const Size(0, 36), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), child: const Text('Approve', style: TextStyle(color: Colors.white, fontSize: 11))))],
                          if (m['status'] == 'active') ...[const SizedBox(width: 6), Expanded(child: ElevatedButton(onPressed: _updating ? null : () => _updateStatus(m['id'], 'suspended'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 4), minimumSize: const Size(0, 36), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), child: const Text('Suspend', style: TextStyle(color: Colors.white, fontSize: 11))))],
                        ]),
                      ],
                    ),
                  ),
                );
              },"""

builder_new = """              itemBuilder: (ctx, i) {
                return _buildMemberCard(filtered[i], primary, ctx);
              },"""
content = content.replace(builder_old, builder_new)


# Now wrap ListView.separated in a LayoutBuilder
list_old = """            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                return _buildMemberCard(filtered[i], primary, ctx);
              },
            ),"""
list_new = """            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 800) {
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 400,
                      childAspectRatio: 1.8,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemBuilder: (ctx, i) => _buildMemberCard(filtered[i], primary, ctx),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    return _buildMemberCard(filtered[i], primary, ctx);
                  },
                );
              }
            ),"""
content = content.replace(list_old, list_new)


# Now add the _buildMemberCard method to the class
card_method = """  Widget _buildMemberCard(dynamic m, Color primary, BuildContext ctx) {
    final ss = _statusStyle[m['status']] ?? _statusStyle['inactive']!;
    final c  = _typeColors[m['member_type']] ?? primary;
    final starRating = double.tryParse(m['star_rating']?.toString() ?? '') ?? 5.0;
    final score = int.tryParse(m['compliance_score']?.toString() ?? '') ?? 100;
    final tier = StandingTier.getFromStars(starRating);

    return InkWell(
      onTap: () => _selectMember(m),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Theme.of(ctx).cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(ctx).dividerColor)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Row(children: [
              CircleAvatar(radius: 18, backgroundColor: c.withValues(alpha: 0.1), child: Text(_initials(m['name']?.toString() ?? ''), style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12))),
              const Spacer(),
              Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: ss['bg'] as Color, borderRadius: BorderRadius.circular(20)), child: Text((ss['label'] as String).toUpperCase(), style: TextStyle(fontSize: 8, color: ss['color'] as Color, fontWeight: FontWeight.bold))),
            ]),
            const SizedBox(height: 8),
            Text(m['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
            Text(m['email']?.toString() ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.star, color: Color(0xFFFFD700), size: 14),
                const SizedBox(width: 4),
                Text(
                  starRating.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 6),
                Text(
                  '($score%)',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tier.label,
                    style: TextStyle(fontSize: 10, color: tier.color, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => _selectMember(m), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 4), minimumSize: const Size(0, 36), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Details', style: TextStyle(fontSize: 11)))),
              if (m['status'] == 'pending') ...[const SizedBox(width: 6), Expanded(child: ElevatedButton(onPressed: _updating ? null : () => _updateStatus(m['id'], 'active'), style: ElevatedButton.styleFrom(backgroundColor: primary, padding: const EdgeInsets.symmetric(vertical: 4), minimumSize: const Size(0, 36), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), child: const Text('Approve', style: TextStyle(color: Colors.white, fontSize: 11))))],
              if (m['status'] == 'active') ...[const SizedBox(width: 6), Expanded(child: ElevatedButton(onPressed: _updating ? null : () => _updateStatus(m['id'], 'suspended'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 4), minimumSize: const Size(0, 36), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), child: const Text('Suspend', style: TextStyle(color: Colors.white, fontSize: 11))))],
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildMathBreakdownSection(Map<String, dynamic> m, Color primary) {"""

content = content.replace("  Widget _buildMathBreakdownSection(Map<String, dynamic> m, Color primary) {", card_method)

with open('lib/pages/admin_members_page.dart', 'w') as f:
    f.write(content)

