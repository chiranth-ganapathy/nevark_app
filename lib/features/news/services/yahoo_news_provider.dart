import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import '../../../services/api_service.dart';
import '../models/news_item.dart';
import 'news_pipeline_log.dart';
import 'sector_mapper.dart';
import 'sentiment_engine.dart';

/// Yahoo Finance RSS headlines — sole news provider for NeVark.
///
/// Fetches from multiple Yahoo Finance RSS feeds covering Indian indices,
/// top NSE stocks, and regional market news.
class YahooNewsProvider {
  /// Core market feeds — India region + major indices.
  static const _coreFeedUrls = [
    // India regional headlines
    'https://feeds.finance.yahoo.com/rss/2.0/headline?region=IN&lang=en-IN',
    // Nifty 50 index
    'https://feeds.finance.yahoo.com/rss/2.0/headline?s=%5ENSEI&region=IN&lang=en-IN',
    // Nifty Bank index
    'https://feeds.finance.yahoo.com/rss/2.0/headline?s=%5ENSEBANK&region=IN&lang=en-IN',
    // Sensex
    'https://feeds.finance.yahoo.com/rss/2.0/headline?s=%5EBSESN&region=IN&lang=en-IN',
  ];

  /// Per-stock feeds for major NSE blue-chips.
  /// Yahoo Finance uses .NS suffix for NSE-listed equities.
  static const _stockFeedSymbols = [
    'RELIANCE.NS',
    'TCS.NS',
    'HDFCBANK.NS',
    'INFY.NS',
    'ICICIBANK.NS',
    'SBIN.NS',
    'BHARTIARTL.NS',
    'ITC.NS',
    'KOTAKBANK.NS',
    'HINDUNILVR.NS',
    'LT.NS',
    'AXISBANK.NS',
    'MARUTI.NS',
    'SUNPHARMA.NS',
    'TATAMOTORS.NS',
    'NTPC.NS',
    'WIPRO.NS',
    'HCLTECH.NS',
    'BAJFINANCE.NS',
    'TATASTEEL.NS',
    'POWERGRID.NS',
    'ONGC.NS',
    'DRREDDY.NS',
    'JSWSTEEL.NS',
    'M%26M.NS',
    'TECHM.NS',
    'DIVISLAB.NS',
    'CIPLA.NS',
    'NESTLEIND.NS',
    'BAJAJ-AUTO.NS',
  ];

  // ignore: unused_element
  static List<String> get _allFeedUrls {
    final urls = <String>[..._coreFeedUrls];
    for (final sym in _stockFeedSymbols) {
      urls.add(
        'https://feeds.finance.yahoo.com/rss/2.0/headline?s=$sym&region=IN&lang=en-IN',
      );
    }
    return urls;
  }

  /// Fetch articles from all Yahoo Finance RSS feeds.
  Future<List<NewsItem>> fetch() async {
    final results = <NewsItem>[];
    final seenKeys = <String>{};
    String? lastError;
    int successCount = 0;

    // 1. Fetch core feeds
    for (final url in _coreFeedUrls) {
      try {
        final items = await _fetchFeed(url);
        for (final item in items) {
          if (item.title.isEmpty) continue;
          // Deduplicate by URL first, then title
          final key = item.url.isNotEmpty ? item.url : item.title;
          if (seenKeys.contains(key)) continue;
          seenKeys.add(key);
          // Also prevent near-duplicate titles
          if (item.url.isEmpty && seenKeys.contains(item.title)) continue;
          if (item.url.isNotEmpty) seenKeys.add(item.title);
          results.add(item);
        }
        successCount++;
        NewsPipelineLog.parsed(
          'Yahoo Core',
          items.length,
          sampleTitle: items.isNotEmpty ? items.first.title : null,
        );
      } catch (e) {
        lastError = e.toString();
        debugPrint('[YahooNews] core feed failed: $url → $e');
      }
    }

    // 2. Fetch stock-specific feeds and pass their ticker context
    for (final sym in _stockFeedSymbols) {
      final cleanSymbol = sym.replaceAll('.NS', '');
      final url = 'https://feeds.finance.yahoo.com/rss/2.0/headline?s=$sym&region=IN&lang=en-IN';
      try {
        final items = await _fetchFeed(url, feedSymbol: cleanSymbol);
        for (final item in items) {
          if (item.title.isEmpty) continue;
          // Deduplicate by URL first, then title
          final key = item.url.isNotEmpty ? item.url : item.title;
          if (seenKeys.contains(key)) continue;
          seenKeys.add(key);
          // Also prevent near-duplicate titles
          if (item.url.isEmpty && seenKeys.contains(item.title)) continue;
          if (item.url.isNotEmpty) seenKeys.add(item.title);
          results.add(item);
        }
        successCount++;
      } catch (e) {
        lastError = e.toString();
      }
    }

    NewsPipelineLog.i(
      'Yahoo total: $successCount feeds OK, ${results.length} unique articles',
    );

    if (results.isEmpty) {
      throw Exception(
        lastError ?? 'Yahoo Finance RSS returned no articles from any feed',
      );
    }

    results.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return results;
  }

