// lib/features/news/models/news_item.dart

enum Sentiment { positive, neutral, negative }

class NewsItem {
  final String title;
  final String description;
  final String source;
  final String url;
  final String imageUrl;
  final DateTime publishedAt;
  final Sentiment sentiment;
  final int sentimentScore; // -100 to +100
  final String sector;
  final List<String> relatedStocks;

  const NewsItem({
    required this.title,
    required this.description,
    required this.source,
    required this.url,
    required this.imageUrl,
    required this.publishedAt,
    required this.sentiment,
    required this.sentimentScore,
    required this.sector,
    required this.relatedStocks,
  });

  String get sentimentLabel {
    switch (sentiment) {
      case Sentiment.positive:
        return 'Positive';
      case Sentiment.negative:
        return 'Negative';
      case Sentiment.neutral:
        return 'Neutral';
    }
  }

  String get timeAgo {
    final diff = DateTime.now().difference(publishedAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  /// Build a NewsItem from a single Marketaux article JSON object.
  factory NewsItem.fromMarketaux(
    Map<String, dynamic> json, {
    required Sentiment sentiment,
    required int sentimentScore,
    required String sector,
    required List<String> relatedStocks,
  }) {
    final title = _firstNonEmpty([
      json['title']?.toString(),
      json['headline']?.toString(),
    ]);
    final description = _firstNonEmpty([
      json['description']?.toString(),
      json['snippet']?.toString(),
      json['summary']?.toString(),
    ]);
    final imageUrl = _firstNonEmpty([
      json['image_url']?.toString(),
      json['image']?.toString(),
      json['thumbnail']?.toString(),
    ]);

    final entitySymbols = _symbolsFromEntities(json['entities']);
    final stocks = relatedStocks.isNotEmpty ? relatedStocks : entitySymbols;

    return NewsItem(
      title: title,
      description: description,
      source: _parseSource(json['source']),
      url: json['url']?.toString() ?? '',
      imageUrl: imageUrl,
      publishedAt: _parseDate(json['published_at']?.toString()),
      sentiment: sentiment,
      sentimentScore: sentimentScore,
      sector: sector,
      relatedStocks: stocks,
    );
  }

  static String _firstNonEmpty(List<String?> values) {
    for (final v in values) {
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }

  static List<String> _symbolsFromEntities(dynamic raw) {
    if (raw is! List) return [];
    final out = <String>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final sym = e['symbol']?.toString() ?? '';
      if (sym.isEmpty) continue;
      final clean = sym.replaceAll(RegExp(r'^\^'), '').toUpperCase();
      if (clean.isNotEmpty && !out.contains(clean)) out.add(clean);
    }
    return out;
  }

  /// Marketaux returns `source` as either a string or `{ "name": "..." }`.
  static String _parseSource(dynamic raw) {
    if (raw == null) return 'Market News';
    if (raw is String && raw.isNotEmpty) return raw;
    if (raw is Map) {
      final name = raw['name']?.toString();
      if (name != null && name.isNotEmpty) return name;
    }
    return 'Market News';
  }

  static DateTime _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return DateTime.now();
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return DateTime.now();
    }
  }

  NewsItem withSentiment(Sentiment s, int score) => NewsItem(
        title: title,
        description: description,
        source: source,
        url: url,
        imageUrl: imageUrl,
        publishedAt: publishedAt,
        sentiment: s,
        sentimentScore: score,
        sector: sector,
        relatedStocks: relatedStocks,
      );

  NewsItem withSectorAndStocks(String sec, List<String> stocks) => NewsItem(
        title: title,
        description: description,
        source: source,
        url: url,
        imageUrl: imageUrl,
        publishedAt: publishedAt,
        sentiment: sentiment,
        sentimentScore: sentimentScore,
        sector: sec.isNotEmpty ? sec : sector,
        relatedStocks: stocks.isNotEmpty ? stocks : relatedStocks,
      );
}
