 
import 'dart:math' as math;

import '../core/models/stock_quote.dart';
import 'intelligence/prediction_context.dart';
 
// ─────────────────────────────────────────────────────────────────
// PRICE HISTORY STORE
// Maintains rolling 100-tick price history per symbol for indicators
// ─────────────────────────────────────────────────────────────────
class PriceHistory {
  static final Map<String, List<double>> _history = {};
  static final Map<String, List<int>>    _volumes = {};
  static const int _maxLen = 100;
 
  static void push(String symbol, double price, int volume) {
    _history.putIfAbsent(symbol, () => []);
    _volumes.putIfAbsent(symbol, () => []);
    _history[symbol]!.add(price);
    _volumes[symbol]!.add(volume);
    if (_history[symbol]!.length > _maxLen) {
      _history[symbol]!.removeAt(0);
      _volumes[symbol]!.removeAt(0);
    }
  }
 
  static List<double> prices(String symbol) => _history[symbol] ?? [];
  static List<int>    volumes(String symbol) => _volumes[symbol] ?? [];
  static int          count(String symbol)   => (_history[symbol] ?? []).length;
}
 
// ─────────────────────────────────────────────────────────────────
// TECHNICAL INDICATORS — computed from real price history
// ─────────────────────────────────────────────────────────────────
class TechnicalIndicators {
  final double rsi;
  final double ema9;
  final double ema21;
  final double sma50;
  final double macd;
  final double macdSignal;
  final double bbUpper;
  final double bbLower;
  final double bbMid;
  final double atr;
  final double volumeAvg;
  final double currentVolume;
  final int    dataPoints;
 
  // Derived labels
  String get rsiLabel {
    if (rsi > 75) return 'Overbought';
    if (rsi > 60) return 'Strong';
    if (rsi > 40) return 'Healthy';
    if (rsi > 25) return 'Weak';
    return 'Oversold';
  }
 
  String get maLabel {
    if (ema9 > ema21 && ema21 > sma50) return 'Strong Uptrend';
    if (ema9 > ema21) return 'Above EMA';
    if (ema9 < ema21 && ema21 < sma50) return 'Strong Downtrend';
    if (ema9 < ema21) return 'Below EMA';
    return 'Neutral';
  }
 
  String get bbLabel {
    if (bbUpper <= bbMid) return 'Neutral';
    // Will be filled with current price in prediction
    return 'Normal Range';
  }
 
  String get volumeLabel {
    if (currentVolume > volumeAvg * 2.0) return 'Very High Volume';
    if (currentVolume > volumeAvg * 1.4) return 'High Volume';
    if (currentVolume > volumeAvg * 0.8) return 'Normal Volume';
    if (currentVolume > volumeAvg * 0.5) return 'Low Volume';
    return 'Very Low Volume';
  }
 
  String get macdLabel {
    if (macd > macdSignal + 2) return 'Strong Bullish';
    if (macd > macdSignal)     return 'Bullish Cross';
    if (macd < macdSignal - 2) return 'Strong Bearish';
    if (macd < macdSignal)     return 'Bearish Cross';
    return 'Neutral';
  }
 
  const TechnicalIndicators({
    required this.rsi,
    required this.ema9,
    required this.ema21,
    required this.sma50,
    required this.macd,
    required this.macdSignal,
    required this.bbUpper,
    required this.bbLower,
    required this.bbMid,
    required this.atr,
    required this.volumeAvg,
    required this.currentVolume,
    required this.dataPoints,
  });
 
