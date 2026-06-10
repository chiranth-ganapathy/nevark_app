// lib/services/api_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:otp/otp.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/angel_one_config.dart';
import '../core/models/stock_quote.dart';
import 'market_calendar.dart';
import 'market_store.dart';
import 'prediction_service.dart';

const Duration kLiveRefreshInterval = Duration(seconds: 5);

const List<String> kPrimaryIndexKeys = ['NIFTY', 'BANKNIFTY', 'FINNIFTY'];

const List<String> kAllIndexKeys = [
  'NIFTY',
  'BANKNIFTY',
  'FINNIFTY',
  'SENSEX',
  'NIFTY_NEXT_50',
  'NIFTY_MIDCAP',
  'NIFTY_SMALLCAP',
  'NIFTY_IT',
  'NIFTY_BANK',
  'NIFTY_PHARMA',
  'NIFTY_AUTO',
  'NIFTY_FMCG',
];

const Map<String, String> kNseTokens = {
  'NIFTY': '99926000',
  'BANKNIFTY': '99926009',
  'FINNIFTY': '99926037',
  'SENSEX': '99919000',
  'NIFTY_NEXT_50': '99926013',
  'NIFTY_MIDCAP': '99926011',
  'NIFTY_SMALLCAP': '99926032',
  'NIFTY_IT': '99926008',
  'NIFTY_BANK': '99926009',
  'NIFTY_PHARMA': '99926023',
  'NIFTY_AUTO': '99926029',
  'NIFTY_FMCG': '99926021',
  'TCS': '11536',
  'INFY': '1594',
  'WIPRO': '3787',
  'HCLTECH': '7229',
  'TECHM': '13538',
  'LTIM': '17818',
  'MPHASIS': '4067',
  'PERSISTENT': '18365',
  'COFORGE': '23026',
  'HDFCBANK': '1333',
  'ICICIBANK': '4963',
  'SBIN': '3045',
  'KOTAKBANK': '1922',
  'AXISBANK': '5900',
  'INDUSINDBK': '5258',
  'BANDHANBNK': '2263',
  'FEDERALBNK': '1023',
  'IDFCFIRSTB': '11184',
  'SUNPHARMA': '3351',
  'DRREDDY': '881',
  'CIPLA': '694',
  'DIVISLAB': '10940',
  'APOLLOHOSP': '157',
  'TORNTPHARM': '3518',
  'AUROPHARMA': '275',
  'RELIANCE': '2885',
  'ONGC': '2475',
  'NTPC': '11630',
  'POWERGRID': '14977',
  'TATAPOWER': '3426',
  'BPCL': '526',
  'IOC': '1624',
  'GAIL': '1209',
  'HINDUNILVR': '1394',
  'ITC': '1660',
  'NESTLEIND': '17963',
  'BRITANNIA': '547',
  'DABUR': '772',
  'MARICO': '438',
  'COLPAL': '760',
  'TATACONSUM': '3432',
  'MARUTI': '10999',
  'TATAMOT': '3456',
  'BAJAJ-AUTO': '16669',
  'HEROMOTOCO': '1348',
  'EICHERMOT': '910',
  'M&M': '2031',
  'BAJAJFINSV': '16675',
  'BAJFINANCE': '317',
  'MUTHOOTFIN': '15141',
  'CHOLAFIN': '685',
  'HDFCLIFE': '467',
  'SBILIFE': '21808',
  'SHRIRAMFIN': '3308',
  'JSWSTEEL': '11723',
  'TATASTEEL': '3408',
  'HINDALCO': '1363',
  'VEDL': '3063',
  'COALINDIA': '20374',
  'NMDC': '15332',
  'SAIL': '2963',
  'LT': '11483',
  'SIEMENS': '3200',
  'ABB': '13',
  'HAVELLS': '7249',
  'BHEL': '438',
  'BHARTIARTL': '10604',
  'DLF': '14732',
  'OBEROIRLTY': '20242',
  'PRESTIGE': '21042',
  'GODREJPROP': '17875',
};

final Map<String, String> _tokenToSym = {
  for (final e in kNseTokens.entries)
    if (e.key != 'NIFTY_BANK') e.value: e.key,
};

