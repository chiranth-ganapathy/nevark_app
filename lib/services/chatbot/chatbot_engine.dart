import 'package:shared_preferences/shared_preferences.dart';

import '../api_service.dart';
import '../intelligence/intelligence_engine.dart';
import '../market_store.dart';
import '../prediction_service.dart';
import 'chatbot_news_helper.dart';
import 'chatbot_parser.dart';

/// Conversation memory for follow-up queries.
class ChatSession {
  String? lastSymbol;
  String? lastSector;
  ChatIntent? lastIntent;

  void update(ParsedQuery parsed) {
    lastIntent = parsed.intent;
    if (parsed.symbols.isNotEmpty) lastSymbol = parsed.symbols.first;
    if (parsed.sector != null) lastSector = parsed.sector;
  }

  void clear() {
    lastSymbol = null;
    lastSector = null;
    lastIntent = null;
  }
}

/// Builds research-grade replies from [MarketStore] + prediction engine.
class ChatbotEngine {
  static Future<String> respond(String query, ChatSession session) async {
    final parsed = ChatbotParser.parse(
      query,
      contextSymbol: session.lastSymbol,
      contextSector: session.lastSector,
    );
    session.update(parsed);

    switch (parsed.intent) {
      case ChatIntent.offTopic:
        return _offTopicReply();
      case ChatIntent.marketOverview:
        return _marketOverview();
      case ChatIntent.stockAnalysis:
      case ChatIntent.prediction:
        return await _stockAnalysis(parsed.symbols.first);
      case ChatIntent.sectorAnalysis:
        return _sectorAnalysis(parsed.sector!);
      case ChatIntent.indexAnalysis:
        return _indexAnalysis(parsed.indexKey!);
      case ChatIntent.compare:
        if (parsed.symbols.length < 2) {
          return 'Please name two stocks to compare.\n'
              'Example: "Compare HDFC Bank and ICICI Bank"';
        }
        return _compare(parsed.symbols[0], parsed.symbols[1]);
      case ChatIntent.technical:
        return _technical(
          parsed.symbols.first,
          parsed.indicator ?? 'all',
        );
      case ChatIntent.news:
        return _newsReply(parsed);
      case ChatIntent.bestInSector:
        return _bestInSector(parsed.sector!);
      case ChatIntent.watchlist:
        return _watchlistReply();
      case ChatIntent.portfolio:
        return _watchlistReply(label: 'Portfolio');
    }
  }

  static String _offTopicReply() => '🚫 I\'m NeVark\'s stock research assistant — '
      'I only cover Indian markets, stocks, sectors, indices, '
      'technical analysis, predictions, and news.\n\n'
      'Try:\n'
      '• "TCS"\n'
      '• "Should I buy Reliance?"\n'
      '• "How is IT sector?"\n'
      '• "Compare HDFC Bank and ICICI Bank"\n'
      '• "RSI for Infosys"\n'
      '• "NIFTY outlook"';

  static String _dataUnavailable(String what) {
    final err = MarketStore.instance.lastError;
    final status = MarketStore.instance.marketStatus;
    return '⚠ Live data for $what is not available yet.\n\n'
        'Market: ${status.message}\n'
        '${err != null && err.isNotEmpty ? "Feed: $err\n\n" : ""}'
        'Open the app during NSE hours (9:15 AM – 3:30 PM IST) on Android '
        'for live Angel One quotes, or wait for cached data to load.\n\n'
        '$kSebiDisclaimer';
  }

  static Future<String> _stockAnalysis(String symbol) async {
    final sym = symbol.toUpperCase();
    final intel = IntelligenceEngine.stock(sym);
    if (intel == null) return _dataUnavailable(sym);

    final buf = StringBuffer('📈 ${IntelligenceEngine.formatStockBrief(intel)}\n\n');
    buf.writeln('Technical (plain English)');
    buf.writeln('• ${intel.narratives.rsi}');
    buf.writeln('• ${intel.narratives.ema}');
    buf.writeln('• ${intel.narratives.macd}');
    buf.writeln('• ${intel.narratives.bollinger}');
    buf.writeln('• ${intel.narratives.volume}');

    return _appendNewsAndDisclaimer(buf, sym);
  }

  static Future<String> _appendNewsAndDisclaimer(
    StringBuffer buf,
    String symbol,
  ) async {
    final news = await ChatbotNewsHelper.sentimentBlurbForSymbol(symbol);
    if (news != null) {
      buf.writeln('');
      buf.writeln('News Sentiment');
      buf.writeln(news);
    }
    buf.writeln('');
    buf.writeln(kSebiDisclaimer);
    return buf.toString();
  }