  // ── Compute from price history ──────────────────────────
  factory TechnicalIndicators.compute(String symbol, StockQuote quote) {
    final prices  = PriceHistory.prices(symbol);
    final volumes = PriceHistory.volumes(symbol);
    final n       = prices.length;
 
    if (n < 5) {
      // Not enough data — derive from quote fields only
      final pct = quote.changePercent;
      final rsiEst = (50 + pct * 4).clamp(10.0, 90.0);
      return TechnicalIndicators(
        rsi: rsiEst, ema9: quote.ltp, ema21: quote.ltp,
        sma50: quote.close, macd: pct * 2, macdSignal: pct,
        bbUpper: quote.high, bbLower: quote.low,
        bbMid: (quote.high + quote.low) / 2,
        atr: quote.high - quote.low,
        volumeAvg: quote.volume.toDouble(),
        currentVolume: quote.volume.toDouble(),
        dataPoints: n,
      );
    }
 
    // RSI (14-period)
    final rsi = _rsi(prices, 14);
 
    // EMA
    final ema9  = _ema(prices, 9);
    final ema21 = _ema(prices, math.min(21, n));
    final sma50 = _sma(prices, math.min(50, n));
 
    // MACD (12,26,9)
    final ema12     = _ema(prices, math.min(12, n));
    final ema26     = _ema(prices, math.min(26, n));
    final macdLine  = ema12 - ema26;
    final macdSig   = macdLine * 0.9; // simplified signal
 
    // Bollinger Bands (20-period, 2 std)
    final period    = math.min(20, n);
    final mid       = _sma(prices, period);
    final std       = _std(prices.sublist(n - period), mid);
    final bbUpper   = mid + 2 * std;
    final bbLower   = mid - 2 * std;
 
    // ATR (simplified)
    final atr = _atr(prices, math.min(14, n));
 
    // Volume averages
    final volAvg = volumes.length > 1
        ? volumes.reduce((a, b) => a + b) / volumes.length.toDouble()
        : quote.volume.toDouble();
 
    return TechnicalIndicators(
      rsi: rsi, ema9: ema9, ema21: ema21, sma50: sma50,
      macd: macdLine, macdSignal: macdSig,
      bbUpper: bbUpper, bbLower: bbLower, bbMid: mid,
      atr: atr, volumeAvg: volAvg,
      currentVolume: quote.volume.toDouble(),
      dataPoints: n,
    );
  }
 
  // ── Math helpers ─────────────────────────────────────────
  static double _sma(List<double> p, int n) {
    if (p.isEmpty) return 0;
    final sub = p.sublist(math.max(0, p.length - n));
    return sub.reduce((a, b) => a + b) / sub.length;
  }
 
  static double _ema(List<double> p, int n) {
    if (p.isEmpty) return 0;
    final k   = 2 / (n + 1);
    double ema = p.first;
    for (final price in p) { ema = price * k + ema * (1 - k); }
    return ema;
  }
 
  static double _std(List<double> p, double mean) {
    if (p.length < 2) return 0;
    final v = p.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b);
    return math.sqrt(v / p.length);
  }
 
  static double _rsi(List<double> p, int n) {
    if (p.length < 2) return 50;
    double gains = 0, losses = 0;
    final count  = math.min(n, p.length - 1);
    for (var i = p.length - count; i < p.length; i++) {
      final diff = p[i] - p[i - 1];
      if (diff > 0) {
        gains  += diff;
      } else {
        losses -= diff;
      }
    }
    if (losses == 0) return 100;
    final rs = gains / losses;
    return 100 - (100 / (1 + rs));
  }
 
  static double _atr(List<double> p, int n) {
    if (p.length < 2) return 0;
    double sum = 0;
    final cnt  = math.min(n, p.length - 1);
    for (var i = p.length - cnt; i < p.length; i++) {
      sum += (p[i] - p[i - 1]).abs();
    }
    return sum / cnt;
  }
}
 
// ─────────────────────────────────────────────────────────────────
// XGBOOST-STYLE SIGNAL CLASSIFIER
// Multi-factor weighted scoring matching project spec
// Features: price momentum, RSI, MACD, BB position, volume, EMA cross
// ─────────────────────────────────────────────────────────────────
class XGBoostSignal {
  final String signal;      // BUY / SELL / HOLD
  final int    confidence;  // 50–95%
  final String risk;        // Low / Medium / High
  final String reason;      // Plain language
  final TechnicalIndicators indicators;
  final String expectedDirection;
  final String whatHappened;
  final String whatToWatch;
  final String actionHint;

