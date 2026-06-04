// lib/core/models/stock_quote.dart

class StockQuote {
  final String symbol;
  final String name;
  final double ltp;          // last traded price
  final double open;
  final double high;
  final double low;
  final double close;        // previous day close
  final double change;
  final double changePercent; // numeric e.g. +1.23 or -0.45
  final int    volume;

  const StockQuote({
    required this.symbol,
    this.name          = '',
    required this.ltp,
    this.open          = 0,
    this.high          = 0,
    this.low           = 0,
    this.close         = 0,
    required this.change,
    required this.changePercent,
    this.volume        = 0,
  });

  // ── Aliases so old code still compiles ──────────────────────────
  double get price     => ltp;
  double get prevClose => close;

  // Formatted strings
  String get priceStr     => '₹${ltp.toStringAsFixed(2)}';
  String get changeStr    => '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}';
  String get changePctStr => '${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%';

  // Old changePct string alias (used by chatbot_service / old dashboard)
  String get changePct      => changePctStr;
  String get changePctClean => changePctStr;

  // Convenience
  bool   get isPositive   => change >= 0;
  double get changePctAbs => changePercent.abs();

  // ── Angel One response parser ────────────────────────────────────
  factory StockQuote.fromAngelOne(
    Map<String, dynamic> d, {
    String? symbolHint,
  }) {
    final ltp   = _d(d['ltp']);
    final close = _d(d['close']);
    final chg   = ltp - close;
    final pct   = close > 0 ? (chg / close) * 100 : 0.0;

    // Resolve symbol from hint → tradingSymbol → name → token
    String sym = symbolHint ?? '';
    if (sym.isEmpty) sym = d['tradingSymbol']?.toString() ?? '';
    if (sym.isEmpty) sym = d['name']?.toString() ?? '';

    String nm = d['name']?.toString() ?? sym;

    return StockQuote(
      symbol:        sym,
      name:          nm,
      ltp:           ltp,
      open:          _d(d['open']),
      high:          _d(d['high']),
      low:           _d(d['low']),
      close:         close,
      change:        chg,
      changePercent: pct,
      volume:        _i(d['volume'] ?? d['tradeVolume']),
    );
  }

  // ── Generic JSON parser (FastAPI / mock) ─────────────────────────
  factory StockQuote.fromJson(Map<String, dynamic> j) {
    final ltpVal   = _d(j['ltp'] ?? j['price']);
    final closeVal = _d(j['close'] ?? j['prevClose']);
    final chgVal   = _d(j['change'] ?? ltpVal - closeVal);
    final pctRaw   = j['changePercent'] ?? j['changePct'];
    final pctVal   = pctRaw is num
        ? pctRaw.toDouble()
        : double.tryParse(
              pctRaw?.toString().replaceAll('%', '').replaceAll(' ', '') ?? '0',
            ) ??
            (closeVal > 0 ? (chgVal / closeVal) * 100 : 0.0);

    return StockQuote(
      symbol:        j['symbol']?.toString() ?? '',
      name:          j['name']?.toString() ?? '',
      ltp:           ltpVal,
      open:          _d(j['open']),
      high:          _d(j['high']),
      low:           _d(j['low']),
      close:         closeVal,
      change:        chgVal,
      changePercent: pctVal,
      volume:        _i(j['volume']),
    );
  }

  static double _d(dynamic v) =>
      double.tryParse(v?.toString() ?? '0') ?? 0.0;
  static int _i(dynamic v) =>
      int.tryParse(v?.toString() ?? '0') ?? 0;
}