import '../models/news_item.dart';
import 'marketaux_news_provider.dart';
import 'news_service.dart';

class InstitutionalFlowRecord {
  final String participant;
  final double amountCrore;
  final bool isBuy;
  final DateTime publishedAt;
  final NewsItem source;

  const InstitutionalFlowRecord({
    required this.participant,
    required this.amountCrore,
    required this.isBuy,
    required this.publishedAt,
    required this.source,
  });

  double get signedAmount => isBuy ? amountCrore : -amountCrore;
  String get label => isBuy ? 'Net Buy' : 'Net Sell';
  String get formattedAmount =>
      'Rs ${amountCrore.toStringAsFixed(amountCrore >= 100 ? 0 : 2)} Cr';
}

class FiiDiiSnapshot {
  final InstitutionalFlowRecord? fii;
  final InstitutionalFlowRecord? dii;
  final double? dailyInstitutionalFlowCrore;
  final String trend;
  final String bias;
  final DateTime? lastUpdated;
  final List<String> insights;
  final List<NewsItem> newsItems;
  final String dataSource;

  const FiiDiiSnapshot({
    required this.fii,
    required this.dii,
    required this.dailyInstitutionalFlowCrore,
    required this.trend,
    required this.bias,
    required this.lastUpdated,
    required this.insights,
    required this.newsItems,
    required this.dataSource,
  });

  bool get hasRealData => fii != null || dii != null;

  String get fiiDisplay =>
      fii == null ? 'Unavailable' : '${fii!.label} (${fii!.formattedAmount})';

  String get diiDisplay =>
      dii == null ? 'Unavailable' : '${dii!.label} (${dii!.formattedAmount})';

  String get dailyFlowDisplay {
    final value = dailyInstitutionalFlowCrore;
    if (value == null) return 'Unavailable';
    final sign = value >= 0 ? '+' : '-';
    return '$sign Rs ${value.abs().toStringAsFixed(value.abs() >= 100 ? 0 : 2)} Cr';
  }

  factory FiiDiiSnapshot.empty() => const FiiDiiSnapshot(
        fii: null,
        dii: null,
        dailyInstitutionalFlowCrore: null,
        trend: 'Unavailable',
        bias: 'Neutral',
        lastUpdated: null,
        insights: [
          'No real institutional flow values were found in the configured data sources.',
        ],
        newsItems: [],
        dataSource: 'No live institutional source available',
      );
}

class FiiDiiService {
  static final _marketaux = MarketauxNewsProvider();

  static Future<FiiDiiSnapshot> fetchSnapshot() async {
    final articles = await _fetchInstitutionalArticles();
    if (articles.isEmpty) return FiiDiiSnapshot.empty();

    final fiiRecords = <InstitutionalFlowRecord>[];
    final diiRecords = <InstitutionalFlowRecord>[];

    for (final article in articles) {
      final text = '${article.title}. ${article.description}';
      final fii = _extractRecord(article, text, participant: 'FII');
      final dii = _extractRecord(article, text, participant: 'DII');
      if (fii != null) fiiRecords.add(fii);
      if (dii != null) diiRecords.add(dii);
    }

    fiiRecords.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    diiRecords.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    final fii = fiiRecords.isNotEmpty ? fiiRecords.first : null;
    final dii = diiRecords.isNotEmpty ? diiRecords.first : null;
    final lastUpdated = [fii?.publishedAt, dii?.publishedAt]
        .whereType<DateTime>()
        .fold<DateTime?>(null, (latest, current) {
      if (latest == null || current.isAfter(latest)) return current;
      return latest;
    });

    final dailyFlow = (fii != null && dii != null)
        ? fii.signedAmount + dii.signedAmount
        : null;
    final biasScore = (fii?.signedAmount ?? 0) + (dii?.signedAmount ?? 0);
    final bias = biasScore > 0
        ? 'Bullish'
        : biasScore < 0
            ? 'Bearish'
            : 'Neutral';
    final trend = _trendLabel(fii, dii);
    final insights = _buildInsights(fii, dii, dailyFlow);

    return FiiDiiSnapshot(
      fii: fii,
      dii: dii,
      dailyInstitutionalFlowCrore: dailyFlow,
      trend: trend,
      bias: bias,
      lastUpdated: lastUpdated,
      insights: insights,
      newsItems: articles.take(8).toList(),
      dataSource: 'Marketaux institutional news feed',
    );
  }

  static Future<List<NewsItem>> _fetchInstitutionalArticles() async {
    final results = <NewsItem>[];
    final seen = <String>{};

    try {
      final marketauxItems = await _marketaux.fetchInstitutional();
      for (final item in marketauxItems) {
        final key = item.url.isNotEmpty ? item.url : item.title;
        if (seen.add(key)) results.add(item);
      }
    } catch (_) {}

    if (results.isEmpty) {
      try {
        final fallback = await NewsService.fetchAll(forceRefresh: true);
        for (final item in fallback.where(_isInstitutionalArticle)) {
          final key = item.url.isNotEmpty ? item.url : item.title;
          if (seen.add(key)) results.add(item);
        }
      } catch (_) {}
    }

    results.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return results;
  }