  const XGBoostSignal({
    required this.signal,
    required this.confidence,
    required this.risk,
    required this.reason,
    required this.indicators,
    this.expectedDirection = 'Sideways',
    this.whatHappened = '',
    this.whatToWatch = '',
    this.actionHint = '',
  });

  // ── Main classifier — multi-factor scoring + context ─────
  factory XGBoostSignal.classify(
    StockQuote q, {
    PredictionContext? context,
  }) {
    context ??= PredictionContext.fromStore(q);
    // Push to price history
    PriceHistory.push(q.symbol, q.ltp, q.volume);
 
    final ind = TechnicalIndicators.compute(q.symbol, q);
    final pct = q.changePercent;
 
    // ── Feature scores (–100 to +100) ────────────────────
    double score = 0;
 
    // 1. Price momentum (weight: 25%)
    final momentumScore = (pct * 10).clamp(-25.0, 25.0);
    score += momentumScore;
 
    // 2. RSI signal (weight: 20%)
    double rsiScore = 0;
    if (ind.rsi < 30) {
      rsiScore = 15;   // oversold → buy
    } else if (ind.rsi < 45)  rsiScore = 8;
    else if (ind.rsi < 55)  rsiScore = 0;
    else if (ind.rsi < 70)  rsiScore = -5;
    else                     rsiScore = -15;  // overbought → sell
    score += rsiScore;
 
    // 3. EMA crossover (weight: 20%)
    double emaScore = 0;
    if (ind.ema9 > ind.ema21 && ind.ema21 > ind.sma50) {
      emaScore = 20;
    } else if (ind.ema9 > ind.ema21)                        emaScore = 10;
    else if (ind.ema9 < ind.ema21 && ind.ema21 < ind.sma50) emaScore = -20;
    else if (ind.ema9 < ind.ema21)                        emaScore = -10;
    score += emaScore;
 
    // 4. MACD (weight: 15%)
    final macdScore = (ind.macd > ind.macdSignal ? 1 : -1) *
        ((ind.macd - ind.macdSignal).abs().clamp(0, 15));
    score += macdScore;
 
    // 5. Bollinger Band position (weight: 10%)
    double bbScore = 0;
    if (ind.bbUpper > ind.bbLower) {
      final bbPos = (q.ltp - ind.bbLower) / (ind.bbUpper - ind.bbLower);
      if (bbPos < 0.2) {
        bbScore = 10;  // near lower band → buy
      } else if (bbPos > 0.8) bbScore = -10; // near upper band → sell
    }
    score += bbScore;
 
    // 6. Volume confirmation (weight: 10%)
    double volScore = 0;
    if (ind.currentVolume > ind.volumeAvg * 1.5) {
      // High volume confirms direction
      volScore = pct > 0 ? 8 : -8;
    } else if (ind.currentVolume < ind.volumeAvg * 0.5) {
      volScore = -3; // low volume = weak signal
    }
    score += volScore;
 
    // 7. Intraday range position (weight: 10%)
    final range = q.high - q.low;
    if (range > 0) {
      final pos = (q.ltp - q.low) / range;
      if (pos > 0.8) {
        score -= 5;  // near day high
      } else if (pos < 0.2)  score += 5;  // near day low
    }

    // 8. Sector strength (weight ~12%)
    score += context.sectorStrength * 12;

    // 9. Market trend — NIFTY (weight ~8%)
    score += context.marketTrend * 8;

    // 10. News sentiment (weight ~10%)
    score += context.newsSentiment * 10;

    // ── Convert score to signal ───────────────────────────
    String signal;
    int    conf;
    String risk;
 
    if (score >= 25) {
      signal = 'BUY';
      conf   = (60 + score.clamp(0, 35)).toInt();
      risk   = score >= 40 ? 'Medium' : 'Low';
    } else if (score <= -25) {
      signal = 'SELL';
      conf   = (60 + score.abs().clamp(0, 35)).toInt();
      risk   = score <= -40 ? 'High' : 'Medium';
    } else {
      signal = 'HOLD';
      conf   = (50 + (25 - score.abs())).clamp(50, 65).toInt();
      risk   = 'Low';
    }
 
    // Volatility penalty
    final volatility = range > 0 && q.close > 0 ? (range / q.close) * 100 : 0.0;
    if (volatility > 5) risk = 'High';

    // Confidence calibration
    if (ind.dataPoints < 9) {
      conf = (conf * 0.88).round();
    }
    final aligned = (signal == 'BUY' &&
            context.marketTrend > 0.15 &&
            context.sectorStrength > 0) ||
        (signal == 'SELL' &&
            context.marketTrend < -0.15 &&
            context.sectorStrength < 0);
    if (aligned) conf = (conf + 4).clamp(50, 95);
    if ((signal == 'BUY' && context.newsSentiment < -0.3) ||
        (signal == 'SELL' && context.newsSentiment > 0.3)) {
      conf = (conf - 5).clamp(50, 95);
    }
    conf = conf.clamp(50, 95);

    final expectedDirection = signal == 'BUY'
        ? 'Up'
        : signal == 'SELL'
            ? 'Down'
            : fcTrendFromScore(score);

    // ── Build reason ──────────────────────────────────────
    final reasons = <String>[];
 
    if (pct.abs() > 1.5) {
      reasons.add('${pct >= 0 ? '📈' : '📉'} Price ${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}% today');
    }
 
    if (ind.dataPoints >= 9) {
      if (ind.ema9 > ind.ema21) {
        reasons.add('EMA9 above EMA21 — bullish cross');
      } else {
        reasons.add('EMA9 below EMA21 — bearish cross');
      }
    }
 
    if (ind.rsi < 30) {
      reasons.add('RSI ${ind.rsi.toStringAsFixed(0)} — oversold, reversal possible');
    } else if (ind.rsi > 70) reasons.add('RSI ${ind.rsi.toStringAsFixed(0)} — overbought, caution');
    else reasons.add('RSI ${ind.rsi.toStringAsFixed(0)} — ${ind.rsiLabel}');
 
    if (ind.currentVolume > ind.volumeAvg * 1.4) {
      reasons.add('${_vol(q.volume)} volume confirms move');
    }
 
    if (ind.macd > ind.macdSignal) {
      reasons.add('MACD bullish');
    } else {
      reasons.add('MACD bearish');
    }

    if (context.sectorName != null && context.sectorStrength.abs() > 0.2) {
      reasons.add(
        '${context.sectorName} sector ${context.sectorStrength > 0 ? 'supporting' : 'dragging'}',
      );
    }
    if (context.newsSnapshot.articleCount > 0) {
      reasons.add(context.newsSnapshot.summary);
    }

    final reason = reasons.isEmpty
        ? 'Consolidating near ₹${q.ltp.toStringAsFixed(0)}'
        : reasons.join('. ');

    final whatHappened = q.changePercent.abs() > 0.05
        ? '${q.symbol} is ${q.changePercent >= 0 ? 'up' : 'down'} '
            '${q.changePctStr} today on ${ind.volumeLabel.toLowerCase()}.'
        : '${q.symbol} is largely flat today with limited price movement.';

    final whatToWatch = _whatToWatch(signal, ind, volatility);

    final actionHint = signal == 'BUY'
        ? 'Bias is bullish — consider entries on dips; respect ${risk.toLowerCase()} risk and use stops.'
        : signal == 'SELL'
            ? 'Bias is bearish — avoid fresh longs; tighten risk on existing positions.'
            : 'No strong edge — wait for clearer trend or volume confirmation.';

    return XGBoostSignal(
      signal: signal,
      confidence: conf,
      risk: risk,
      reason: reason,
      indicators: ind,
      expectedDirection: expectedDirection,
      whatHappened: whatHappened,
      whatToWatch: whatToWatch,
      actionHint: actionHint,
    );
  }

