import '../api_service.dart';

enum ChatIntent {
  offTopic,
  marketOverview,
  stockAnalysis,
  sectorAnalysis,
  indexAnalysis,
  compare,
  technical,
  prediction,
  news,
  bestInSector,
  watchlist,
  portfolio,
}

class ParsedQuery {
  final ChatIntent intent;
  final List<String> symbols;
  final String? sector;
  final String? indexKey;
  final String? indicator;
  final String raw;

  const ParsedQuery({
    required this.intent,
    this.symbols = const [],
    this.sector,
    this.indexKey,
    this.indicator,
    required this.raw,
  });
}

/// Resolves symbols, sectors, indices, and intent from natural language.
class ChatbotParser {
  static const _offTopic = [
    'joke',
    'jokes',
    'weather',
    'cricket',
    'football',
    'movie',
    'song',
    'recipe',
    'who is pm',
    'prime minister',
    'election',
    'politics',
    'political',
    'bitcoin',
    'crypto',
    'dating',
    'hello',
    'hi there',
    'how are you',
    'tell me about yourself',
    'chatgpt',
    'write a poem',
    'story about',
  ];

  static const _companyAliases = {
    'hdfc bank': 'HDFCBANK',
    'hdfc': 'HDFCBANK',
    'icici bank': 'ICICIBANK',
    'icici': 'ICICIBANK',
    'sbi': 'SBIN',
    'state bank': 'SBIN',
    'reliance': 'RELIANCE',
    'reliance industries': 'RELIANCE',
    'infosys': 'INFY',
    'infy': 'INFY',
    'tcs': 'TCS',
    'tata consultancy': 'TCS',
    'wipro': 'WIPRO',
    'hcl tech': 'HCLTECH',
    'hcltech': 'HCLTECH',
    'tech mahindra': 'TECHM',
    'ltimindtree': 'LTIM',
    'maruti': 'MARUTI',
    'tata motors': 'TATAMOT',
    'tatamotors': 'TATAMOT',
    'bajaj auto': 'BAJAJ-AUTO',
    'hero motocorp': 'HEROMOTOCO',
    'sun pharma': 'SUNPHARMA',
    'dr reddy': 'DRREDDY',
    'bharti': 'BHARTIARTL',
    'airtel': 'BHARTIARTL',
    'itc': 'ITC',
    'hul': 'HINDUNILVR',
    'hindustan unilever': 'HINDUNILVR',
    'asian paints': 'ASIANPAINT',
    'kotak': 'KOTAKBANK',
    'axis bank': 'AXISBANK',
    'bajaj finance': 'BAJFINANCE',
    'tata steel': 'TATASTEEL',
    'jsw steel': 'JSWSTEEL',
    'coal india': 'COALINDIA',
    'dlf': 'DLF',
  };

  static const _sectorAliases = {
    'it sector': 'IT',
    'information technology': 'IT',
    'tech sector': 'IT',
    'banking sector': 'Banking',
    'banks': 'Banking',
    'bank sector': 'Banking',
    'pharma sector': 'Pharma',
    'pharmaceutical': 'Pharma',
    'energy sector': 'Energy',
    'oil and gas': 'Energy',
    'fmcg sector': 'FMCG',
    'consumer goods': 'FMCG',
    'auto sector': 'Auto',
    'automobile': 'Auto',
    'metal sector': 'Metal',
    'metals': 'Metal',
    'telecom sector': 'Telecom',
    'real estate sector': 'Real Estate',
    'realty': 'Real Estate',
    'agriculture sector': 'Agriculture',
    'agri': 'Agriculture',
  };

