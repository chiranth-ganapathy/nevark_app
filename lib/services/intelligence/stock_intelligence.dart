import '../../core/models/stock_quote.dart';
import '../prediction_service.dart';
import 'indicator_explainer.dart';
import 'prediction_context.dart';

/// Full intelligence package for a single stock.
class StockIntelligence {
  final StockQuote quote;
  final StockPrediction prediction;
  final PredictionContext context;
  final TechnicalNarratives narratives;
  final double volatilityPct;

  const StockIntelligence({
    required this.quote,
    required this.prediction,
    required this.context,
    required this.narratives,
    required this.volatilityPct,
  });

  factory StockIntelligence.fromQuote(StockQuote q) {
    final ctx = PredictionContext.fromStore(q);
    final pred = StockPrediction.fromQuote(q, context: ctx);
    final ind = pred.signal.indicators;
    final vol = IndicatorExplainer.volatilityPercent(q);

    final narratives = TechnicalNarratives(
      rsi: IndicatorExplainer.explainRsi(ind.rsi),
      ema: IndicatorExplainer.explainEmaTrend(ind.maLabel, ind.ema9, ind.ema21),
      macd: IndicatorExplainer.explainMacd(ind.macdLabel, ind.macd, ind.macdSignal),
      bollinger: IndicatorExplainer.explainBollinger(q.ltp, ind),
      atr: IndicatorExplainer.explainAtr(ind.atr, vol),
      volume: IndicatorExplainer.explainVolume(ind.volumeLabel),
      volatility: IndicatorExplainer.explainVolatility(vol),
    );

    return StockIntelligence(
      quote: q,
      prediction: pred,
      context: ctx,
      narratives: narratives,
      volatilityPct: vol,
    );
  }

  String get symbol => quote.symbol;
  String get priceStr => quote.priceStr;
  String get changeStr => quote.changePctStr;
  String get signal => prediction.signalStr;
  int get confidence => prediction.confidence;
  String get risk => prediction.risk;
  String get trend => prediction.forecast.trend;
  String get reason => prediction.reason;
  String get whatHappened => prediction.whatHappened;
  String get why => prediction.reason;
  String get whatToWatch => prediction.whatToWatch;
  String get actionHint => prediction.actionHint;
  String get expectedDirection => prediction.expectedDirection;
  String get forecast5d => prediction.forecast.price5dStr;
}

class TechnicalNarratives {
  final String rsi;
  final String ema;
  final String macd;
  final String bollinger;
  final String atr;
  final String volume;
  final String volatility;

  const TechnicalNarratives({
    required this.rsi,
    required this.ema,
    required this.macd,
    required this.bollinger,
    required this.atr,
    required this.volume,
    required this.volatility,
  });
}