  static String fcTrendFromScore(double score) {
    if (score > 10) return 'Up';
    if (score < -10) return 'Down';
    return 'Sideways';
  }

  static String _whatToWatch(String signal, TechnicalIndicators ind, double vol) {
    final parts = <String>[];
    if (ind.rsi > 65) parts.add('RSI for overbought pullback');
    if (ind.rsi < 35) parts.add('RSI for oversold bounce');
    if (ind.ema9 > ind.ema21) {
      parts.add('EMA21 as support');
    } else {
      parts.add('EMA21 as resistance');
    }
    if (vol > 4) parts.add('intraday volatility spikes');
    if (signal == 'HOLD') parts.add('volume breakout for direction');
    return parts.take(3).join(', ');
  }
 
  static String _vol(int v) {
    if (v >= 10000000) return '${(v/10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000)   return '${(v/100000).toStringAsFixed(1)}L';
    if (v >= 1000)     return '${(v/1000).toStringAsFixed(1)}K';
    return '$v';
  }
}
 
// ─────────────────────────────────────────────────────────────────
// LSTM PRICE FORECASTER
// Simulates LSTM outputs: trend direction + 5/10/30 day estimates
// Based on EMA momentum + ATR volatility bands
// ─────────────────────────────────────────────────────────────────
class LstmForecast {
  final double price5d;
  final double price10d;
  final double price30d;
  final String trend;       // Uptrend / Downtrend / Sideways
  final double confidence;  // 0.0–1.0
  final double upperBand;   // confidence interval upper
  final double lowerBand;   // confidence interval lower
 