  static ParsedQuery parse(
    String query, {
    String? contextSymbol,
    String? contextSector,
  }) {
    final raw = query.trim();
    final q = raw.toLowerCase();

    if (_isOffTopic(q)) {
      return ParsedQuery(intent: ChatIntent.offTopic, raw: raw);
    }

    final symbols = extractSymbols(q);
    final sector = resolveSector(q) ?? contextSector;
    final index = resolveIndex(q);
    final indicator = _resolveIndicator(q);

    // Follow-up: "what about rsi?" / "its rsi"
    if (indicator != null &&
        symbols.isEmpty &&
        contextSymbol != null &&
        _isFollowUpTechnical(q)) {
      return ParsedQuery(
        intent: ChatIntent.technical,
        symbols: [contextSymbol],
        indicator: indicator,
        raw: raw,
      );
    }

    // Follow-up: "compare with infy" / "vs infosys"
    if (contextSymbol != null &&
        symbols.length == 1 &&
        symbols.first != contextSymbol &&
        _mentionsCompare(q)) {
      return ParsedQuery(
        intent: ChatIntent.compare,
        symbols: [contextSymbol, symbols.first],
        raw: raw,
      );
    }

    if (_mentionsCompare(q) || q.contains(' vs ') || q.contains(' versus ')) {
      final syms = symbols.length >= 2
          ? symbols.take(2).toList()
          : symbols;
      if (syms.length >= 2) {
        return ParsedQuery(
          intent: ChatIntent.compare,
          symbols: syms,
          raw: raw,
        );
      }
    }

    if (q.contains('watchlist') || q.contains('my stocks')) {
      return ParsedQuery(intent: ChatIntent.watchlist, raw: raw);
    }

    if (q.contains('portfolio') || q.contains('holdings')) {
      return ParsedQuery(intent: ChatIntent.portfolio, raw: raw);
    }

    if (_isNewsQuery(q)) {
      return ParsedQuery(
        intent: ChatIntent.news,
        symbols: symbols,
        sector: sector,
        raw: raw,
      );
    }

    if (_isBestStockQuery(q) && sector != null) {
      return ParsedQuery(
        intent: ChatIntent.bestInSector,
        sector: sector,
        raw: raw,
      );
    }

    if (indicator != null && symbols.isNotEmpty) {
      return ParsedQuery(
        intent: ChatIntent.technical,
        symbols: symbols,
        indicator: indicator,
        raw: raw,
      );
    }

    if (_isBuySellQuery(q) && symbols.isNotEmpty) {
      return ParsedQuery(
        intent: ChatIntent.prediction,
        symbols: symbols,
        raw: raw,
      );
    }

    if (index != null &&
        (q.contains('outlook') ||
            q.contains('analysis') ||
            q.contains('nifty') ||
            q.contains('index') ||
            symbols.isEmpty)) {
      return ParsedQuery(
        intent: ChatIntent.indexAnalysis,
        indexKey: index,
        raw: raw,
      );
    }

    if (sector != null &&
        (q.contains('sector') ||
            q.contains('how is') ||
            q.contains('how\'s') ||
            q.contains('trend') ||
            symbols.isEmpty)) {
      return ParsedQuery(
        intent: ChatIntent.sectorAnalysis,
        sector: sector,
        raw: raw,
      );
    }

    if (symbols.length == 1 &&
        (q.length <= 12 ||
            _isStockQuery(q) ||
            !q.contains('sector') &&
                !q.contains('market'))) {
      return ParsedQuery(
        intent: ChatIntent.stockAnalysis,
        symbols: symbols,
        raw: raw,
      );
    }

    if (symbols.isNotEmpty) {
      return ParsedQuery(
        intent: ChatIntent.stockAnalysis,
        symbols: symbols,
        raw: raw,
      );
    }

    if (sector != null) {
      return ParsedQuery(
        intent: ChatIntent.sectorAnalysis,
        sector: sector,
        raw: raw,
      );
    }

    if (index != null) {
      return ParsedQuery(
        intent: ChatIntent.indexAnalysis,
        indexKey: index,
        raw: raw,
      );
    }

    if (_isMarketQuery(q)) {
      return ParsedQuery(intent: ChatIntent.marketOverview, raw: raw);
    }

    if (!_isFinanceDomain(q)) {
      return ParsedQuery(intent: ChatIntent.offTopic, raw: raw);
    }

    return ParsedQuery(intent: ChatIntent.marketOverview, raw: raw);
  }

  static List<String> extractSymbols(String q) {
    final found = <String>[];

    for (final entry in _companyAliases.entries) {
      if (_wordMatch(q, entry.key) && !found.contains(entry.value)) {
        found.add(entry.value);
      }
    }

    for (final sym in kNseTokens.keys) {
      if (kAllIndexKeys.contains(sym)) continue;
      if (_wordMatch(q, sym.toLowerCase()) && !found.contains(sym)) {
        found.add(sym);
      }
    }

    return found;
  }

  static String? resolveSector(String q) {
    for (final entry in _sectorAliases.entries) {
      if (q.contains(entry.key)) return entry.value;
    }
    if (RegExp(r'\bit\b').hasMatch(q) &&
        (q.contains('sector') || q.contains('how is') || q.contains('outlook'))) {
      return 'IT';
    }
    if (q.contains('banking') || q.contains('bank sector') || q.contains('banks today')) {
      return 'Banking';
    }
    if (q.contains('pharma')) return 'Pharma';
    if (q.contains('energy') || q.contains(' oil ')) return 'Energy';
    if (q.contains('fmcg')) return 'FMCG';
    if (q.contains('agriculture') || q.contains('agri ')) return 'Agriculture';
    if (q.contains('auto')) return 'Auto';
    if (q.contains('metal')) return 'Metal';
    if (q.contains('telecom')) return 'Telecom';
    if (q.contains('real estate') || q.contains('realty')) return 'Real Estate';
    return null;
  }

