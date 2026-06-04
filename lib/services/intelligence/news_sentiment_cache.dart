import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/news/models/news_item.dart';

/// In-memory view of cached news for prediction + sentiment intelligence.
class NewsSentimentCache {
  static const _cacheKey = 'news_cache_v5';
  static List<_NewsRow>? _rows;
  static DateTime? _loadedAt;

  static Future<void> preload() async {
    if (_rows != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) {
        _rows = [];
        return;
      }
      final list = jsonDecode(raw) as List<dynamic>;
      _rows = list
          .map((e) => _NewsRow.fromJson(e as Map<String, dynamic>))
          .where((r) => r.title.isNotEmpty)
          .toList();
      _loadedAt = DateTime.now();
    } catch (_) {
      _rows = [];
    }
  }

  static List<_NewsRow> get rows => _rows ?? [];

  static SentimentSnapshot forSymbol(String symbol) {
    final sym = symbol.toUpperCase();
    final matches = rows.where((r) {
      final blob = '${r.title} ${r.description}'.toUpperCase();
      return blob.contains(sym) ||
          r.relatedStocks.any((s) => s.toUpperCase() == sym);
    }).toList();
    return _aggregate(matches, label: sym);
  }

  static SentimentSnapshot forSector(String sector) {
    final matches = rows
        .where((r) => r.sector.toLowerCase() == sector.toLowerCase())
        .toList();
    return _aggregate(matches, label: sector);
  }

  static SentimentSnapshot forMarket() {
    if (rows.isEmpty) return SentimentSnapshot.neutral('No cached headlines');
    return _aggregate(rows.take(40).toList(), label: 'Market');
  }

  static SentimentSnapshot _aggregate(List<_NewsRow> articles, {required String label}) {
    if (articles.isEmpty) {
      return SentimentSnapshot.neutral('No recent news for $label');
    }

    var scoreSum = 0;
    var pos = 0, neg = 0, neu = 0;
    for (final a in articles) {
      scoreSum += a.sentimentScore;
      switch (a.sentiment) {
        case Sentiment.positive:
          pos++;
          break;
        case Sentiment.negative:
          neg++;
          break;
        case Sentiment.neutral:
          neu++;
          break;
      }
    }

    final avg = (scoreSum / articles.length).round().clamp(-100, 100);
    final labelStr = avg >= 15
        ? 'Positive'
        : avg <= -15
            ? 'Negative'
            : 'Neutral';

    return SentimentSnapshot(
      label: labelStr,
      impactScore: avg,
      articleCount: articles.length,
      summary: '$labelStr news tone ($pos↑ $neu→ $neg↓ from ${articles.length} headlines)',
    );
  }
}

class SentimentSnapshot {
  final String label;
  final int impactScore;
  final int articleCount;
  final String summary;

  const SentimentSnapshot({
    required this.label,
    required this.impactScore,
    required this.articleCount,
    required this.summary,
  });

  factory SentimentSnapshot.neutral(String summary) => SentimentSnapshot(
        label: 'Neutral',
        impactScore: 0,
        articleCount: 0,
        summary: summary,
      );

  double get normalized => (impactScore / 100).clamp(-1.0, 1.0);
}

class _NewsRow {
  final String title;
  final String description;
  final String sector;
  final List<String> relatedStocks;
  final Sentiment sentiment;
  final int sentimentScore;

  _NewsRow({
    required this.title,
    required this.description,
    required this.sector,
    required this.relatedStocks,
    required this.sentiment,
    required this.sentimentScore,
  });

  factory _NewsRow.fromJson(Map<String, dynamic> json) {
    final sentIdx = json['sentiment'];
    int idx = 1;
    if (sentIdx is int) idx = sentIdx.clamp(0, 2);

    return _NewsRow(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      sector: json['sector'] as String? ?? 'General',
      relatedStocks: (json['relatedStocks'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      sentiment: Sentiment.values[idx],
      sentimentScore: json['sentimentScore'] as int? ?? 0,
    );
  }
}