  const LstmForecast({
    required this.price5d,
    required this.price10d,
    required this.price30d,
    required this.trend,
    required this.confidence,
    required this.upperBand,
    required this.lowerBand,
  });
 
  factory LstmForecast.predict(StockQuote q, TechnicalIndicators ind) {
    final prices = PriceHistory.prices(q.symbol);
    final n      = prices.length;
    final ltp    = q.ltp;
 
    // Momentum from EMA difference
    final emaMomentum = n >= 9
        ? (ind.ema9 - ind.ema21) / ind.ema21 * 100
        : q.changePercent * 0.5;
 
    // ATR-based volatility for confidence intervals
    final atr    = ind.atr > 0 ? ind.atr : ltp * 0.01;
    final volMul = math.sqrt(ind.currentVolume / (ind.volumeAvg + 1));
 
    // Projected daily return (dampened momentum)
    final dailyReturn = (emaMomentum * 0.05 + q.changePercent * 0.03)
        .clamp(-2.0, 2.0); // max 2% per day
 
    // LSTM projections
    final p5d  = ltp * math.pow(1 + dailyReturn / 100, 5);
    final p10d = ltp * math.pow(1 + dailyReturn / 100, 10);
    final p30d = ltp * math.pow(1 + dailyReturn / 100 * 0.7, 30); // mean reversion
 
    // Confidence intervals (wider for volatile stocks)
    final conf   = (0.65 + (n / 100) * 0.15).clamp(0.55, 0.82);
    final band30 = atr * math.sqrt(30) * volMul;
 
    String trend;
    if (dailyReturn > 0.3) {
      trend = 'Uptrend';
    } else if (dailyReturn < -0.3) trend = 'Downtrend';
    else                         trend = 'Sideways';
 
    return LstmForecast(
      price5d:    p5d.toDouble(),
      price10d:   p10d.toDouble(),
      price30d:   p30d.toDouble(),
      trend:      trend,
      confidence: conf,
      upperBand:  (p30d + band30).toDouble(),
      lowerBand:  (p30d - band30).toDouble(),
    );
  }
 
