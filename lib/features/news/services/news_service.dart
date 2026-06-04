// lib/features/news/services/news_service.dart
//
// Fetches news exclusively from Yahoo Finance RSS feeds.

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../../services/api_service.dart';
import '../models/news_item.dart';
import 'news_pipeline_log.dart';
import 'yahoo_news_provider.dart';

const Duration _kCacheTtl = Duration(minutes: 15);
const String _kCacheKey = 'news_cache_v6';
const String _kCacheTsKey = 'news_cache_ts_v6';

/// Legacy cache keys — cleared on upgrade so stale data cannot block the UI.
const _legacyCacheKeys = [
  'news_cache_v3',
  'news_cache_ts_v3',
  'news_cache_v4',
  'news_cache_ts_v4',
  'news_cache_v5',
  'news_cache_ts_v5',
];

class NewsServiceException implements Exception {
  final String message;
  const NewsServiceException(this.message);
  @override
  String toString() => message;
}

class NewsService {
  static final _yahoo = YahooNewsProvider();

  static Future<List<NewsItem>> fetchAll({bool forceRefresh = false}) async {
    await _purgeLegacyCaches();

    if (!forceRefresh) {
      final cached = await _loadCache();
      if (cached != null && cached.isNotEmpty) {
        NewsPipelineLog.i('Serving ${cached.length} articles from cache');
        return _prioritizeStockNews(cached);
      }
    }

    try {
      NewsPipelineLog.i('Fetching from Yahoo Finance…');
      final items = await _yahoo.fetch();
      if (items.isEmpty) {
        throw Exception('Yahoo Finance returned 0 articles after parsing');
      }
      final sorted = _prioritizeStockNews(items);
      await _saveCache(sorted);
      NewsPipelineLog.i('Yahoo Finance OK: ${sorted.length} articles saved');
      return sorted;
    } catch (e, st) {
      NewsPipelineLog.i('Yahoo Finance failed: $e\n$st');
      throw NewsServiceException(
        'Could not load news from Yahoo Finance.\n$e',
      );
    }
  }

  /// Stock-linked articles first, then newest.
  static List<NewsItem> _prioritizeStockNews(List<NewsItem> items) {
    final copy = [...items];
    copy.sort((a, b) {
      final aTracked = a.relatedStocks.any((s) => kNseTokens.containsKey(s));
      final bTracked = b.relatedStocks.any((s) => kNseTokens.containsKey(s));
      if (aTracked != bTracked) return aTracked ? -1 : 1;
      return b.publishedAt.compareTo(a.publishedAt);
    });
    return copy;
  }

  static Future<void> _purgeLegacyCaches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in _legacyCacheKeys) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }

  static Future<List<NewsItem>?> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tsMs = prefs.getInt(_kCacheTsKey);
      if (tsMs == null) return null;

      final age =
          DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(tsMs));
      if (age > _kCacheTtl) {
        NewsPipelineLog.i('Cache expired (${age.inMinutes}m old)');
        return null;
      }

      final raw = prefs.getString(_kCacheKey);
      if (raw == null || raw.isEmpty) return null;

      final list = jsonDecode(raw) as List<dynamic>;
      final items = list
          .map((e) => _newsItemFromCacheJson(e as Map<String, dynamic>))
          .where((n) => n.title.isNotEmpty)
          .toList();

      NewsPipelineLog.i('Cache read: ${list.length} raw → ${items.length} valid');
      return items.isEmpty ? null : items;
    } catch (e) {
      NewsPipelineLog.i('Cache read failed: $e');
      await clearCache();
      return null;
    }
  }

  static Future<void> _saveCache(List<NewsItem> items) async {
    if (items.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kCacheTsKey, DateTime.now().millisecondsSinceEpoch);
      await prefs.setString(
        _kCacheKey,
        jsonEncode(items.map(_newsItemToJson).toList()),
      );
      NewsPipelineLog.i('Cache saved: ${items.length} articles');
    } catch (e) {
      NewsPipelineLog.i('Cache save failed: $e');
    }
  }

  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCacheKey);
    await prefs.remove(_kCacheTsKey);
    for (final key in _legacyCacheKeys) {
      await prefs.remove(key);
    }
    NewsPipelineLog.i('Cache cleared');
  }

  static Map<String, dynamic> _newsItemToJson(NewsItem item) => {
        'title': item.title,
        'description': item.description,
        'source': item.source,
        'url': item.url,
        'imageUrl': item.imageUrl,
        'publishedAt': item.publishedAt.toIso8601String(),
        'sentiment': item.sentiment.index,
        'sentimentScore': item.sentimentScore,
        'sector': item.sector,
        'relatedStocks': item.relatedStocks,
      };

  static NewsItem _newsItemFromCacheJson(Map<String, dynamic> json) {
    final sentIndex = json['sentiment'];
    int idx = 1;
    if (sentIndex is int) {
      idx = sentIndex.clamp(0, 2);
    } else if (sentIndex is String) {
      idx = switch (sentIndex.toLowerCase()) {
        'positive' => 0,
        'negative' => 2,
        _ => 1,
      };
    }

    return NewsItem(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      source: json['source'] as String? ?? 'Yahoo Finance',
      url: json['url'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? '') ??
          DateTime.now(),
      sentiment: Sentiment.values[idx],
      sentimentScore: json['sentimentScore'] as int? ?? 0,
      sector: json['sector'] as String? ?? 'General',
      relatedStocks: (json['relatedStocks'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
