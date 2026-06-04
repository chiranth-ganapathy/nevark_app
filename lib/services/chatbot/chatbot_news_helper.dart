import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Reads cached news (same keys as [NewsService]) for chatbot sentiment.
class ChatbotNewsHelper {
  static const _cacheKey = 'news_cache_v5';

  static Future<List<_CachedArticle>> loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return [];

      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => _CachedArticle.fromJson(e as Map<String, dynamic>))
          .where((a) => a.title.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<String?> sentimentBlurbForSymbol(String symbol) async {
    final articles = await loadCached();
    if (articles.isEmpty) return null;

    final sym = symbol.toUpperCase();
    final matches = articles.where((a) {
      final t = '${a.title} ${a.description}'.toUpperCase();
      return t.contains(sym) ||
          a.relatedStocks.any((s) => s.toUpperCase().contains(sym));
    }).toList();

    if (matches.isEmpty) return null;

    var pos = 0, neg = 0;
    for (final m in matches.take(8)) {
      switch (m.sentiment) {
        case 0:
          pos++;
          break;
        case 2:
          neg++;
          break;
        default:
          break;
      }
    }

    final tone = pos > neg
        ? 'Mostly positive news tone'
        : neg > pos
            ? 'Mostly negative news tone'
            : 'Mixed/neutral news tone';

    final headline = matches.first.title;
    final short = headline.length > 72 ? '${headline.substring(0, 72)}…' : headline;
    return '$tone (${matches.length} recent articles).\nLatest: "$short"';
  }

  static Future<String?> sectorNewsBlurb(String sector) async {
    final articles = await loadCached();
    if (articles.isEmpty) return null;

    final sec = sector.toLowerCase();
    final matches = articles
        .where((a) => a.sector.toLowerCase() == sec)
        .toList();
    if (matches.isEmpty) return null;

    return '${matches.length} cached $sector headlines — latest: "${matches.first.title}"';
  }
}

class _CachedArticle {
  final String title;
  final String description;
  final String sector;
  final List<String> relatedStocks;
  final int sentiment;

  _CachedArticle({
    required this.title,
    required this.description,
    required this.sector,
    required this.relatedStocks,
    required this.sentiment,
  });

  factory _CachedArticle.fromJson(Map<String, dynamic> json) => _CachedArticle(
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        sector: json['sector'] as String? ?? 'General',
        relatedStocks: (json['relatedStocks'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        sentiment: json['sentiment'] as int? ?? 1,
      );
}
