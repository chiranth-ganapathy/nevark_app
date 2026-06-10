import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_states.dart';
import '../../core/models/stock_quote.dart';
import '../../services/api_service.dart';
import '../../services/market_store.dart';
import '../../services/prediction_service.dart';
import '../stock/stock_detail_screen.dart';

List<Map<String, String>> get kAllNseStocks => kNseTokens.keys
    .where((s) => !kAllIndexKeys.contains(s))
    .map((sym) => {'sym': sym, 'name': sym})
    .toList();

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});
  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  List<String> _watchlist = [];
  Map<String, StockQuote> _quotes = {};
  bool _loading = true;
  String? _error;
  StreamSubscription<MarketSnapshot>? _sub;

  static const _defaultList = [
    'TCS',
    'HDFCBANK',
    'INFY',
    'RELIANCE',
    'ICICIBANK',
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('watchlist') ?? _defaultList;
    _watchlist = saved
        .map((s) => s.toUpperCase())
        .where((s) => kNseTokens.containsKey(s))
        .toList();
    ApiService.setWatchlistSymbols(_watchlist);
    _sub = ApiService.streamMarket().listen((snap) {
      if (!mounted) return;
      _syncFromStore(snap);
    });
    _syncFromStore(MarketStore.instance.snapshot);
  }

  void _syncFromStore(MarketSnapshot snap) {
    final map = <String, StockQuote>{};
    for (final sym in _watchlist) {
      final q = MarketStore.instance.quote(sym);
      if (q != null && q.ltp > 0) map[sym] = q;
    }
    setState(() {
      _quotes = map;
      _loading = !snap.hasData &&
          snap.lastError == null &&
          snap.marketStatus.isOpen;
      _error = snap.lastError;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('watchlist', _watchlist);
    ApiService.setWatchlistSymbols(_watchlist);
  }

  Future<void> _add(String sym) async {
    final s = sym.toUpperCase().trim();
    if (!kNseTokens.containsKey(s)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$s is not available for live NSE quotes'),
          backgroundColor: AppColors.amber,
        ),
      );
      return;
    }
    if (_watchlist.contains(s)) return;
    setState(() => _watchlist.add(s));
    await _save();
  }

  Future<void> _remove(String sym) async {
    setState(() {
      _watchlist.remove(sym);
      _quotes.remove(sym);
    });
    await _save();
  }

  void _openSearch() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _SearchSheet(
          alreadyAdded: _watchlist,
          onAdd: (sym) async {
            Navigator.pop(context);
            await _add(sym);
          },
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          title: const Text(
            'Watchlist',
            style: TextStyle(
              fontFamily: 'Syne',
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.add_circle_outline_rounded,
                color: AppColors.cyan,
                size: 26,
              ),
              onPressed: _openSearch,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _openSearch,
          backgroundColor: AppColors.cyan,
          child: const Icon(Icons.search, color: Colors.black),
        ),
        body: _loading && _quotes.isEmpty
            ? const AppLoadingState(message: 'Loading watchlist…')
            : _watchlist.isEmpty
                ? _emptyState()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    children: [
                      if (_error != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.red.withOpacity(0.25),
                            ),
                          ),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              fontFamily: 'Space Mono',
                              fontSize: 10,
                              color: AppColors.red,
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          Text(
                            '${_watchlist.length} stocks · live from MarketStore',
                            style: TextStyle(
                              fontFamily: 'Space Mono',
                              fontSize: 10,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: _openSearch,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.cyan.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.cyan.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add, color: AppColors.cyan, size: 13),
                                    SizedBox(width: 4),
                                    Text(
                                      'Add',
                                      style: TextStyle(
                                        fontFamily: 'Space Mono',
                                        fontSize: 10,
                                        color: AppColors.cyan,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._watchlist.map((sym) {
                        final q = _quotes[sym];
                        return _WatchCard(
                          symbol: sym,
                          quote: q,
                          error: q == null && !_loading ? 'Live quote unavailable' : null,
                          onTap: q == null
                              ? null
                              : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => StockDetailScreen(quote: q),
                                    ),
                                  ),
                          onRemove: () => _confirmRemove(sym),
                        );
                      }),
                      const SizedBox(height: 20),
                      Center(
                        child: Text(
                          kSebiDisclaimer,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Space Mono',
                            fontSize: 9,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
      );

  Widget _emptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border_rounded,
              size: 64,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            const Text(
              'Watchlist empty',
              style: TextStyle(
                fontFamily: 'Syne',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Search and add NSE stocks with live tokens',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _openSearch,
              icon: const Icon(Icons.add),
              label: const Text('Add Stock'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cyan,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      );

  void _confirmRemove(String sym) => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            'Remove $sym?',
            style: const TextStyle(
              fontFamily: 'Syne',
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          content: Text(
            'Remove from your watchlist?',
            style: TextStyle(color: AppColors.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _remove(sym);
              },
              child: Text(
                'Remove',
                style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
}

class _WatchCard extends StatelessWidget {
  final String symbol;
  final StockQuote? quote;
  final String? error;
  final VoidCallback? onTap;
  final VoidCallback onRemove;

  const _WatchCard({
    required this.symbol,
    required this.quote,
    this.error,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (quote == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Text(
              symbol,
              style: const TextStyle(
                fontFamily: 'Syne',
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            if (error != null)
              Text(
                error!,
                style: TextStyle(
                  fontFamily: 'Space Mono',
                  fontSize: 9,
                  color: AppColors.amber,
                ),
              )
            else
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AppColors.cyan,
                ),
              ),
          ],
        ),
      );
    }

    final pred = StockPrediction.fromQuote(quote!);
    final isUp = quote!.change >= 0;
    final pclr = isUp ? AppColors.green : AppColors.red;
    final sigStr = pred.signalStr;
    final sigClr = sigStr == 'BUY'
        ? AppColors.green
        : sigStr == 'SELL'
            ? AppColors.red
            : AppColors.amber;
    final ind = pred.signal.indicators;

    return Dismissible(
      key: Key(symbol),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.red.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.red.withOpacity(0.3)),
        ),
        child: Icon(Icons.delete_outline_rounded, color: AppColors.red, size: 24),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: pclr.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        symbol.length >= 2 ? symbol.substring(0, 2) : symbol,
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: pclr,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          symbol,
                          style: const TextStyle(
                            fontFamily: 'Syne',
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            _Pill(sigStr, sigClr),
                            const SizedBox(width: 6),
                            Text(
                              '${pred.confidence}% · ${pred.risk} risk',
                              style: TextStyle(
                                fontFamily: 'Space Mono',
                                fontSize: 9,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        quote!.priceStr,
                        style: const TextStyle(
                          fontFamily: 'Space Mono',
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: pclr.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          quote!.changePctStr,
                          style: TextStyle(
                            fontFamily: 'Space Mono',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: pclr,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: sigClr.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: sigClr.withOpacity(0.15)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_graph_rounded, color: sigClr, size: 13),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        pred.reason,
                        style: TextStyle(
                          fontFamily: 'Space Mono',
                          fontSize: 10,
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _Mini('O', '₹${quote!.open.toStringAsFixed(0)}'),
                  const SizedBox(width: 10),
                  _Mini('H', '₹${quote!.high.toStringAsFixed(0)}'),
                  const SizedBox(width: 10),
                  _Mini('L', '₹${quote!.low.toStringAsFixed(0)}'),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'RSI ${pred.rsiValue.toStringAsFixed(0)} · ${pred.rsiLabel}',
                      style: TextStyle(
                        fontFamily: 'Space Mono',
                        fontSize: 9,
                        color: AppColors.cyan,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    ind.ema9 > ind.ema21 ? 'Bullish momentum' : 'Bearish momentum',
                    style: TextStyle(
                      fontFamily: 'Space Mono',
                      fontSize: 9,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    ind.volumeLabel,
                    style: TextStyle(
                      fontFamily: 'Space Mono',
                      fontSize: 9,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(color: AppColors.cardBorder, height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: quote == null
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StockDetailScreen(quote: quote!),
                              ),
                            ),
                    icon: Icon(Icons.auto_graph_rounded, color: AppColors.cyan),
                    label: Text(
                      'Analyze Stock',
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.cyan,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.cyan,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String s;
  final Color c;
  const _Pill(this.s, this.c);
  @override
  Widget build(BuildContext _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: c.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          s,
          style: TextStyle(
            fontFamily: 'Space Mono',
            fontSize: 9,
            color: c,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _Mini extends StatelessWidget {
  final String l, v;
  const _Mini(this.l, this.v);
  @override
  Widget build(BuildContext _) => Row(
        children: [
          Text(
            '$l:',
            style: TextStyle(
              fontFamily: 'Space Mono',
              fontSize: 9,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            v,
            style: const TextStyle(
              fontFamily: 'Space Mono',
              fontSize: 9,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
}

class _SearchSheet extends StatefulWidget {
  final List<String> alreadyAdded;
  final void Function(String) onAdd;
  const _SearchSheet({required this.alreadyAdded, required this.onAdd});
  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final _ctrl = TextEditingController();
  List<Map<String, String>> _results = kAllNseStocks;

  void _filter(String q) {
    final l = q.toLowerCase();
    setState(() {
      _results = q.isEmpty
          ? kAllNseStocks
          : kAllNseStocks
              .where((s) => s['sym']!.toLowerCase().contains(l))
              .toList();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, sc) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF090F18),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Add to Watchlist',
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _ctrl,
                  onChanged: _filter,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search live NSE symbols...',
                    hintStyle: TextStyle(color: AppColors.textMuted),
                    prefixIcon: Icon(Icons.search, color: AppColors.cyan),
                    filled: true,
                    fillColor: const Color(0xFF0D1620),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_results.length} live symbols',
                    style: TextStyle(
                      fontFamily: 'Space Mono',
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: sc,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final sym = _results[i]['sym']!;
                    final added = widget.alreadyAdded.contains(sym);
                    return ListTile(
                      title: Text(
                        sym,
                        style: const TextStyle(
                          fontFamily: 'Syne',
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      trailing: added
                          ? Text(
                              'Added',
                              style: TextStyle(
                                fontFamily: 'Space Mono',
                                fontSize: 9,
                                color: AppColors.green,
                              ),
                            )
                          : GestureDetector(
                              onTap: () => widget.onAdd(sym),
                              child: Text(
                                '+ Add',
                                style: TextStyle(
                                  fontFamily: 'Space Mono',
                                  fontSize: 10,
                                  color: AppColors.cyan,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
}
