import '../../core/models/stock_quote.dart';
import '../prediction_service.dart';

/// Plain-English explanations for technical indicators (beginner mode).
class IndicatorExplainer {
  static String explainRsi(double rsi) {
    if (rsi >= 75) {
      return 'Momentum is very strong but the stock is in overbought territory — '
          'a pullback is possible before further upside.';
    }
    if (rsi >= 68) {
      return 'Momentum is strong but approaching overbought territory.';
    }
    if (rsi >= 55) {
      return 'Buying pressure is healthy — momentum favours the current direction.';
    }
    if (rsi >= 45) {
      return 'Momentum is balanced — neither overbought nor oversold.';
    }
    if (rsi >= 30) {
      return 'Momentum is weak — sellers have more control than buyers right now.';
    }
    return 'The stock is oversold — selling may be exhausted and a bounce is possible, '
        'but confirm with volume and trend before acting.';
  }

  static String explainEmaTrend(String maLabel, double ema9, double ema21) {
    switch (maLabel) {
      case 'Strong Uptrend':
        return 'Short-term averages are stacked above long-term — '
            'a classic bullish structure (EMA9 ₹${ema9.toStringAsFixed(0)} > EMA21 ₹${ema21.toStringAsFixed(0)}).';
      case 'Above EMA':
        return 'Price is trading above its short-term average — buyers are in control intraday.';
      case 'Strong Downtrend':
        return 'Averages are stacked bearishly — trend favours lower prices until structure improves.';
      case 'Below EMA':
        return 'Price is below its short-term average — sellers are dominating the session.';
      default:
        return 'Moving averages are flat — trend is unclear; wait for a clearer crossover.';
    }
  }

  static String explainMacd(String macdLabel, double macd, double signal) {
    switch (macdLabel) {
      case 'Strong Bullish':
        return 'MACD is well above its signal line — bullish momentum is accelerating.';
      case 'Bullish Cross':
        return 'MACD has crossed above its signal line — early bullish momentum shift.';
      case 'Strong Bearish':
        return 'MACD is well below its signal line — bearish pressure is building.';
      case 'Bearish Cross':
        return 'MACD crossed below its signal line — momentum is turning negative.';
      default:
        return 'MACD and signal are close (Δ ${(macd - signal).toStringAsFixed(2)}) — no strong directional bias.';
    }
  }

  static String explainBollinger(double ltp, TechnicalIndicators ind) {
    if (ind.bbUpper <= ind.bbLower) {
      return 'Not enough history to position price within Bollinger Bands.';
    }
    final pos = (ltp - ind.bbLower) / (ind.bbUpper - ind.bbLower);
    if (pos < 0.2) {
      return 'Price is near the lower Bollinger Band — relatively cheap vs recent range; '
          'mean-reversion bounce possible.';
    }
    if (pos > 0.8) {
      return 'Price is near the upper Bollinger Band — extended vs recent range; '
          'fresh longs carry higher risk.';
    }
    return 'Price is mid-band — trading inside a normal volatility range.';
  }

  static String explainAtr(double atr, double volatilityPct) {
    if (volatilityPct > 4) {
      return 'ATR ₹${atr.toStringAsFixed(2)} — high intraday volatility; use wider stops.';
    }
    if (volatilityPct > 2) {
      return 'ATR ₹${atr.toStringAsFixed(2)} — moderate volatility; normal for active NSE names.';
    }
    return 'ATR ₹${atr.toStringAsFixed(2)} — low volatility session; moves may be limited.';
  }

  static String explainVolume(String volumeLabel) {
    switch (volumeLabel) {
      case 'Very High Volume':
        return 'Volume is very high — the current move has strong participation and is more reliable.';
      case 'High Volume':
        return 'Volume is above average — the price move is being confirmed by traders.';
      case 'Low Volume':
        return 'Volume is low — the move lacks conviction; signals are less reliable.';
      case 'Very Low Volume':
        return 'Very thin volume — avoid aggressive positions until participation returns.';
      default:
        return 'Volume is near average — no unusual participation today.';
    }
  }

  static String explainVolatility(double volatilityPct) {
    if (volatilityPct > 5) {
      return 'Volatility is high (${volatilityPct.toStringAsFixed(1)}% of price) — expect larger swings; size positions smaller.';
    }
    if (volatilityPct > 2.5) {
      return 'Volatility is moderate (${volatilityPct.toStringAsFixed(1)}%) — normal intraday risk.';
    }
    return 'Volatility is low (${volatilityPct.toStringAsFixed(1)}%) — price action is relatively calm.';
  }

  static double volatilityPercent(StockQuote q) {
    final range = q.high - q.low;
    if (range <= 0 || q.close <= 0) return 0;
    return (range / q.close) * 100;
  }
}
