import '../../core/models/stock_quote.dart';
import '../api_service.dart';
import '../market_store.dart';
import '../prediction_service.dart';
import 'news_sentiment_cache.dart';

/// AI-generated market-wide insights from live MarketStore data.
class MarketInsights {
  final List<StockQuote> topGainers;
  final List<StockQuote> topLosers;
  final String strongestSector;
  final String weakestSector;
  final String? mostBullishStock;
  final String? mostBearishStock;
  final String marketSentiment;
  final int sentimentScore;
  final String summary;
  final SentimentSnapshot newsSentiment;

  const MarketInsights({
    required this.topGainers,
    required this.topLosers,
    required this.strongestSector,
    required this.weakestSector,
    this.mostBullishStock,
    this.mostBearishStock,
    required this.marketSentiment,
    required this.sentimentScore,
    required this.summary,
    required this.newsSentiment,
  });

  static MarketInsights generate() {
    final store = MarketStore.instance;
    final stocks = [...store.stocks]..sort(
        (a, b) => b.changePercent.compareTo(a.changePercent),
      );

    final gainers = stocks.where((s) => s.change > 0).take(5).toList();
    final losers = [...stocks]
      ..sort((a, b) => a.changePercent.compareTo(b.changePercent));
    final loserList = losers.where((s) => s.change < 0).take(5).toList();

    String strongest = '—';
    String weakest = '—';
    double bestChg = -999;
    double worstChg = 999;

    for (final name in kSectorStocks.keys) {
      final sp = store.sector(name);
      if (sp == null) continue;
      if (sp.avgChange > bestChg) {
        bestChg = sp.avgChange;
        strongest = name;
      }
      if (sp.avgChange < worstChg) {
        worstChg = sp.avgChange;
        weakest = name;
      }
    }

    String? bullish;
    String? bearish;
    int bestConf = 0;
    int worstConf = 0;

    for (final q in stocks) {
      final p = store.prediction(q.symbol) ?? StockPrediction.fromQuote(q);
      if (p.signalStr == 'BUY' && p.confidence > bestConf) {
        bestConf = p.confidence;
        bullish = '${q.symbol} (${p.confidence}% BUY)';
      }
      if (p.signalStr == 'SELL' && p.confidence > worstConf) {
        worstConf = p.confidence;
        bearish = '${q.symbol} (${p.confidence}% SELL)';
      }
    }

    final nifty = store.quote('NIFTY');
    final up = stocks.where((s) => s.change >= 0).length;
    final down = stocks.where((s) => s.change < 0).length;
    final total = stocks.length;

    String sentiment;
    int score;
    if (nifty != null && nifty.changePercent > 0.4 && up > down) {
      sentiment = 'Bullish';
      score = (50 + nifty.changePercent * 8 + (up / (total + 1)) * 30).round();
    } else if (nifty != null && nifty.changePercent < -0.4 && down > up) {
      sentiment = 'Bearish';
      score = (-50 + nifty.changePercent * 8).round();
    } else {
      sentiment = 'Neutral';
      score = 0;
    }
    score = score.clamp(-100, 100);

    final news = NewsSentimentCache.forMarket();
    if (news.articleCount > 0) {
      score = ((score * 0.6) + news.impactScore * 0.4).round();
      if (score > 15) {
        sentiment = 'Bullish';
      } else if (score < -15) {
        sentiment = 'Bearish';
      } else {
        sentiment = 'Neutral';
      }
    }

    final summary = stocks.isEmpty
        ? 'Waiting for live market data.'
        : 'Market is $sentiment — $up advancers vs $down decliners. '
            'Strongest sector: $strongest (${bestChg >= 0 ? '+' : ''}${bestChg.toStringAsFixed(2)}%). '
            'Weakest: $weakest (${worstChg.toStringAsFixed(2)}%). '
            '${news.summary}';

    return MarketInsights(
      topGainers: gainers,
      topLosers: loserList,
      strongestSector: strongest,
      weakestSector: weakest,
      mostBullishStock: bullish,
      mostBearishStock: bearish,
      marketSentiment: sentiment,
      sentimentScore: score,
      summary: summary,
      newsSentiment: news,
    );
  }
}