  String get price5dStr  => '₹${price5d.toStringAsFixed(2)}';
  String get price10dStr => '₹${price10d.toStringAsFixed(2)}';
  String get price30dStr => '₹${price30d.toStringAsFixed(2)}';
  String get confStr     => '${(confidence * 100).toStringAsFixed(0)}%';
}
 
// ─────────────────────────────────────────────────────────────────
// FULL PREDICTION — combines XGBoost + LSTM
// Recomputes every time price updates
// ─────────────────────────────────────────────────────────────────
class StockPrediction {
  final XGBoostSignal signal;
  final LstmForecast  forecast;
  final DateTime      computedAt;
 
  const StockPrediction({
    required this.signal,
    required this.forecast,
    required this.computedAt,
  });
 
  // Main entry point — call this on every price tick
  factory StockPrediction.fromQuote(
    StockQuote q, {
    PredictionContext? context,
  }) {
    context ??= PredictionContext.fromStore(q);
    final xgb = XGBoostSignal.classify(q, context: context);
    final forecast = LstmForecast.predict(q, xgb.indicators);
    return StockPrediction(
      signal:     xgb,
      forecast:   forecast,
      computedAt: DateTime.now(),
    );
  }
 
  // Convenience getters
  String get signalStr     => signal.signal;
  int    get confidence    => signal.confidence;
  String get risk          => signal.risk;
  String get reason        => signal.reason;
  String get rsiLabel      => signal.indicators.rsiLabel;
  String get maLabel       => signal.indicators.maLabel;
  String get volumeLabel   => signal.indicators.volumeLabel;
  String get macdLabel     => signal.indicators.macdLabel;
  double get rsiValue      => signal.indicators.rsi;
  double get ema9          => signal.indicators.ema9;
  double get ema21         => signal.indicators.ema21;
  double get sma50         => signal.indicators.sma50;
  String get expectedDirection => signal.expectedDirection;
  String get whatHappened  => signal.whatHappened;
  String get whatToWatch   => signal.whatToWatch;
  String get actionHint    => signal.actionHint;
}
 
// ─────────────────────────────────────────────────────────────────
// SECTOR PREDICTION ENGINE
// Aggregates individual stock predictions into sector-level signal
// Per project spec: IT, Pharma, Agri, Banking, Energy, FMCG
// ─────────────────────────────────────────────────────────────────
class SectorPrediction {
  final String name;
  final String trend;         // Bullish / Bearish / Neutral
  final String signal;        // BUY / SELL / HOLD
  final int    confidence;
  final double avgChange;
  final double avgRsi;
  final String reason;        // Plain language sector analysis
  final List<StockPrediction> stockPredictions;
  final List<String> topStockSymbols;
  final List<String> weakStockSymbols;

  const SectorPrediction({
    required this.name,
    required this.trend,
    required this.signal,
    required this.confidence,
    required this.avgChange,
    required this.avgRsi,
    required this.reason,
    required this.stockPredictions,
    this.topStockSymbols = const [],
    this.weakStockSymbols = const [],
  });
 