  static String? resolveIndex(String q) {
    if (q.contains('sensex')) return 'SENSEX';
    if (q.contains('nifty next 50') || q.contains('nifty next')) return 'NIFTY_NEXT_50';
    if (q.contains('nifty midcap') || q.contains('midcap')) return 'NIFTY_MIDCAP';
    if (q.contains('nifty smallcap') || q.contains('smallcap')) return 'NIFTY_SMALLCAP';
    if (q.contains('nifty it')) return 'NIFTY_IT';
    if (q.contains('nifty pharma')) return 'NIFTY_PHARMA';
    if (q.contains('nifty auto')) return 'NIFTY_AUTO';
    if (q.contains('nifty fmcg')) return 'NIFTY_FMCG';
    if (q.contains('banknifty') || q.contains('bank nifty') || q.contains('nifty bank')) return 'BANKNIFTY';
    if (q.contains('finnifty') || q.contains('fin nifty')) return 'FINNIFTY';
    if (q.contains('nifty 50') || q.contains('nifty')) return 'NIFTY';
    return null;
  }

  static bool _isOffTopic(String q) {
    return _offTopic.any((t) => q.contains(t));
  }

  static bool _isFinanceDomain(String q) {
    const kw = [
      'stock',
      'share',
      'nse',
      'bse',
      'market',
      'nifty',
      'sensex',
      'buy',
      'sell',
      'hold',
      'rsi',
      'macd',
      'ema',
      'sma',
      'bollinger',
      'atr',
      'volume',
      'volatility',
      'sector',
      'index',
      'trading',
      'invest',
      'portfolio',
      'watchlist',
      'outlook',
      'analysis',
      'signal',
      'prediction',
      'bullish',
      'bearish',
      'trend',
      'compare',
      'news',
      'banking',
      'pharma',
      'energy',
    ];
    if (kw.any((k) => q.contains(k))) return true;
    if (extractSymbols(q).isNotEmpty) return true;
    if (resolveSector(q) != null) return true;
    if (resolveIndex(q) != null) return true;
    return false;
  }

  static bool _isMarketQuery(String q) =>
      q.contains('market overview') ||
      q.contains('market today') ||
      q.contains('how is market') ||
      q.contains('how\'s market') ||
      q == 'market' ||
      q.contains('nse today');

  static bool _isStockQuery(String q) =>
      q.contains('analyze') ||
      q.contains('analysis') ||
      q.contains('price of') ||
      q.contains('tell me about') ||
      q.contains('outlook for');

  static bool _isBuySellQuery(String q) =>
      q.contains('should i buy') ||
      q.contains('should i sell') ||
      q.contains(' worth buying') ||
      q.contains('good buy') ||
      q.contains(' a buy') ||
      q.contains(' a sell');

  static bool _isNewsQuery(String q) =>
      q.contains('news') || q.contains('headline') || q.contains('sentiment');

  static bool _isBestStockQuery(String q) =>
      q.contains('best') &&
      (q.contains('stock') || q.contains('pick') || q.contains('today'));

  static bool _mentionsCompare(String q) =>
      q.contains('compare') || q.contains(' vs ') || q.contains(' versus ');

  static bool _isFollowUpTechnical(String q) =>
      q.contains('rsi') ||
      q.contains('macd') ||
      q.contains('ema') ||
      q.contains('bollinger') ||
      q.contains('atr') ||
      q.contains('volume') ||
      q.contains('technical') ||
      q.startsWith('what about') ||
      q.startsWith('how about');

  static String? _resolveIndicator(String q) {
    if (q.contains('rsi')) return 'rsi';
    if (q.contains('macd')) return 'macd';
    if (q.contains('ema')) return 'ema';
    if (q.contains('sma')) return 'sma';
    if (q.contains('bollinger')) return 'bollinger';
    if (q.contains('atr')) return 'atr';
    if (q.contains('volume')) return 'volume';
    if (q.contains('volatility')) return 'volatility';
    return null;
  }

  static bool _wordMatch(String q, String term) {
    if (term.length <= 4) {
      return RegExp(r'\b' + RegExp.escape(term) + r'\b').hasMatch(q);
    }
    return q.contains(term);
  }
}
