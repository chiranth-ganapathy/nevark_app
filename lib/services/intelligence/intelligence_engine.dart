import '../api_service.dart' show kSectorStocks;
import '../market_store.dart';
import 'market_insights.dart';
import 'news_sentiment_cache.dart';
import 'sector_intelligence.dart';
import 'stock_intelligence.dart';

export 'indicator_explainer.dart';
export 'market_insights.dart';
export 'news_sentiment_cache.dart';
export 'sector_intelligence.dart';
export 'stock_intelligence.dart';

/// Central intelligence API for NeVark.
class IntelligenceEngine {
  IntelligenceEngine._();

  static Future<void> bootstrap() => NewsSentimentCache.preload();

  static StockIntelligence? stock(String symbol) {
    final q = MarketStore.instance.quote(symbol.toUpperCase());
    if (q == null || q.ltp <= 0) return null;
    return StockIntelligence.fromQuote(q);
  }

  static SectorIntelligence? sector(String name) {
    if (!kSectorStocks.containsKey(name)) return null;
    return SectorIntelligence.forSector(name);
  }

  static MarketInsights marketInsights() => MarketInsights.generate();

  static String formatStockBrief(StockIntelligence intel) {
    final p = intel.prediction;
    final fc = p.forecast;
    return '${intel.symbol}\n'
        'Price: ${intel.priceStr} (${intel.changeStr})\n'
        'Signal: ${intel.signal} · ${intel.confidence}% confidence\n'
        'Risk: ${intel.risk} · Trend: ${intel.trend}\n'
        'Direction: ${intel.expectedDirection}\n\n'
        'What happened?\n${intel.whatHappened}\n\n'
        'Why?\n${intel.why}\n\n'
        'What to watch?\n${intel.whatToWatch}\n\n'
        'Action\n${intel.actionHint}\n\n'
        'Forecast (5D): ${fc.price5dStr} · ${fc.trend}';
  }
}
