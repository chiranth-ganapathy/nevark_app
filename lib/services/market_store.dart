import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/models/stock_quote.dart';
import 'api_service.dart';
import 'prediction_service.dart';

/// Central in-memory market state — only [ApiService] writes here.
class MarketStore extends ChangeNotifier {
  MarketStore._();
  static final MarketStore instance = MarketStore._();

  final _controller = StreamController<MarketSnapshot>.broadcast();

  final Map<String, StockQuote> _indices = {};
  final List<StockQuote> _stocks = [];
  Map<String, SectorPrediction> _sectors = {};
  final Map<String, StockPrediction> _predictions = {};
  MarketInfo _marketStatus = MarketInfo.current();
  DateTime? _lastUpdated;
  String? _lastError;
  bool _hasData = false;

  Stream<MarketSnapshot> get stream => _controller.stream;

  MarketSnapshot get snapshot => MarketSnapshot(
        indices: Map.unmodifiable(_indices),
        stocks: List.unmodifiable(_stocks),
        sectors: Map.unmodifiable(_sectors),
        predictions: Map.unmodifiable(_predictions),
        marketStatus: _marketStatus,
        lastUpdated: _lastUpdated,
        lastError: _lastError,
        hasData: _hasData,
      );

  Map<String, StockQuote> get indices => Map.unmodifiable(_indices);
  List<StockQuote> get stocks => List.unmodifiable(_stocks);
  Map<String, SectorPrediction> get sectors => Map.unmodifiable(_sectors);
  Map<String, StockPrediction> get predictions => Map.unmodifiable(_predictions);
  MarketInfo get marketStatus => _marketStatus;
  DateTime? get lastUpdated => _lastUpdated;
  String? get lastError => _lastError;
  bool get hasData => _hasData;

  StockQuote? quote(String symbol) {
    final sym = symbol.toUpperCase();
    return _indices[sym] ?? _findStock(sym);
  }

  StockPrediction? prediction(String symbol) =>
      _predictions[symbol.toUpperCase()];

  SectorPrediction? sector(String name) => _sectors[name];

  /// Called by ApiService after Angel One fetch completes.
  void applyQuotes(List<StockQuote> quotes, {String? error}) {
    _marketStatus = MarketInfo.current();
    _lastError = error;

    if (quotes.isNotEmpty) {
      for (final q in quotes) {
        if (q.symbol.isEmpty || q.ltp <= 0) continue;

        if (kPrimaryIndexKeys.contains(q.symbol)) {
          _indices[q.symbol] = q;
        } else {
          final idx = _stocks.indexWhere((s) => s.symbol == q.symbol);
          if (idx >= 0) {
            _stocks[idx] = q;
          } else {
            _stocks.add(q);
          }
        }

        _predictions[q.symbol] = StockPrediction.fromQuote(q);
      }

      _stocks.sort((a, b) => b.changePercent.compareTo(a.changePercent));
      _rebuildSectors();
      _lastUpdated = DateTime.now();
      _hasData = true;
    }

    notifyListeners();
    _controller.add(snapshot);
  }

  void setError(String message) {
    _lastError = message;
    _marketStatus = MarketInfo.current();
    notifyListeners();
    _controller.add(snapshot);
  }

  /// Updates market open/closed status without clearing quotes.
  void refreshMarketStatus() {
    _marketStatus = MarketInfo.current();
    notifyListeners();
    _controller.add(snapshot);
  }

  static const _cacheKey = 'market_quote_cache';

