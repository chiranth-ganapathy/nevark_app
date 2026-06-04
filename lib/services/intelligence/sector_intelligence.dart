import '../../core/models/stock_quote.dart';
import '../api_service.dart';
import '../market_store.dart';
import '../prediction_service.dart';
import 'news_sentiment_cache.dart';

class SectorIntelligence {
  final String name;
  final SectorPrediction prediction;
  final List<StockQuote> topStocks;
  final List<StockQuote> weakStocks;
  final SentimentSnapshot newsSentiment;
  final String whatHappened;
  final String actionHint;

  const SectorIntelligence({
    required this.name,
    required this.prediction,
    required this.topStocks,
    required this.weakStocks,
    required this.newsSentiment,
    required this.whatHappened,
    required this.actionHint,
  });

  factory SectorIntelligence.forSector(String sectorName) {
    final quotes = (kSectorStocks[sectorName] ?? [])
        .map((s) => MarketStore.instance.quote(s))
        .whereType<StockQuote>()
        .where((q) => q.ltp > 0)
        .toList();

    final pred = quotes.isEmpty
        ? SectorPrediction(
            name: sectorName,
            trend: 'Neutral',
            signal: 'HOLD',
            confidence: 50,
            avgChange: 0,
            avgRsi: 50,
            reason: 'Awaiting live data',
            stockPredictions: [],
          )
        : SectorPrediction.fromStocks(sectorName, quotes);

    final sorted = [...quotes]
      ..sort((a, b) => b.changePercent.compareTo(a.changePercent));
    final top = sorted.take(3).toList();
    final weak = [...quotes]
      ..sort((a, b) => a.changePercent.compareTo(b.changePercent));
    final weakList = weak.take(3).toList();

    final news = NewsSentimentCache.forSector(sectorName);

    final whatHappened = quotes.isEmpty
        ? '$sectorName sector has no live quotes yet.'
        : '$sectorName is ${pred.trend.toLowerCase()} today '
            '(avg ${pred.avgChangeStr}). '
            '${pred.stockPredictions.where((p) => p.signalStr == 'BUY').length} of '
            '${pred.stockPredictions.length} stocks show BUY.';

    final actionHint = pred.signal == 'BUY'
        ? 'Sector bias is positive — focus on leaders; avoid weakest laggards.'
        : pred.signal == 'SELL'
            ? 'Sector bias is negative — reduce exposure; wait for reversal signals.'
            : 'Mixed sector — stock-pick carefully; prefer high-confidence leaders.';

    return SectorIntelligence(
      name: sectorName,
      prediction: pred,
      topStocks: top,
      weakStocks: weakList,
      newsSentiment: news,
      whatHappened: whatHappened,
      actionHint: actionHint,
    );
  }
}