  static bool _isInstitutionalArticle(NewsItem item) {
    final text = '${item.title} ${item.description}'.toLowerCase();
    return text.contains('fii') ||
        text.contains('dii') ||
        text.contains('foreign investor') ||
        text.contains('domestic institution') ||
        text.contains('institutional flow') ||
        text.contains('fund flow');
  }

  static InstitutionalFlowRecord? _extractRecord(
    NewsItem article,
    String text, {
    required String participant,
  }) {
    final sentences = text
        .split(RegExp(r'[.!?]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    for (final sentence in sentences) {
      final lower = sentence.toLowerCase();
      if (!_matchesParticipant(lower, participant)) continue;
      final amount = _extractAmountCrore(sentence);
      if (amount == null) continue;
      final isBuy = _extractDirection(lower);
      if (isBuy == null) continue;
      return InstitutionalFlowRecord(
        participant: participant,
        amountCrore: amount,
        isBuy: isBuy,
        publishedAt: article.publishedAt,
        source: article,
      );
    }

    return null;
  }

  static bool _matchesParticipant(String text, String participant) {
    if (participant == 'FII') {
      return text.contains('fii') ||
          text.contains('fpi') ||
          text.contains('foreign institutional') ||
          text.contains('foreign investor');
    }
    return text.contains('dii') ||
        text.contains('domestic institutional') ||
        text.contains('domestic investor') ||
        text.contains('mutual fund');
  }

  static bool? _extractDirection(String text) {
    const buyWords = [
      'net buy',
      'net bought',
      'buyer',
      'bought',
      'buying',
      'inflow',
      'purchase',
      'accumulation',
    ];
    const sellWords = [
      'net sell',
      'net sold',
      'seller',
      'sold',
      'selling',
      'outflow',
      'withdraw',
      'distribution',
    ];

    for (final word in buyWords) {
      if (text.contains(word)) return true;
    }
    for (final word in sellWords) {
      if (text.contains(word)) return false;
    }
    return null;
  }

  static double? _extractAmountCrore(String text) {
    final match = RegExp(
      r'(?:(?:rs|inr)\.?\s*)?([0-9][0-9,]*(?:\.\d+)?)\s*(crore|cr|billion|bn|million|mn|lakh)?',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return null;

    final rawValue = double.tryParse((match.group(1) ?? '').replaceAll(',', ''));
    if (rawValue == null) return null;

    final unit = (match.group(2) ?? 'cr').toLowerCase();
    switch (unit) {
      case 'crore':
      case 'cr':
        return rawValue;
      case 'billion':
      case 'bn':
        return rawValue * 100;
      case 'million':
      case 'mn':
        return rawValue * 0.1;
      case 'lakh':
        return rawValue * 0.01;
      default:
        return rawValue;
    }
  }

  static String _trendLabel(
    InstitutionalFlowRecord? fii,
    InstitutionalFlowRecord? dii,
  ) {
    if (fii == null && dii == null) return 'Unavailable';
    if (fii != null && dii != null) {
      if (fii.isBuy && dii.isBuy) return 'Institutional Accumulation';
      if (!fii.isBuy && !dii.isBuy) return 'Institutional Distribution';
      if (!fii.isBuy && dii.isBuy) return 'Domestic Support';
      if (fii.isBuy && !dii.isBuy) return 'Foreign-led Buying';
    }
    final record = fii ?? dii;
    return record!.isBuy ? 'Selective Accumulation' : 'Selective Selling';
  }

  static List<String> _buildInsights(
    InstitutionalFlowRecord? fii,
    InstitutionalFlowRecord? dii,
    double? dailyFlow,
  ) {
    final insights = <String>[];

    if (fii != null) {
      insights.add(
        fii.isBuy
            ? 'Foreign investors were net buyers today.'
            : 'Foreign investors remained net sellers today.',
      );
    }

    if (dii != null) {
      insights.add(
        dii.isBuy
            ? 'Domestic institutions are supporting the market.'
            : 'Domestic institutions are trimming exposure in the current session.',
      );
    }

    if (dailyFlow != null) {
      if (dailyFlow > 0) {
        insights.add('Strong institutional accumulation detected.');
      } else if (dailyFlow < 0) {
        insights.add('Institutional selling pressure remains elevated.');
      } else {
        insights.add('Institutional participation is balanced on the latest reported flow.');
      }
    }

    if (insights.isEmpty) {
      insights.add(
        'Institutional headlines are available, but no direct buy/sell values were reported.',
      );
    }
    return insights;
  }
}
