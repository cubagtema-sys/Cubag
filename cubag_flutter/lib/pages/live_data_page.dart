import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../components/app_layout.dart';
import '../services/api_service.dart';

class LiveDataPage extends StatefulWidget {
  const LiveDataPage({super.key});
  @override
  State<LiveDataPage> createState() => _LiveDataPageState();
}

class _LiveDataPageState extends State<LiveDataPage> {
  final _api = ApiService();
  Map<String, String> _forex = {'USD': '...', 'EUR': '...', 'GBP': '...', 'CNY': '...'};
  bool _forexLoading = true;
  bool _newsLoading = true;
  List<Map<String, String>> _news = [];
  String _lastUpdated = '';
  int _newsPage = 1;
  static const int _newsPerPage = 10;

  String _formatTime() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  @override
  void initState() {
    super.initState();
    _lastUpdated = _formatTime();
    _loadForex();
    _loadNews();
  }

  Future<void> _loadForex() async {
    setState(() => _forexLoading = true);
    try {
      final res = await http.get(Uri.parse('https://open.er-api.com/v6/latest/GHS'));
      if (res.statusCode == 200) {
        // Simple JSON parse without dart:convert overhead
        final body = res.body;
        String extractRate(String currency) {
          final pattern = '"$currency":';
          final idx = body.indexOf(pattern);
          if (idx == -1) return '...';
          final start = idx + pattern.length;
          final end = body.indexOf(',', start);
          final rateStr = body.substring(start, end).trim();
          final rate = double.tryParse(rateStr);
          return rate != null ? (1 / rate).toStringAsFixed(2) : '...';
        }
        setState(() => _forex = {'USD': extractRate('USD'), 'EUR': extractRate('EUR'), 'GBP': extractRate('GBP'), 'CNY': extractRate('CNY')});
      }
    } catch (_) {}
    setState(() => _forexLoading = false);
  }

  Future<void> _loadNews() async {
    setState(() { _newsLoading = true; });
    try {
      final res = await _api.getPublic('news/global');
      if (res is List) {
        final List<Map<String, String>> parsed = [];
        for (final item in res) {
          if (item is Map) {
            parsed.add({
              'title': item['title']?.toString() ?? '',
              'source': item['source']?.toString() ?? '',
              'date': item['pubDate']?.toString() ?? '',
              'description': item['description']?.toString() ?? '',
              'thumbnail': item['thumbnail']?.toString() ?? '',
              'sourceColor': item['sourceColor']?.toString() ?? '#3b82f6',
            });
          }
        }
        if (mounted) {
          setState(() {
            _news = parsed;
            _newsLoading = false;
            _lastUpdated = _formatTime();
          });
          return;
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _news = [];
        _newsLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final totalPages = (_news.length / _newsPerPage).ceil().clamp(1, 999);
    final pageItems = _news.skip((_newsPage - 1) * _newsPerPage).take(_newsPerPage).toList();

    return AppLayout(
      title: 'Intelligence Hub',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Live indicator
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10b981), shape: BoxShape.circle)),
          const SizedBox(width: 6),
          const Text('LIVE', style: TextStyle(fontSize: 11, color: Color(0xFF10b981), fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Text(_lastUpdated, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
        const SizedBox(height: 12),

        // Forex Card
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(Icons.currency_exchange, color: primary, size: 20), const SizedBox(width: 8), const Text('Live Forex Rates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))]),
              const SizedBox(height: 14),
              Row(children: _forex.entries.map((e) => Expanded(child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: Theme.of(context).dividerColor)),
                child: Column(children: [
                  Text('${e.key}/GHS', style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(_forexLoading ? '...' : e.value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'monospace')),
                ]),
              ))).toList()),
            ]),
          ),
        ),
        const SizedBox(height: 20),

        // News section
        Row(children: [
          Icon(Icons.directions_boat, color: const Color(0xFF3b82f6), size: 22),
          const SizedBox(width: 8),
          const Text('Maritime & Customs Intelligence', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          if (!_newsLoading) Text('${_news.length} articles', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
        const SizedBox(height: 4),
        const Text('gCaptain · Hellenic Shipping · Splash247 · FreightWaves · CUBAG Updates', style: TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 12),

        if (_newsLoading)
          const Center(child: Padding(padding: EdgeInsets.all(40), child: Column(children: [CircularProgressIndicator(), SizedBox(height: 12), Text('Syncing maritime news feeds...', style: TextStyle(color: Colors.grey))])))
        else
          Column(children: [
            ...pageItems.map((news) {
              Color? srcColor;
              final hexStr = news['sourceColor'];
              if (hexStr != null) {
                try {
                  final cleanHex = hexStr.replaceAll('#', '');
                  srcColor = Color(int.parse('FF$cleanHex', radix: 16));
                } catch (_) {}
              }
              final displayColor = srcColor ?? primary;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: displayColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)), child: Text(news['source'] ?? '', style: TextStyle(fontSize: 10, color: displayColor, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 8),
                    Text(news['date'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ]),
                  const SizedBox(height: 8),
                  Text(news['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, height: 1.3)),
                  const SizedBox(height: 6),
                  Text(news['description'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                ]),
              );
            }),

            if (totalPages > 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  IconButton(icon: const Icon(Icons.arrow_back), onPressed: _newsPage > 1 ? () => setState(() { _newsPage--; }) : null),
                  ...List.generate(totalPages, (i) => i + 1).map((n) => GestureDetector(
                    onTap: () => setState(() => _newsPage = n),
                    child: Container(margin: const EdgeInsets.symmetric(horizontal: 4), width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: _newsPage == n ? primary : Theme.of(context).cardColor, borderRadius: BorderRadius.circular(8)), child: Text('$n', style: TextStyle(color: _newsPage == n ? Colors.white : null, fontWeight: FontWeight.bold))),
                  )),
                  IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _newsPage < totalPages ? () => setState(() => _newsPage++) : null),
                ]),
              ),
          ]),
      ]),
    );
  }
}