  factory SectorPrediction.fromStocks(
    String sectorName,
    List<StockQuote> quotes,
  ) {
    if (quotes.isEmpty) {
      return SectorPrediction(
        name: sectorName,
        trend: 'Neutral',
        signal: 'HOLD',
        confidence: 50,
        avgChange: 0,
        avgRsi: 50,
        reason: 'No data',
        stockPredictions: [],
      );
    }
 
    // Compute predictions for each stock
    final preds = quotes.map((q) => StockPrediction.fromQuote(q)).toList();
 
    // Aggregate metrics
    final avgChg = quotes.map((q) => q.changePercent)
        .reduce((a, b) => a + b) / quotes.length;
    final avgRsi = preds.map((p) => p.rsiValue)
        .reduce((a, b) => a + b) / preds.length;
 
    // Count signals
    final buys  = preds.where((p) => p.signalStr == 'BUY').length;
    final sells = preds.where((p) => p.signalStr == 'SELL').length;
    final total = preds.length;
    final buyPct  = buys  / total;
    final sellPct = sells / total;
 
    // Sector-level signal
    String trend, signal;
    int conf;
 
    if (buyPct > 0.6 && avgChg > 0) {
      trend = 'Bullish'; signal = 'BUY';
      conf  = (65 + (buyPct * 25 + avgChg * 3).clamp(0, 30)).toInt();
    } else if (sellPct > 0.6 && avgChg < 0) {
      trend = 'Bearish'; signal = 'SELL';
      conf  = (65 + (sellPct * 25 + avgChg.abs() * 3).clamp(0, 30)).toInt();
    } else if (buyPct > 0.4 && avgChg > 0) {
      trend = 'Bullish'; signal = 'BUY';
      conf  = (55 + (buyPct * 15).clamp(0, 20)).toInt();
    } else if (sellPct > 0.4 && avgChg < 0) {
      trend = 'Bearish'; signal = 'SELL';
      conf  = (55 + (sellPct * 15).clamp(0, 20)).toInt();
    } else {
      trend = 'Neutral'; signal = 'HOLD';
      conf  = 55;
    }
 
    // Generate plain-language reason
    final topGainer = [...quotes]
        ..sort((a, b) => b.changePercent.compareTo(a.changePercent));
    final topLoser = [...quotes]
        ..sort((a, b) => a.changePercent.compareTo(b.changePercent));
 
    final reasons = <String>[];
    reasons.add('$buys/$total stocks showing BUY signal');
    if (topGainer.isNotEmpty && topGainer.first.changePercent > 0) {
      reasons.add('${topGainer.first.symbol} leading with +${topGainer.first.changePercent.toStringAsFixed(2)}%');
    }
    if (topLoser.isNotEmpty && topLoser.first.changePercent < -1) {
      reasons.add('${topLoser.first.symbol} dragging at ${topLoser.first.changePercent.toStringAsFixed(2)}%');
    }
    if (avgRsi < 35) {
      reasons.add('Sector RSI ${avgRsi.toStringAsFixed(0)} — oversold territory');
    } else if (avgRsi > 65) reasons.add('Sector RSI ${avgRsi.toStringAsFixed(0)} — overbought zone');
 
    final sorted = [...quotes]
      ..sort((a, b) => b.changePercent.compareTo(a.changePercent));
    final top = sorted.take(3).map((q) => q.symbol).toList();
    final weak = [...quotes]
      ..sort((a, b) => a.changePercent.compareTo(b.changePercent));
    final weakSyms = weak.take(3).map((q) => q.symbol).toList();

    if (top.isNotEmpty) {
      reasons.add('Leaders: ${top.join(', ')}');
    }
    if (weakSyms.isNotEmpty && weak.first.changePercent < 0) {
      reasons.add('Laggards: ${weakSyms.join(', ')}');
    }

    return SectorPrediction(
      name:             sectorName,
      trend:            trend,
      signal:           signal,
      confidence:       conf.clamp(50, 95),
      avgChange:        avgChg,
      avgRsi:           avgRsi,
      reason:           reasons.join('. '),
      stockPredictions: preds,
      topStockSymbols:  top,
      weakStockSymbols: weakSyms,
    );
  }

  bool   get isPositive   => avgChange >= 0;
  String get avgChangeStr => '${avgChange >= 0 ? '+' : ''}${avgChange.toStringAsFixed(2)}%';

  List<StockQuote> topStocks(List<StockQuote> quotes) {
    final set = topStockSymbols.toSet();
    return quotes.where((q) => set.contains(q.symbol)).toList();
  }

  List<StockQuote> weakStocks(List<StockQuote> quotes) {
    final set = weakStockSymbols.toSet();
    return quotes.where((q) => set.contains(q.symbol)).toList();
  }
}