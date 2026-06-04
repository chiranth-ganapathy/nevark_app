import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/news_config.dart';
import '../../../services/api_service.dart';
import '../models/news_item.dart';
import 'news_pipeline_log.dart';
import 'sector_mapper.dart';
import 'sentiment_engine.dart';

class MarketauxNewsProvider {
  static const _headers = {
    'Accept': 'application/json',
    'User-Agent': 'NeVark/1.0 (Flutter; Android)',
  };

  /// Core NeVark watchlist / market symbols for stock-aware news.
  static const _prioritySymbols = [
    'TCS',
    'INFY',
    'RELIANCE',
    'HDFCBANK',
    'ICICIBANK',
    'SBIN',
    'WIPRO',
    'HCLTECH',
    'KOTAKBANK',
    'AXISBANK',
    'SUNPHARMA',
    'ITC',
    'BHARTIARTL',
    'MARUTI',
    'TATASTEEL',
    'NTPC',
    'POWERGRID',
  ];

  Future<List<NewsItem>> fetch() async {
    if (!NewsConfig.hasApiKey) {
      throw Exception('Marketaux API key missing');
    }

    final results = <NewsItem>[];
    String? lastError;

    // 1) Stock-aware symbol batches (tracked NSE names)
    for (var i = 0; i < _prioritySymbols.length; i += 4) {
      final batch = _prioritySymbols.skip(i).take(4).join(',');
      try {
        final items = await _fetchWithParams({
          'symbols': batch,
          'language': 'en',
          'limit': '20',
          'filter_entities': 'false',
        });
        _mergeUnique(results, items);
      } catch (e) {
        lastError = e.toString();
        NewsPipelineLog.i('Marketaux symbols batch failed: $e');
      }
    }

    // 2) Broad India market searches
    final searchQueries = [
      'nifty OR sensex OR "indian stock market"',
      'nse OR bse OR sebi',
      'reliance OR tcs OR hdfc OR infosys OR wipro',
    ];

    for (final search in searchQueries) {
      try {
        final items = await _fetchWithParams({
          'search': search,
          'language': 'en',
          'limit': '25',
          'countries': 'in',
        });
        _mergeUnique(results, items);
      } catch (e) {
        lastError = e.toString();
        NewsPipelineLog.i('Marketaux search failed: $e');
      }
    }

    // 3) Index symbols
    try {
      final items = await _fetchWithParams({
        'symbols': 'NIFTY,BANKNIFTY,FINNIFTY',
        'language': 'en',
        'limit': '15',
        'filter_entities': 'false',
      });
      _mergeUnique(results, items);
    } catch (e) {
      lastError = e.toString();
    }

    if (results.isEmpty) {
      throw Exception(lastError ?? 'Marketaux returned no parseable articles');
    }

    results.sort(_sortStockAware);
    NewsPipelineLog.parsed(
      'Marketaux',
      results.length,
      sampleTitle: results.first.title,
    );
    return results;
  }

  int _sortStockAware(NewsItem a, NewsItem b) {
    final aStock = a.relatedStocks.any(_isTrackedSymbol) ? 1 : 0;
    final bStock = b.relatedStocks.any(_isTrackedSymbol) ? 1 : 0;
    if (aStock != bStock) return aStock > bStock ? -1 : 1;
    return b.publishedAt.compareTo(a.publishedAt);
  }

  bool _isTrackedSymbol(String s) {
    final u = s.toUpperCase();
    return kNseTokens.containsKey(u) || _prioritySymbols.contains(u);
  }

  void _mergeUnique(List<NewsItem> target, List<NewsItem> incoming) {
    for (final item in incoming) {
      if (item.title.isEmpty) continue;
      final key = item.url.isNotEmpty ? item.url : item.title;
      if (!target.any((r) =>
          (r.url.isNotEmpty && r.url == key) || r.title == item.title)) {
        target.add(item);
      }
    }
  }

  Future<List<NewsItem>> _fetchWithParams(Map<String, String> params) async {
    final uri = Uri.parse(NewsConfig.baseUrl).replace(queryParameters: {
      'api_token': NewsConfig.apiKey,
      ...params,
    });

    final safeUri = uri.replace(queryParameters: {
      ...uri.queryParameters,
      'api_token': '***',
    });
    NewsPipelineLog.i('Marketaux request: $safeUri');

    final resp = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 25));

    NewsPipelineLog.api(
      'Marketaux',
      safeUri.toString(),
      resp.statusCode,
      resp.body.length,
    );

    if (resp.statusCode == 401) {
      throw Exception('Invalid Marketaux API key');
    }
    if (resp.statusCode == 429) {
      throw Exception('Marketaux rate limit exceeded');
    }
    if (resp.statusCode != 200) {
      final preview = resp.body.length > 200
          ? resp.body.substring(0, 200)
          : resp.body;
      throw Exception('Marketaux HTTP ${resp.statusCode}: $preview');
    }

    return _parseResponseBody(resp.body);
  }

  List<NewsItem> _parseResponseBody(String body) {
    final dynamic decoded = jsonDecode(body);
    if (decoded is! Map) {
      NewsPipelineLog.i('Marketaux: root is not a Map');
      return [];
    }

    final map = Map<String, dynamic>.from(decoded);
    final meta = map['meta'];
    if (meta is Map) {
      NewsPipelineLog.i(
        'Marketaux meta: found=${meta['found']} returned=${meta['returned']}',
      );
    }

    final data = map['data'];
    if (data == null) {
      NewsPipelineLog.i('Marketaux: missing "data" key in response');
      return [];
    }
    if (data is! List) {
      NewsPipelineLog.i('Marketaux: "data" is ${data.runtimeType}, expected List');
      return [];
    }

    final items = <NewsItem>[];
    var skipped = 0;
    for (final raw in data) {
      if (raw is! Map) {
        skipped++;
        continue;
      }
      try {
        final json = Map<String, dynamic>.from(raw);
        final item = _processArticle(json);
        if (item.title.isNotEmpty) {
          items.add(item);
        } else {
          skipped++;
        }
      } catch (e) {
        skipped++;
        debugPrint('[Marketaux] parse skip: $e');
      }
    }

    NewsPipelineLog.i(
      'Marketaux batch: raw=${data.length} parsed=${items.length} skipped=$skipped',
    );
    if (items.isNotEmpty) {
      NewsPipelineLog.i('Sample body: ${body.length > 400 ? body.substring(0, 400) : body}');
    }
    return items;
  }

  NewsItem _processArticle(Map<String, dynamic> json) {
    final title = json['title']?.toString() ?? '';
    final desc = json['description']?.toString() ??
        json['snippet']?.toString() ??
        '';
    final combined = '$title $desc';

    final sentResult = SentimentEngine.analyse(combined);
    final mapResult = SectorMapper.map(combined);

    return NewsItem.fromMarketaux(
      json,
      sentiment: sentResult.sentiment,
      sentimentScore: sentResult.score,
      sector: mapResult.sector,
      relatedStocks: mapResult.relatedStocks,
    );
  }
}