  /// Restore last saved quotes (e.g. after app restart on weekend).
  Future<void> loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw) as List;
      final quotes = list
          .map((e) => StockQuote.fromJson(e as Map<String, dynamic>))
          .where((q) => q.ltp > 0)
          .toList();
      if (quotes.isNotEmpty) {
        applyQuotes(quotes);
        debugPrint('[MarketStore] Restored ${quotes.length} cached quotes');
      }
    } catch (e) {
      debugPrint('[MarketStore] Cache load failed: $e');
    }
  }

  Future<void> saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = [..._indices.values, ..._stocks];
      if (all.isEmpty) return;
      final json = jsonEncode(all.map((q) => _quoteToJson(q)).toList());
      await prefs.setString(_cacheKey, json);
    } catch (e) {
      debugPrint('[MarketStore] Cache save failed: $e');
    }
  }

  static Map<String, dynamic> _quoteToJson(StockQuote q) => {
        'symbol': q.symbol,
        'name': q.name,
        'ltp': q.ltp,
        'open': q.open,
        'high': q.high,
        'low': q.low,
        'close': q.close,
        'change': q.change,
        'changePercent': q.changePercent,
        'volume': q.volume,
      };

  void _rebuildSectors() {
    final map = <String, SectorPrediction>{};
    for (final entry in kSectorStocks.entries) {
      final quotes = entry.value
          .map((sym) => quote(sym))
          .whereType<StockQuote>()
          .where((q) => q.ltp > 0)
          .toList();
      if (quotes.isNotEmpty) {
        map[entry.key] = SectorPrediction.fromStocks(entry.key, quotes);
      }
    }
    _sectors = map;
  }

  StockQuote? _findStock(String sym) {
    for (final q in _stocks) {
      if (q.symbol == sym) return q;
    }
    return null;
  }

  DashboardData toDashboardData() {
    final idx = Map<String, StockQuote>.from(_indices);
    final all = List<StockQuote>.from(_stocks);
    return DashboardData(
      indices: idx,
      gainers: all.where((s) => s.change >= 0).take(10).toList(),
      losers: all.where((s) => s.change < 0).toList().reversed.take(10).toList(),
      allStocks: all,
    );
  }

  SectorData sectorData(String name) {
    final pred = _sectors[name];
    final quotes = (kSectorStocks[name] ?? [])
        .map((sym) => quote(sym))
        .whereType<StockQuote>()
        .where((q) => q.ltp > 0)
        .toList();

    if (pred != null) {
      return SectorData(
        name: name,
        stocks: quotes,
        avgChange: pred.avgChange,
        trend: pred.trend.toUpperCase(),
        signal: pred.signal,
        confidence: pred.confidence,
        avgRsi: pred.avgRsi,
        reason: pred.reason,
        momentum: _momentumLabel(pred),
        strength: _strengthLabel(pred),
      );
    }

    if (quotes.isEmpty) {
      return SectorData(
        name: name,
        stocks: const [],
        avgChange: 0,
        trend: 'NEUTRAL',
        signal: 'HOLD',
        confidence: 50,
      );
    }

    final avg =
        quotes.map((q) => q.changePercent).reduce((a, b) => a + b) / quotes.length;
    return SectorData(
      name: name,
      stocks: quotes,
      avgChange: avg,
      trend: avg >= 0 ? 'BULLISH' : 'BEARISH',
      signal: avg >= 0 ? 'BUY' : 'SELL',
      confidence: 55,
      reason: 'Awaiting sector prediction data',
    );
  }

  static String _momentumLabel(SectorPrediction p) {
    if (p.avgChange > 0.5) return 'Positive momentum';
    if (p.avgChange < -0.5) return 'Negative momentum';
    return 'Neutral momentum';
  }

  static String _strengthLabel(SectorPrediction p) {
    if (p.avgRsi > 60) return 'Strong';
    if (p.avgRsi < 40) return 'Weak';
    return 'Moderate';
  }

  void disposeStore() {
    _controller.close();
  }
}

class MarketSnapshot {
  final Map<String, StockQuote> indices;
  final List<StockQuote> stocks;
  final Map<String, SectorPrediction> sectors;
  final Map<String, StockPrediction> predictions;
  final MarketInfo marketStatus;
  final DateTime? lastUpdated;
  final String? lastError;
  final bool hasData;

  const MarketSnapshot({
    required this.indices,
    required this.stocks,
    required this.sectors,
    required this.predictions,
    required this.marketStatus,
    this.lastUpdated,
    this.lastError,
    required this.hasData,
  });
}
