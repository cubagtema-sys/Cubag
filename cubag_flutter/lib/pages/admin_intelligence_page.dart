import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import '../components/app_layout.dart';
import '../components/skeleton_loader.dart';
import '../services/api_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

const _kOrange = Color(0xFFf08232);

// Mirror the exact same 6 feed sources from React
const _feedSources = [
  {'url': 'https://gcaptain.com/feed/',                 'source': 'gCaptain',            'color': 0xFFf08232},
  {'url': 'https://www.hellenicshippingnews.com/feed/', 'source': 'Hellenic Shipping',   'color': 0xFF1a6b3c},
  {'url': 'https://splash247.com/feed/',                'source': 'Splash247',           'color': 0xFF0066cc},
  {'url': 'https://www.ship-technology.com/feed/',      'source': 'Ship Technology',     'color': 0xFFc0392b},
  {'url': 'https://www.freightwaves.com/news/feed',     'source': 'FreightWaves',        'color': 0xFF003580},
];


class AdminIntelligencePage extends StatefulWidget {
  const AdminIntelligencePage({super.key});
  @override State<AdminIntelligencePage> createState() => _State();
}

class _Article {
  final String title, link, pubDate, source, thumbnail;
  final Color sourceColor;

  const _Article({
    required this.title,
    required this.link,
    required this.pubDate,
    required this.source,
    required this.thumbnail,
    required this.sourceColor,
  });
}

class _State extends State<AdminIntelligencePage> {
  final _api = ApiService();
  bool _loading = true;
  List<_Article> _articles = [];
  String _lastUpdated = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool isRetry = false}) async {
    setState(() { _loading = true; _articles = []; });

    try {
      final res = await _api.getPublic('news/global');
      if (res is List) {
        final List<_Article> parsed = [];
        for (final item in res) {
          if (item is Map) {
            final title = item['title']?.toString() ?? '';
            final link = item['link']?.toString() ?? '';
            final pubDate = item['pubDate']?.toString() ?? '';
            final source = item['source']?.toString() ?? '';
            final thumbnail = item['thumbnail']?.toString() ?? '';
            final colorHexStr = item['sourceColor']?.toString() ?? '#3b82f6';
            
            // Parse color
            Color color;
            try {
              final cleanHex = colorHexStr.replaceAll('#', '');
              color = Color(int.parse('FF$cleanHex', radix: 16));
            } catch (_) {
              color = const Color(0xFF3b82f6);
            }

            parsed.add(_Article(
              title: title,
              link: link,
              pubDate: pubDate,
              source: source,
              thumbnail: thumbnail,
              sourceColor: color,
            ));
          }
        }
        if (mounted) {
          setState(() {
            _articles = parsed;
            _loading = false;
            _lastUpdated = TimeOfDay.now().format(context);
          });

          // Auto-retry once if result was only mock/empty data (server cache warming up)
          if (!isRetry && parsed.length <= 2) {
            await Future.delayed(const Duration(seconds: 4));
            if (mounted) _load(isRetry: true);
          }
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() { _loading = false; });
      // Auto-retry once after brief delay if network failed
      if (!isRetry) {
        await Future.delayed(const Duration(seconds: 4));
        if (mounted) _load(isRetry: true);
      }
    }
  }

  String _formatDate(String pubDate) {
    try {
      final dt = HttpDate.parse(pubDate);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final monthStr = months[(dt.month - 1).clamp(0, 11)];
      return '$monthStr ${dt.day}, ${dt.year}';
    } catch (_) {
      return pubDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1e293b) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFe2e8f0);
    final textColor = isDark ? const Color(0xFFf8fafc) : const Color(0xFF0f172a);
    final subTextColor = isDark ? const Color(0xFF94a3b8) : const Color(0xFF475569);

    return AppLayout(
      title: 'Intelligence Hub',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Status Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0f172a).withValues(alpha: 0.4) : const Color(0xFFf0fdf4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF10b981).withValues(alpha: isDark ? 0.3 : 0.4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.anchor_rounded, color: Color(0xFF10b981), size: 22),
                const SizedBox(width: 10),
                Text(
                  'Maritime Intelligence Active',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: const Color(0xFF10b981),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Text(
                'The Intelligence Hub is directly connected to 5 maritime and customs news networks — '
                'gCaptain, Hellenic Shipping News, Splash247, Ship Technology, and FreightWaves. '
                'Live data is pulled 24/7 for all CUBAG members.',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF94a3b8) : const Color(0xFF1e293b).withValues(alpha: 0.8),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: _feedSources.map((s) {
                final color = Color(s['color'] as int);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        (s['source'] as String).toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: color,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList()),
            ]),
          ),
          const SizedBox(height: 24),

          // Feed header
          Row(children: [
            const Icon(Icons.directions_boat_filled_rounded, color: _kOrange, size: 20),
            const SizedBox(width: 8),
            Text(
              'Live Maritime Feed',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: textColor,
              ),
            ),
            if (_lastUpdated.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                '• updated $_lastUpdated',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: subTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const Spacer(),
            if (!_loading)
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1e293b) : Colors.grey.shade100,
                  border: Border.all(color: borderColor),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  tooltip: 'Refresh feeds',
                  icon: Icon(Icons.refresh, size: 16, color: isDark ? Colors.white70 : Colors.black87),
                  onPressed: _load,
                ),
              ),
          ]),
          const SizedBox(height: 16),

          // Feed content
          if (_loading)
            Column(
              children: List.generate(4, (index) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonLoader(width: 90, height: 90, borderRadius: 12),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              SkeletonLoader(width: 80, height: 18, borderRadius: 6),
                              const SizedBox(width: 8),
                              SkeletonLoader(width: 60, height: 12),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SkeletonLoader(height: 16),
                          const SizedBox(height: 6),
                          SkeletonLoader(width: 180, height: 16),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              SkeletonLoader(width: 100, height: 14, borderRadius: 4),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
            )
          else if (_articles.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFf1f5f9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.wifi_off_rounded, color: subTextColor, size: 28),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Feed temporarily unavailable.',
                      style: GoogleFonts.outfit(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'The server may still be warming up.',
                      style: GoogleFonts.outfit(
                        color: subTextColor,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: Text(
                        'Try Again',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: _articles.map((a) => _buildArticleCard(a, isDark, cardBg, borderColor, textColor, subTextColor)).toList(),
            ),
        ]),
      ),
    );
  }

  Widget _buildArticleCard(_Article a, bool isDark, Color cardBg, Color borderColor, Color textColor, Color subTextColor) {
    return InkWell(
      onTap: () async {
        if (a.link.isNotEmpty) {
          final uri = Uri.parse(a.link);
          if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Premium Image Container
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: a.thumbnail.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: '${ApiService.baseUrl}/news/proxy-image?url=${Uri.encodeComponent(a.thumbnail)}',
                    width: 90, 
                    height: 90,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF1e293b), const Color(0xFF334155)]
                              : [Colors.grey.shade100, Colors.grey.shade200],
                        ),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: _kOrange),
                        ),
                      ),
                    ),
                    errorWidget: (context, error, stack) => Container(
                      width: 90,
                      height: 90,
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFf1f5f9),
                      child: Icon(Icons.image_not_supported_outlined, color: subTextColor.withValues(alpha: 0.6), size: 22),
                    ),
                  )
                : Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF1e293b), const Color(0xFF334155)]
                            : [Colors.grey.shade50, Colors.grey.shade100],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.article_outlined,
                        color: a.sourceColor.withValues(alpha: 0.6),
                        size: 28,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          
          // Content
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Source badge + date
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: a.sourceColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: a.sourceColor.withValues(alpha: 0.2)),
                ),
                child: Text(
                  a.source.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: a.sourceColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (a.pubDate.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatDate(a.pubDate),
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: subTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 8),
            Text(
              a.title,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: textColor,
                height: 1.35,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Read full article',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: _kOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_outward_rounded,
                  size: 14,
                  color: _kOrange,
                ),
              ],
            ),
          ])),
        ]),
      ),
    );
  }
}