  Future<List<NewsItem>> _fetchFeed(String url, {String? feedSymbol}) async {
    final resp = await http
        .get(
          Uri.parse(url),
          headers: {
            'User-Agent': 'NeVark/1.0 (Flutter; Android)',
            'Accept': 'application/rss+xml, application/xml, text/xml, */*',
          },
        )
        .timeout(const Duration(seconds: 15));

    NewsPipelineLog.api('Yahoo', url, resp.statusCode, resp.body.length);

    if (resp.statusCode != 200) {
      throw Exception('Yahoo RSS HTTP ${resp.statusCode}');
    }

    if (resp.body.trim().isEmpty) {
      throw Exception('Yahoo RSS returned empty body');
    }

    return _parseRss(resp.body, feedSymbol: feedSymbol);
  }

  static List<NewsItem> _parseRss(String xml, {String? feedSymbol}) {
    final items = <NewsItem>[];
    final itemBlocks = RegExp(
      r'<item[^>]*>([\s\S]*?)</item>',
      caseSensitive: false,
    ).allMatches(xml);

    for (final block in itemBlocks) {
      final chunk = block.group(1) ?? '';
      final title = _tag(chunk, 'title');
      if (title.isEmpty) continue;

      final desc = _tag(chunk, 'description');
      final link = _tag(chunk, 'link');
      final pubDate = _tag(chunk, 'pubDate');
      final source = _tag(chunk, 'source');
      final combined = '$title $desc';

      final sent = SentimentEngine.analyse(combined);
      final map = SectorMapper.map(combined);

      String sector = map.sector;
      final stocks = List<String>.from(map.relatedStocks);

      if (feedSymbol != null) {
        if (!stocks.contains(feedSymbol)) {
          stocks.add(feedSymbol);
        }
        if (sector == 'General') {
          for (final entry in kSectorStocks.entries) {
            if (entry.value.contains(feedSymbol)) {
              sector = entry.key;
              break;
            }
          }
        }
      }

      items.add(NewsItem(
        title: _decode(title),
        description: _decode(desc),
        source: source.isNotEmpty ? _decode(source) : 'Yahoo Finance',
        url: link,
        imageUrl: _extractImageUrl(chunk),
        publishedAt: _parseRssDate(pubDate),
        sentiment: sent.sentiment,
        sentimentScore: sent.score,
        sector: sector,
        relatedStocks: stocks,
      ));
    }
    return items;
  }

  /// Extract text from an XML tag, handling CDATA sections.
  static String _tag(String xml, String tag) {
    // Try CDATA first: <tag><![CDATA[content]]></tag>
    // In a non-raw Dart string we need \\ to produce a single \ for regex.
    final cdataPattern = RegExp(
      '<$tag[^>]*><!\\[CDATA\\[([\\s\\S]*?)\\]\\]></$tag>',
      caseSensitive: false,
    );
    final cdataMatch = cdataPattern.firstMatch(xml);
    if (cdataMatch != null) {
      return (cdataMatch.group(1) ?? '').trim();
    }

    // Plain text: <tag>content</tag>
    final plainPattern = RegExp(
      '<$tag[^>]*>([\\s\\S]*?)</$tag>',
      caseSensitive: false,
    );
    final plainMatch = plainPattern.firstMatch(xml);
    if (plainMatch != null) {
      return (plainMatch.group(1) ?? '').trim();
    }

    return '';
  }


  /// Try to extract an image URL from media:content, media:thumbnail,
  /// or enclosure tags within the RSS item.
  static String _extractImageUrl(String chunk) {
    // media:content url="..."
    final mediaContent = RegExp(
      r'<media:content[^>]+url="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(chunk);
    if (mediaContent != null) return mediaContent.group(1) ?? '';

    // media:thumbnail url="..."
    final mediaThumbnail = RegExp(
      r'<media:thumbnail[^>]+url="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(chunk);
    if (mediaThumbnail != null) return mediaThumbnail.group(1) ?? '';

    // enclosure url="..." type="image/..."
    final enclosure = RegExp(
      r'<enclosure[^>]+url="([^"]+)"[^>]+type="image/',
      caseSensitive: false,
    ).firstMatch(chunk);
    if (enclosure != null) return enclosure.group(1) ?? '';

    // img src="..." inside description CDATA
    final imgSrc = RegExp(
      r'<img[^>]+src="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(chunk);
    if (imgSrc != null) {
      final url = imgSrc.group(1) ?? '';
      if (url.startsWith('http')) return url;
    }

    return '';
  }

  static String _decode(String s) {
    return s
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&#x27;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&#8217;', '\u2019') // right single quote
        .replaceAll('&#8216;', '\u2018') // left single quote
        .replaceAll('&#8220;', '\u201C') // left double quote
        .replaceAll('&#8221;', '\u201D') // right double quote
        .replaceAll('&#8211;', '\u2013') // en dash
        .replaceAll('&#8212;', '\u2014') // em dash
        .replaceAll(RegExp(r'<[^>]+>'), ''); // strip remaining HTML tags
  }

  static DateTime _parseRssDate(String raw) {
    if (raw.isEmpty) return DateTime.now();
    const patterns = [
      'EEE, dd MMM yyyy HH:mm:ss Z',
      'EEE, dd MMM yyyy HH:mm:ss zzz',
      'EEE, dd MMM yyyy HH:mm:ss',
      'dd MMM yyyy HH:mm:ss Z',
      'yyyy-MM-ddTHH:mm:ssZ',
    ];
    for (final pattern in patterns) {
      try {
        return DateFormat(pattern, 'en_US').parseUtc(raw);
      } catch (_) {}
    }
    return DateTime.tryParse(raw) ?? DateTime.now();
  }
}