const Map<String, String> _aoIndexNames = {
  'Nifty 50': 'NIFTY',
  'Nifty Bank': 'BANKNIFTY',
  'Nifty Fin Service': 'FINNIFTY',
  'NIFTY 50': 'NIFTY',
  'NIFTY BANK': 'BANKNIFTY',
  'NIFTY FIN SERVICE': 'FINNIFTY',
  'Nifty Financial Services': 'FINNIFTY',
  'SENSEX': 'SENSEX',
  'S&P BSE SENSEX': 'SENSEX',
  'Nifty Next 50': 'NIFTY_NEXT_50',
  'NIFTY NEXT 50': 'NIFTY_NEXT_50',
  'NIFTYNXT50': 'NIFTY_NEXT_50',
  'Nifty Midcap 100': 'NIFTY_MIDCAP',
  'NIFTY MIDCAP 100': 'NIFTY_MIDCAP',
  'Nifty SMLCAP 100': 'NIFTY_SMALLCAP',
  'NIFTY SMLCAP 100': 'NIFTY_SMALLCAP',
  'Nifty IT': 'NIFTY_IT',
  'NIFTY IT': 'NIFTY_IT',
  'Nifty Pharma': 'NIFTY_PHARMA',
  'NIFTY PHARMA': 'NIFTY_PHARMA',
  'Nifty Auto': 'NIFTY_AUTO',
  'NIFTY AUTO': 'NIFTY_AUTO',
  'Nifty FMCG': 'NIFTY_FMCG',
  'NIFTY FMCG': 'NIFTY_FMCG',
};

const Map<String, List<String>> kSectorStocks = {
  'IT': [
    'TCS', 'INFY', 'WIPRO', 'HCLTECH', 'TECHM', 'LTIM', 'MPHASIS', 'PERSISTENT', 'COFORGE',
  ],
  'Banking': [
    'HDFCBANK', 'ICICIBANK', 'SBIN', 'KOTAKBANK', 'AXISBANK', 'INDUSINDBK', 'BANDHANBNK', 'FEDERALBNK', 'IDFCFIRSTB',
  ],
  'Pharma': [
    'SUNPHARMA', 'DRREDDY', 'CIPLA', 'DIVISLAB', 'APOLLOHOSP', 'TORNTPHARM', 'AUROPHARMA',
  ],
  'Energy': [
    'RELIANCE', 'ONGC', 'NTPC', 'POWERGRID', 'TATAPOWER', 'BPCL', 'IOC', 'GAIL',
  ],
  'FMCG': [
    'HINDUNILVR', 'ITC', 'NESTLEIND', 'BRITANNIA', 'DABUR', 'MARICO', 'COLPAL', 'TATACONSUM',
  ],
  'Agriculture': ['ITC', 'MARICO', 'DABUR', 'TATACONSUM'],
  'Auto': [
    'MARUTI', 'TATAMOT', 'BAJAJ-AUTO', 'HEROMOTOCO', 'EICHERMOT', 'M&M',
  ],
  'Metal': [
    'JSWSTEEL', 'TATASTEEL', 'HINDALCO', 'VEDL', 'COALINDIA', 'NMDC', 'SAIL',
  ],
  'Telecom': ['BHARTIARTL'],
  'Real Estate': ['DLF', 'OBEROIRLTY', 'PRESTIGE', 'GODREJPROP'],
};

enum MarketStatus { open, closed, holiday, weekend }

class MarketInfo {
  final MarketStatus status;
  final String message;
  final bool isOpen;

  const MarketInfo({required this.status, required this.message})
      : isOpen = status == MarketStatus.open;

  static MarketInfo current() {
    if (MarketCalendar.isWeekend) {
      return const MarketInfo(
        status: MarketStatus.weekend,
        message: 'Market Closed — Weekend',
      );
    }
    if (MarketCalendar.isHoliday) {
      return const MarketInfo(
        status: MarketStatus.holiday,
        message: 'Market Closed — NSE Holiday',
      );
    }
    if (MarketCalendar.isNseOpen) {
      return const MarketInfo(status: MarketStatus.open, message: 'Market Open');
    }
    final beforeOpen = MarketCalendar.minutesSinceMidnight < 9 * 60 + 15;
    return MarketInfo(
      status: MarketStatus.closed,
      message: beforeOpen
          ? 'Market opens at 9:15 AM IST'
          : 'Market Closed — After hours (3:30 PM IST)',
    );
  }
}

class AngelOneAuth {
  static String? _jwt;
  static DateTime? _exp;
  static bool _isLive = false;
  static String _lastError = '';

  static bool get isLive => _isLive;
  static bool get isLiveData => _isLive && MarketInfo.current().isOpen;
  static String get lastError => _lastError;