// Simple HTTP date fallback
class HttpDate {
  static DateTime parse(String httpDate) {
    // RFC 2822: Mon, 02 Jun 2025 10:30:00 GMT
    // Strip day-of-week prefix and timezone suffix, then inject T between date and time
    try {
      final clean = httpDate
          .replaceFirst(RegExp(r'^[A-Za-z]+, '), '')
          .replaceFirst(RegExp(r' \+?\d{4}$'), '')
          .replaceFirst(RegExp(r' [A-Z]{2,4}$'), '')
          .trim();
      // e.g. "02 Jun 2025 10:30:00" -> split into date+time parts
      final parts = clean.split(' ');
      if (parts.length >= 4) {
        final months = {'Jan':1,'Feb':2,'Mar':3,'Apr':4,'May':5,'Jun':6,'Jul':7,'Aug':8,'Sep':9,'Oct':10,'Nov':11,'Dec':12};
        final day = int.parse(parts[0]);
        final month = months[parts[1]] ?? 1;
        final year = int.parse(parts[2]);
        final timeParts = parts[3].split(':');
        final hour = int.parse(timeParts[0]);
        final minute = timeParts.length > 1 ? int.parse(timeParts[1]) : 0;
        final second = timeParts.length > 2 ? int.parse(timeParts[2]) : 0;
        return DateTime.utc(year, month, day, hour, minute, second);
      }
    } catch (_) {}
    throw FormatException('Could not parse: $httpDate');
  }
}