  static String _sectorAnalysis(String sector) {
    final intel = IntelligenceEngine.sector(sector);
    if (intel == null || intel.topStocks.isEmpty && intel.prediction.stockPredictions.isEmpty) {
      return _dataUnavailable('$sector sector');
    }

    final p = intel.prediction;
    final buf = StringBuffer();
    buf.writeln('📊 $sector Sector');
    buf.writeln('');
    buf.writeln('Trend: ${p.trend}');
    buf.writeln('Signal: ${p.signal} · ${p.confidence}% confidence');
    buf.writeln('Avg move: ${p.avgChangeStr}');
    buf.writeln('');
    buf.writeln('What happened?');
    buf.writeln(intel.whatHappened);
    buf.writeln('');
    buf.writeln('Why?');
    buf.writeln(p.reason);
    buf.writeln('');
    buf.writeln('Action');
    buf.writeln(intel.actionHint);
    if (intel.topStocks.isNotEmpty) {
      buf.writeln('');
      buf.writeln('Top stocks');
      for (final q in intel.topStocks) {
        final sp = StockPrediction.fromQuote(q);
        buf.writeln('  ${q.symbol} ${q.changePctStr} · ${sp.signalStr}');
      }
    }
    if (intel.weakStocks.isNotEmpty) {
      buf.writeln('');
      buf.writeln('Weak stocks');
      for (final q in intel.weakStocks) {
        final sp = StockPrediction.fromQuote(q);
        buf.writeln('  ${q.symbol} ${q.changePctStr} · ${sp.signalStr}');
      }
    }
    if (intel.newsSentiment.articleCount > 0) {
      buf.writeln('');
      buf.writeln('News: ${intel.newsSentiment.summary}');
    }
    return '${buf.toString()}\n$kSebiDisclaimer';
  }

  static String _indexAnalysis(String index) {
    if (index == 'SENSEX') {
      return '📊 SENSEX\n\n'
          'SENSEX is not in the current Angel One token list.\n'
          'Use NIFTY 50, BANK NIFTY, or FIN NIFTY for live index data.\n\n'
          '${_marketOverview()}';
    }

    final q = MarketStore.instance.quote(index);
    if (q == null || q.ltp <= 0) {
      return _dataUnavailable(index);
    }

    final pred = StockPrediction.fromQuote(q);
    final ind = pred.signal.indicators;
    final status = MarketStore.instance.marketStatus;

    final buf = StringBuffer();
    buf.writeln('📊 $index');
    buf.writeln('');
    buf.writeln('Session: ${status.message}');
    buf.writeln('Value: ${q.priceStr}');
    buf.writeln('Change: ${q.changePctStr}');
    buf.writeln('High / Low: ₹${q.high.toStringAsFixed(2)} / ₹${q.low.toStringAsFixed(2)}');
    buf.writeln('');
    buf.writeln('Outlook Signal: ${pred.signalStr} (${pred.confidence}%)');
    buf.writeln('Trend: ${pred.forecast.trend}');
    buf.writeln('Risk: ${pred.risk}');
    buf.writeln('');
    buf.writeln('Technical');
    buf.writeln('• RSI ${ind.rsi.toStringAsFixed(0)} — ${_plainRsi(ind.rsi)}');
    buf.writeln('• ${pred.macdLabel}');
    buf.writeln('• ${pred.maLabel}');
    buf.writeln('');
    buf.writeln('Analysis');
    buf.writeln(pred.reason);
    buf.writeln('');
    buf.writeln(kSebiDisclaimer);
    return buf.toString();
  }

  static String _marketOverview() {
    final idx = MarketStore.instance.indices;
    final status = MarketStore.instance.marketStatus;
    final updated = MarketStore.instance.lastUpdated;

    if (idx.isEmpty && !MarketStore.instance.hasData) {
      return _dataUnavailable('market');
    }

    final buf = StringBuffer('🏦 Indian Market Overview\n\n');
    buf.writeln('Status: ${status.message}');
    if (updated != null) {
      buf.writeln(
        'Data as of: ${updated.hour.toString().padLeft(2, '0')}:'
        '${updated.minute.toString().padLeft(2, '0')} local',
      );
    }
    buf.writeln('');

    for (final key in ['NIFTY', 'BANKNIFTY', 'FINNIFTY']) {
      final q = idx[key];
      if (q != null) {
        final p = StockPrediction.fromQuote(q);
        buf.writeln(
          '${key.padRight(12)} ${q.priceStr.padLeft(14)} ${q.changePctStr.padLeft(8)}  ${p.signalStr}',
        );
      }
    }

    final insights = IntelligenceEngine.marketInsights();
    buf.writeln('');
    buf.writeln('Market sentiment: ${insights.marketSentiment} (${insights.sentimentScore})');
    buf.writeln(insights.summary);
    if (insights.topGainers.isNotEmpty) {
      buf.writeln('');
      buf.writeln('Top gainer: ${insights.topGainers.first.symbol} ${insights.topGainers.first.changePctStr}');
    }
    if (insights.topLosers.isNotEmpty) {
      buf.writeln('Top loser: ${insights.topLosers.first.symbol} ${insights.topLosers.first.changePctStr}');
    }
    buf.writeln('Strongest sector: ${insights.strongestSector}');
    buf.writeln('Weakest sector: ${insights.weakestSector}');
    if (insights.mostBullishStock != null) {
      buf.writeln('Most bullish: ${insights.mostBullishStock}');
    }
    if (insights.mostBearishStock != null) {
      buf.writeln('Most bearish: ${insights.mostBearishStock}');
    }

    buf.writeln('');
    buf.writeln('Ask me any stock (e.g. "TCS"), sector, or comparison.');
    buf.writeln('');
    buf.writeln(kSebiDisclaimer);
    return buf.toString();
  }

