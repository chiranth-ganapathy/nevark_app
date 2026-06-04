import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/stock_quote.dart';
import '../../services/api_service.dart';
import '../stock/stock_detail_screen.dart';
 
class ScreenerScreen extends StatefulWidget {
  const ScreenerScreen({super.key});
  @override
  State<ScreenerScreen> createState() => _ScreenerScreenState();
}
 
class _ScreenerScreenState extends State<ScreenerScreen> {
  final List<String> _filters = ['All','Bullish','Bearish','High Vol','Low Risk'];
  String _filter = 'All';
  List<StockQuote> _quotes = [];
  bool    _loading = true;
  String? _error;
 
  final List<String> _allSyms = [
    'TCS','HDFCBANK','INFY','RELIANCE','ITC','WIPRO','SBIN','ICICIBANK',
    'KOTAKBANK','SUNPHARMA','MARUTI','TATAMOT','BHARTIARTL','HCLTECH',
  ];
 
  @override
  void initState() { super.initState(); _load(); }
 
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final quotes = await ApiService.getBatchQuotes(_allSyms);
      if (!mounted) return;
      setState(() { _quotes = quotes; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }
 
  List<StockQuote> get _filtered {
    switch (_filter) {
      case 'Bullish':   return _quotes.where((q) => q.changePercent > 0.5).toList();
      case 'Bearish':   return _quotes.where((q) => q.changePercent < -0.5).toList();
      case 'High Vol':  return _quotes.where((q) => q.volume > 2000000).toList();
      case 'Low Risk':  return _quotes.where((q) => q.changePercent.abs() < 1.0).toList();
      default:          return _quotes;
    }
  }
 
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(backgroundColor: AppColors.surface, elevation: 0,
      title: const Text('Stock Screener', style: TextStyle(fontFamily: 'Syne',
        fontWeight: FontWeight.w800, color: Colors.white)),
      actions: [IconButton(
        icon: const Icon(Icons.refresh_rounded, color: AppColors.cyan),
        onPressed: _load)]),
    body: Column(children: [
      // Filter chips
      SizedBox(height: 52,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _filters.length,
          itemBuilder: (_, i) {
            final sel = _filters[i] == _filter;
            return GestureDetector(
              onTap: () => setState(() => _filter = _filters[i]),
              child: Container(
                margin: const EdgeInsets.only(right: 8, top: 10, bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: sel ? AppColors.cyan : AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel
                    ? AppColors.cyan : AppColors.cardBorder)),
                child: Center(child: Text(_filters[i], style: TextStyle(
                  fontFamily: 'Space Mono', fontSize: 11,
                  color: sel ? AppColors.bg : AppColors.textMuted,
                  fontWeight: FontWeight.w700)))));
          })),
 
      // List
      Expanded(child: _loading
        ? const Center(child: CircularProgressIndicator(
            color: AppColors.cyan, strokeWidth: 1.5))
        : _error != null
          ? Center(child: Text(_error!, style: TextStyle(color: AppColors.red)))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final q   = _filtered[i];
                final sig = StockSignal.fromQuote(q);
                final sc  = sig.signal == 'BUY' ? AppColors.green
                  : sig.signal == 'SELL' ? AppColors.red : AppColors.amber;
                return GestureDetector(
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) =>
                      StockDetailScreen(quote: q))),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.cardBorder)),
                    child: Row(children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(q.symbol, style: const TextStyle(
                            fontFamily: 'Syne', fontWeight: FontWeight.w700,
                            fontSize: 14, color: Colors.white)),
                          Text(sig.reason,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11,
                              color: AppColors.textMuted)),
                        ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(q.priceStr, style: const TextStyle(
                            fontFamily: 'Syne', fontWeight: FontWeight.w700,
                            fontSize: 13, color: Colors.white)),
                          Text(q.changePctStr, style: TextStyle(
                            fontFamily: 'Space Mono', fontSize: 11,
                            color: q.isPositive
                              ? AppColors.green : AppColors.red)),
                        ]),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: sc.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: sc.withOpacity(0.3))),
                        child: Text(sig.signal, style: TextStyle(
                          fontFamily: 'Space Mono', fontSize: 10,
                          color: sc, fontWeight: FontWeight.w700))),
                    ])));
              })),
    ]),
  );
}
