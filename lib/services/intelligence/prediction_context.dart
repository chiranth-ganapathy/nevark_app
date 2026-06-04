import '../../core/models/stock_quote.dart';
import '../api_service.dart';
import '../market_store.dart';
import '../prediction_service.dart' show PriceHistory;
import 'news_sentiment_cache.dart';

/// External features fed into the prediction engine per stock.
class PredictionContext {
  final String? sectorName;
  final double sectorStrength;
  final double marketTrend;
  final double newsSentiment;
  final SentimentSnapshot newsSnapshot;
  final int priceHistoryPoints;

  const PredictionContext({
    this.sectorName,
    required this.sectorStrength,
    required this.marketTrend,
    required this.newsSentiment,
    required this.newsSnapshot,
    required this.priceHistoryPoints,
  });

  factory PredictionContext.fromStore(StockQuote quote) {
    String? sector;
    double sectorStr = 0;

    for (final entry in kSectorStocks.entries) {
      if (entry.value.contains(quote.symbol)) {
        sector = entry.key;
        final sp = MarketStore.instance.sector(entry.key);
        if (sp != null) {
          sectorStr = (sp.avgChange / 3).clamp(-1.0, 1.0);
          if (sp.trend == 'Bullish') sectorStr += 0.2;
          if (sp.trend == 'Bearish') sectorStr -= 0.2;
          sectorStr = sectorStr.clamp(-1.0, 1.0);
        }
        break;
      }
    }

    final nifty = MarketStore.instance.quote('NIFTY');
    double market = 0;
    if (nifty != null) {
      market = (nifty.changePercent / 2).clamp(-1.0, 1.0);
    }

    final news = NewsSentimentCache.forSymbol(quote.symbol);

    return PredictionContext(
      sectorName: sector,
      sectorStrength: sectorStr,
      marketTrend: market,
      newsSentiment: news.normalized,
      newsSnapshot: news,
      priceHistoryPoints: PriceHistory.count(quote.symbol),
    );
  }
}