  static Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-UserType': 'USER',
        'X-SourceID': 'WEB',
        'X-ClientLocalIP': '127.0.0.1',
        'X-ClientPublicIP': '127.0.0.1',
        'X-MACAddress': 'AA:BB:CC:DD:EE:FF',
        'X-PrivateKey': AngelOneConfig.apiKey,
      };

  static String _totp() {
    try {
      final secret = AngelOneConfig.totpSecret
          .trim()
          .toUpperCase()
          .replaceAll(' ', '')
          .replaceAll('-', '');
      if (secret.length < 16) return '';
      return OTP.generateTOTPCodeString(
        secret,
        DateTime.now().millisecondsSinceEpoch,
        algorithm: Algorithm.SHA1,
        isGoogle: true,
      );
    } catch (_) {
      return '';
    }
  }

  static Future<bool> login() async {
    if (kIsWeb) {
      _isLive = false;
      _lastError = 'Angel One does not work on Flutter Web (CORS). Use Android.';
      return false;
    }
    final totp = _totp();
    if (totp.isEmpty) {
      _isLive = false;
      _lastError = 'Invalid TOTP secret. Check angel_one_config.dart.';
      return false;
    }
    try {
      final res = await http
          .post(
            Uri.parse(AngelOneConfig.loginUrl),
            headers: _headers(),
            body: jsonEncode({
              'clientcode': AngelOneConfig.clientCode,
              'password': AngelOneConfig.mpin,
              'totp': totp,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) {
        _isLive = false;
        _lastError = 'Login HTTP ${res.statusCode}';
        return false;
      }
      Map<String, dynamic>? body;
      try {
        body = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {}
      if (body == null || body['status'] != true) {
        _isLive = false;
        _lastError = body?['message']?.toString() ?? 'Login failed';
        return false;
      }
      _jwt = body['data']['jwtToken'] as String;
      _exp = DateTime.now().add(const Duration(hours: 23));
      _isLive = true;
      _lastError = '';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ao_jwt', _jwt!);
      await prefs.setInt('ao_exp', _exp!.millisecondsSinceEpoch);
      return true;
    } catch (e) {
      _isLive = false;
      _lastError = e.toString();
      return false;
    }
  }

  static Future<Map<String, String>?> authHeaders() async {
    if (kIsWeb) return null;
    if (_jwt != null && _exp != null && DateTime.now().isBefore(_exp!)) {
      return {..._headers(), 'Authorization': 'Bearer $_jwt'};
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('ao_jwt');
    final expMs = prefs.getInt('ao_exp') ?? 0;
    if (saved != null &&
        saved.isNotEmpty &&
        DateTime.now().isBefore(DateTime.fromMillisecondsSinceEpoch(expMs))) {
      _jwt = saved;
      _exp = DateTime.fromMillisecondsSinceEpoch(expMs);
      _isLive = true;
      return {..._headers(), 'Authorization': 'Bearer $_jwt'};
    }
    final ok = await login();
    if (!ok || _jwt == null) return null;
    return {..._headers(), 'Authorization': 'Bearer $_jwt'};
  }

  static Future<void> clearToken() async {
    _jwt = null;
    _exp = null;
    _isLive = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ao_jwt');
    await prefs.remove('ao_exp');
  }
}

Future<List<StockQuote>> _fetchQuotes(List<String> symbols) async {
  if (kIsWeb || symbols.isEmpty) return [];

  final headers = await AngelOneAuth.authHeaders();
  if (headers == null) {
    MarketStore.instance.setError(AngelOneAuth.lastError);
    return [];
  }

  final allQuotes = <StockQuote>[];

  for (var i = 0; i < symbols.length; i += 50) {
    final end = (i + 50).clamp(0, symbols.length);
    final chunk = symbols.sublist(i, end);
    final tokens = chunk
        .where((s) => kNseTokens.containsKey(s))
        .map((s) => kNseTokens[s]!)
        .toList();
    if (tokens.isEmpty) continue;

    try {
      final res = await http
          .post(
            Uri.parse(AngelOneConfig.quoteUrl),
            headers: headers,
            body: jsonEncode({'mode': 'FULL', 'exchangeTokens': {'NSE': tokens}}),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 401) {
        await AngelOneAuth.clearToken();
        await AngelOneAuth.login();
        return allQuotes;
      }
      if (res.statusCode != 200) continue;

      Map<String, dynamic>? body;
      try {
        body = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {}
      if (body == null || body['status'] != true) continue;

      final fetched = (body['data']?['fetched'] as List?) ?? [];
      for (final raw in fetched) {
        final d = raw as Map<String, dynamic>;
        final tok = d['symboltoken']?.toString() ?? '';

        String sym = _tokenToSym[tok] ?? '';
        if (sym.isEmpty) {
          final trading = d['tradingSymbol']?.toString() ?? '';
          final name = d['name']?.toString() ?? '';
          sym = _aoIndexNames[trading] ??
              _aoIndexNames[name] ??
              trading.replaceAll('-EQ', '').replaceAll('_EQ', '');
        }
        if (sym.isEmpty) continue;

        final q = StockQuote.fromAngelOne(d, symbolHint: sym);
        if (q.ltp > 0) {
          allQuotes.add(q);
          if (sym == 'BANKNIFTY') {
            allQuotes.add(StockQuote(
              symbol: 'NIFTY_BANK',
              name: 'Nifty Bank',
              ltp: q.ltp,
              open: q.open,
              high: q.high,
              low: q.low,
              close: q.close,
              change: q.change,
              changePercent: q.changePercent,
              volume: q.volume,
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('[ApiService] Fetch error: $e');
    }

    if (symbols.length > 50) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  return allQuotes;
}

class ApiService {
  static Timer? _bgTimer;
  static bool _initialized = false;
  static final Set<String> _extraSymbols = {};

  static final List<String> _stockSyms =
      kSectorStocks.values.expand((e) => e).toSet().toList();

  static List<String> get _allSyms => {
        ...kAllIndexKeys,
        ..._stockSyms,
        ..._extraSymbols,
      }.toList();

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('watchlist') ?? [];
    setWatchlistSymbols(saved);

    await MarketStore.instance.loadCache();

    final loggedIn = await AngelOneAuth.login();
    if (!loggedIn) {
      MarketStore.instance.setError(
        AngelOneAuth.lastError.isNotEmpty
            ? AngelOneAuth.lastError
            : 'Angel One login failed',
      );
    }

    await _refreshAll(force: true);

    _bgTimer = Timer.periodic(kLiveRefreshInterval, (_) async {
      await _refreshAll();
    });
  }

  /// Manual retry from UI.
  static Future<void> forceRefresh() => _refreshAll(force: true);

  static void setWatchlistSymbols(List<String> symbols) {
    _extraSymbols
      ..clear()
      ..addAll(
        symbols
            .map((s) => s.toUpperCase().trim())
            .where((s) => kNseTokens.containsKey(s)),
      );
  }

  static Future<void> _refreshAll({bool force = false}) async {
    if (kIsWeb) {
      MarketStore.instance.setError(
        'Live market data is unavailable on web. Use Android.',
      );
      return;
    }

    final market = MarketInfo.current();
    final needData = !MarketStore.instance.hasData;
    final shouldFetch = market.isOpen || needData || force;

    // Always push latest session status to UI
    MarketStore.instance.refreshMarketStatus();

    if (!shouldFetch) {
      return;
    }

    try {
      if (market.isOpen && !AngelOneAuth.isLive) {
        await AngelOneAuth.login();
      }

      final quotes = await _fetchQuotes(_allSyms);
      if (quotes.isEmpty) {
        if (!AngelOneAuth.isLive) {
          MarketStore.instance.setError(
            AngelOneAuth.lastError.isNotEmpty
                ? AngelOneAuth.lastError
                : 'Could not fetch live market data',
          );
        } else if (!market.isOpen) {
          MarketStore.instance.refreshMarketStatus();
        } else {
          MarketStore.instance.setError('No quotes returned from Angel One');
        }
        return;
      }
      MarketStore.instance.applyQuotes(quotes);
      await MarketStore.instance.saveCache();
      MarketStore.instance.refreshMarketStatus();
    } catch (e) {
      MarketStore.instance.setError(e.toString());
    }
  }

  static List<String> get allSymbolsInStore =>
      MarketStore.instance.stocks.map((q) => q.symbol).toList();

  static Map<String, StockQuote> get indicesSync => MarketStore.instance.indices;

  static List<StockQuote> get allStocksSync => MarketStore.instance.stocks;

  static StockQuote? getQuoteSync(String symbol) =>
      MarketStore.instance.quote(symbol.toUpperCase());

  static bool get isLiveData => AngelOneAuth.isLiveData;
  static MarketInfo get marketInfo => MarketInfo.current();

  static Future<void> login() => AngelOneAuth.login();

  static Future<StockQuote?> getStockQuote(String symbol) async {
    final q = getQuoteSync(symbol.toUpperCase().trim());
    return q != null && q.ltp > 0 ? q : null;
  }

  static Future<Map<String, StockQuote>> getIndices() async => indicesSync;

  static Future<List<StockQuote>> getBatchQuotes(List<String> symbols) async {
    return symbols
        .map((s) => getQuoteSync(s.toUpperCase().trim()))
        .whereType<StockQuote>()
        .where((q) => q.ltp > 0)
        .toList();
  }

  static Future<List<StockQuote>> getSectorQuotes(String sector) async {
    final syms = kSectorStocks[sector] ?? [];
    return syms
        .map((s) => getQuoteSync(s))
        .whereType<StockQuote>()
        .where((q) => q.ltp > 0)
        .toList();
  }

  static Future<DashboardData> getDashboard() async =>
      MarketStore.instance.toDashboardData();

  static List<String> searchSymbols(String query) {
    if (query.isEmpty) return [];
    final q = query.toUpperCase();
    return kNseTokens.keys
        .where((s) => !kAllIndexKeys.contains(s) && s.contains(q))
        .take(20)
        .toList();
  }

  static Stream<Map<String, StockQuote>> streamIndices() =>
      MarketStore.instance.stream.map((s) => s.indices);

  static Stream<DashboardData> streamDashboard() =>
      MarketStore.instance.stream.map((_) => MarketStore.instance.toDashboardData());

  static Stream<StockQuote> streamQuote(String symbol) {
    final sym = symbol.toUpperCase().trim();
    return MarketStore.instance.stream
        .map((_) => MarketStore.instance.quote(sym))
        .where((q) => q != null)
        .cast<StockQuote>();
  }

  static Stream<List<StockQuote>> streamBatch(List<String> symbols) {
    final upper = symbols.map((s) => s.toUpperCase().trim()).toList();
    return MarketStore.instance.stream.map((_) {
      return upper
          .map((s) => MarketStore.instance.quote(s))
          .whereType<StockQuote>()
          .where((q) => q.ltp > 0)
          .toList();
    });
  }

  static Stream<MarketSnapshot> streamMarket() => MarketStore.instance.stream;

  static void dispose() {
    _bgTimer?.cancel();
    _initialized = false;
  }
}

class DashboardData {
  final Map<String, StockQuote> indices;
  final List<StockQuote> gainers;
  final List<StockQuote> losers;
  final List<StockQuote> allStocks;

  const DashboardData({
    required this.indices,
    required this.gainers,
    required this.losers,
    required this.allStocks,
  });
}

class SectorData {
  final String name;
  final List<StockQuote> stocks;
  final double avgChange;
  final String trend;
  final String signal;
  final int confidence;
  final double avgRsi;
  final String reason;
  final String momentum;
  final String strength;

  const SectorData({
    required this.name,
    required this.stocks,
    required this.avgChange,
    required this.trend,
    required this.signal,
    required this.confidence,
    this.avgRsi = 50,
    this.reason = '',
    this.momentum = 'Neutral momentum',
    this.strength = 'Moderate',
  });

  factory SectorData.fromQuotes(String name, List<StockQuote> quotes) =>
      MarketStore.instance.sectorData(name);

  bool get isPositive => avgChange >= 0;
  String get avgChangeStr =>
      '${avgChange >= 0 ? '+' : ''}${avgChange.toStringAsFixed(2)}%';
}

class StockSignal {
  final String signal;
  final String reason;
  final String risk;
  final int confidence;

  const StockSignal({
    required this.signal,
    required this.confidence,
    required this.risk,
    required this.reason,
  });

  factory StockSignal.fromQuote(StockQuote q) {
    final pred = StockPrediction.fromQuote(q);
    return StockSignal(
      signal: pred.signalStr,
      confidence: pred.confidence,
      risk: pred.risk,
      reason: pred.reason,
    );
  }

  factory StockSignal.fromPrediction(StockPrediction pred) => StockSignal(
        signal: pred.signalStr,
        confidence: pred.confidence,
        risk: pred.risk,
        reason: pred.reason,
      );
}

const String kSebiDisclaimer =
    '⚠ Not Financial Advice. Invest at your own risk.';
