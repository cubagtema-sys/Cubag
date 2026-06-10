import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/app_layout.dart';
import '../services/api_service.dart';

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
    return pubDate;
  }

  @override
  Widget build(BuildContext context) => AppLayout(
    title: 'Intelligence Hub',
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 820),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Status Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF10b981).withAlpha(60)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.anchor, color: Color(0xFF10b981), size: 20),
              const SizedBox(width: 8),
              const Text('Maritime Intelligence Active', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF10b981))),
            ]),
            const SizedBox(height: 8),
            const Text(
              'The Intelligence Hub is directly connected to 6 maritime and customs news networks — '
              'gCaptain, Hellenic Shipping News, Splash247, Ship Technology, and FreightWaves. '
              'Live data is pulled 24/7 for all CUBAG members.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748b), height: 1.5),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: _feedSources.map((s) {
              final color = Color(s['color'] as int);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withAlpha(24),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withAlpha(48)),
                ),
                child: Text(
                  (s['source'] as String).toUpperCase(),
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.6),
                ),
              );
            }).toList()),
          ]),
        ),
        const SizedBox(height: 16),

        // Feed header
        Row(children: [
          const Icon(Icons.directions_boat, color: Color(0xFF3b82f6), size: 18),
          const SizedBox(width: 6),
          const Text('Live Maritime Feed', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          if (_lastUpdated.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text('• updated $_lastUpdated', style: const TextStyle(fontSize: 11, color: Color(0xFF94a3b8), fontWeight: FontWeight.w600)),
          ],
          const Spacer(),
          if (!_loading) IconButton(
            tooltip: 'Refresh feeds',
            icon: const Icon(Icons.refresh, size: 18, color: Color(0xFF64748b)),
            onPressed: _load,
          ),
        ]),
        const SizedBox(height: 10),

        // Feed content
        if (_loading)
          Container(
            padding: const EdgeInsets.all(48),
            alignment: Alignment.center,
            child: Column(children: [
              const CircularProgressIndicator(color: _kOrange),
              const SizedBox(height: 14),
              const Text('Syncing maritime intelligence feeds...', style: TextStyle(color: Color(0xFF94a3b8), fontSize: 13)),
            ]),
          )
        else if (_articles.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded, color: Colors.grey, size: 32),
                  const SizedBox(height: 10),
                  const Text('Feed temporarily unavailable.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text('The server may still be warming up.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          )
        else
          Column(children: _articles.map((a) => _buildArticleCard(a)).toList()),
      ]),
    ),
  );

  Widget _buildArticleCard(_Article a) {
    return InkWell(
      onTap: () async {
        if (a.link.isNotEmpty) {
          final uri = Uri.parse(a.link);
          if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Thumbnail if available
          if (a.thumbnail.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                '${ApiService.baseUrl}/news/proxy-image?url=${Uri.encodeComponent(a.thumbnail)}',
                width: 64, height: 64,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(width: 12),
          ],
          // Content
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Source badge + date
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: a.sourceColor.withAlpha(24),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: a.sourceColor.withAlpha(48)),
                ),
                child: Text(a.source.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: a.sourceColor, letterSpacing: 0.5)),
              ),
              if (a.pubDate.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(_formatDate(a.pubDate), style: const TextStyle(fontSize: 11, color: Color(0xFF94a3b8), fontWeight: FontWeight.w600)),
              ],
            ]),
            const SizedBox(height: 5),
            Text(a.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0f172a), height: 1.35), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            const Text('Read full article ↗', style: TextStyle(fontSize: 11, color: Color(0xFF3b82f6), fontWeight: FontWeight.w700)),
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