  static String _compare(String a, String b) {
    final qa = MarketStore.instance.quote(a);
    final qb = MarketStore.instance.quote(b);
    if (qa == null ||
        qb == null ||
        qa.ltp <= 0 ||
        qb.ltp <= 0) {
      return _dataUnavailable('$a vs $b');
    }

    final pa = StockPrediction.fromQuote(qa);
    final pb = StockPrediction.fromQuote(qb);

    String winner;
    if (pa.signalStr == 'BUY' && pb.signalStr != 'BUY') {
      winner = a;
    } else if (pb.signalStr == 'BUY' && pa.signalStr != 'BUY') {
      winner = b;
    } else if (qa.changePercent != qb.changePercent) {
      winner = qa.changePercent >= qb.changePercent ? a : b;
    } else {
      winner = pa.confidence >= pb.confidence ? a : b;
    }

    return '📊 Compare $a vs $b\n\n'
        '$a\n'
        '  Price: ${qa.priceStr} (${qa.changePctStr})\n'
        '  Signal: ${pa.signalStr} · ${pa.confidence}% confidence\n'
        '  Risk: ${pa.risk} · RSI ${pa.rsiValue.toStringAsFixed(0)}\n'
        '  Trend: ${pa.forecast.trend}\n\n'
        '$b\n'
        '  Price: ${qb.priceStr} (${qb.changePctStr})\n'
        '  Signal: ${pb.signalStr} · ${pb.confidence}% confidence\n'
        '  Risk: ${pb.risk} · RSI ${pb.rsiValue.toStringAsFixed(0)}\n'
        '  Trend: ${pb.forecast.trend}\n\n'
        'Relative Strength Today: '
        '${qa.changePercent >= qb.changePercent ? a : b} '
        '(${qa.changePercent >= qb.changePercent ? qa.changePctStr : qb.changePctStr})\n'
        'AI Preference (signals): $winner\n\n'
        'Summary\n'
        '• $a: ${pa.reason.split('. ').first}\n'
        '• $b: ${pb.reason.split('. ').first}\n\n'
        '$kSebiDisclaimer';
  }

  static String _technical(String symbol, String indicator) {
    final intel = IntelligenceEngine.stock(symbol);
    if (intel == null) return _dataUnavailable('$symbol technicals');

    final quote = intel.quote;
    final pred = intel.prediction;
    final ind = pred.signal.indicators;
    final n = intel.narratives;

    final buf = StringBuffer();
    buf.writeln('🔬 Technical Analysis — $symbol');
    buf.writeln('Price: ${quote.priceStr} (${quote.changePctStr})');
    buf.writeln('');

    void block(String title, String body) {
      buf.writeln(title);
      buf.writeln(body);
      buf.writeln('');
    }

    switch (indicator) {
      case 'rsi':
        block('RSI (${ind.rsi.toStringAsFixed(1)})', n.rsi);
        break;
      case 'macd':
        block('MACD', n.macd);
        break;
      case 'ema':
        block('EMA / SMA', '${n.ema} SMA50 ₹${ind.sma50.toStringAsFixed(2)}.');
        break;
      case 'bollinger':
        block('Bollinger Bands', n.bollinger);
        break;
      case 'atr':
        block('ATR (volatility)', n.atr);
        break;
      case 'volume':
        block('Volume', n.volume);
        break;
      default:
        block('RSI', n.rsi);
        block('EMA', n.ema);
        block('MACD', n.macd);
        block('Bollinger', n.bollinger);
        block('Volume', n.volume);
        block('Volatility', n.volatility);
    }

    buf.writeln('Overall Signal: ${pred.signalStr} (${pred.confidence}%)');
    buf.writeln('');
    buf.writeln(kSebiDisclaimer);
    return buf.toString();
  }

  static Future<String> _newsReply(ParsedQuery parsed) async {
    if (parsed.symbols.isNotEmpty) {
      final sym = parsed.symbols.first;
      final news = await ChatbotNewsHelper.sentimentBlurbForSymbol(sym);
      if (news != null) {
        return '📰 News — $sym\n\n$news\n\n'
            'Open the News tab for full articles.\n\n$kSebiDisclaimer';
      }
      return '📰 No cached news found for $sym.\n'
          'Pull to refresh on the News screen first.\n\n$kSebiDisclaimer';
    }
    if (parsed.sector != null) {
      final blurb = await ChatbotNewsHelper.sectorNewsBlurb(parsed.sector!);
      if (blurb != null) {
        return '📰 $blurb\n\n$kSebiDisclaimer';
      }
    }
    return '📰 Open the News tab and refresh to load headlines.\n'
        'I use cached Yahoo Finance articles for sentiment.\n\n$kSebiDisclaimer';
  }

  static String _bestInSector(String sector) {
    final sd = MarketStore.instance.sectorData(sector);
    if (sd.stocks.isEmpty) return _dataUnavailable('$sector picks');

    final ranked = [...sd.stocks]
      ..sort((a, b) {
        final pa = StockPrediction.fromQuote(a);
        final pb = StockPrediction.fromQuote(b);
        final scoreA = _rankScore(pa, a.changePercent);
        final scoreB = _rankScore(pb, b.changePercent);
        return scoreB.compareTo(scoreA);
      });

    final top = ranked.take(3).toList();
    final buf = StringBuffer('🏆 Best $sector stocks today (AI rank)\n\n');

    for (var i = 0; i < top.length; i++) {
      final q = top[i];
      final p = StockPrediction.fromQuote(q);
      buf.writeln('${i + 1}. ${q.symbol}');
      buf.writeln('   ${q.priceStr} · ${q.changePctStr}');
      buf.writeln('   Signal ${p.signalStr} · ${p.confidence}% · Risk ${p.risk}');
      buf.writeln('   ${p.reason.split('. ').first}');
      buf.writeln('');
    }

    buf.writeln(kSebiDisclaimer);
    return buf.toString();
  }

  static double _rankScore(StockPrediction p, double chg) {
    var s = p.confidence.toDouble();
    if (p.signalStr == 'BUY') s += 15;
    if (p.signalStr == 'SELL') s -= 10;
    s += chg.clamp(-3, 3) * 2;
    return s;
  }

  static Future<String> _watchlistReply({String label = 'Watchlist'}) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('watchlist') ?? [];
    if (list.isEmpty) {
      return '📋 Your $label is empty.\n'
          'Add symbols from the Watchlist tab.\n\n$kSebiDisclaimer';
    }

    final buf = StringBuffer('📋 $label (${list.length} stocks)\n\n');
    for (final sym in list.take(12)) {
      final q = MarketStore.instance.quote(sym.toUpperCase());
      if (q == null || q.ltp <= 0) {
        buf.writeln('  $sym — no live quote');
        continue;
      }
      final p = StockPrediction.fromQuote(q);
      buf.writeln(
        '  ${sym.toUpperCase().padRight(10)} ${q.priceStr.padLeft(12)} ${q.changePctStr.padLeft(8)}  ${p.signalStr}',
      );
    }
    buf.writeln('\n$kSebiDisclaimer');
    return buf.toString();
  }

  static String _plainRsi(double rsi) {
    if (rsi >= 70) {
      return 'Overbought — price has risen fast; watch for pullback or wait for confirmation before buying.';
    }
    if (rsi >= 55) {
      return 'Bullish momentum — buyers in control, but not extreme yet.';
    }
    if (rsi >= 45) return 'Neutral — no strong overbought/oversold pressure.';
    if (rsi >= 30) {
      return 'Weak — selling pressure, but not deeply oversold.';
    }
    return 'Oversold — heavy selling; bounce possible, but trend may still be down.';
  }

  static String _plainBollinger(double ltp, TechnicalIndicators ind) {
    if (ind.bbUpper <= ind.bbLower) return 'Not enough data for band position.';
    final pos = (ltp - ind.bbLower) / (ind.bbUpper - ind.bbLower);
    if (pos < 0.2) {
      return 'Price near lower band — often seen as relatively cheap vs recent range.';
    }
    if (pos > 0.8) {
      return 'Price near upper band — extended vs recent range; caution on fresh longs.';
    }
    return 'Price mid-band — trading inside normal range.';
  }

  static String _plainVolatility(double pct) {
    if (pct > 4) return 'High intraday volatility — wider stops advised.';
    if (pct > 2) return 'Moderate volatility — normal for active names.';
    return 'Low volatility — quieter session.';
  }

  static String _formatVolume(int v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(2)} Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(2)} L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)} K';
    return '$v';
  }
}
