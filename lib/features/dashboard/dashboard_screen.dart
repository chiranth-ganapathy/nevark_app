import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/stock_quote.dart';
import '../../services/api_service.dart';
import '../../services/market_store.dart';
import '../../services/prediction_service.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/glass_card.dart';
import '../../services/intelligence/intelligence_engine.dart';
import '../sector/sector_screen.dart';
import '../stock/stock_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  @override bool get wantKeepAlive => true;

  // ── State — always comes from the single _Store ────────────────
  Map<String, StockQuote> _indices  = {};
  List<StockQuote>        _stocks   = [];
  Map<String, SectorData> _sectors  = {};
  bool    _loading = true;
  String? _error;
  int     _tab     = 0;
  MarketInfo _marketInfo = MarketInfo.current();

  StreamSubscription<MarketSnapshot>? _marketSub;

  // ── Animation ─────────────────────────────────────────────────
  late AnimationController _shimCtrl;
  late AnimationController _cardCtrl;

  @override
  void initState() {
    super.initState();
    _shimCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1200))..repeat();
    _cardCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 800));
    _startStreams();
  }

  @override
  void dispose() {
    _marketSub?.cancel();
    _shimCtrl.dispose();
    _cardCtrl.dispose();
    super.dispose();
  }

  void _applySnapshot(MarketSnapshot snap) {
    final data = MarketStore.instance.toDashboardData();
    final sectorMap = <String, SectorData>{};
    for (final name in kSectorStocks.keys) {
      final sd = MarketStore.instance.sectorData(name);
      if (sd.stocks.isNotEmpty) sectorMap[name] = sd;
    }

    setState(() {
      _indices = data.indices;
      _stocks = data.allStocks;
      _sectors = sectorMap;
      _marketInfo = snap.marketStatus;
      // Only shimmer while market is open and we're still waiting for first fetch
      _loading = !snap.hasData &&
          snap.lastError == null &&
          snap.marketStatus.isOpen &&
          ApiService.isLiveData;
      _error = snap.lastError;
    });

    if (_stocks.isNotEmpty && _cardCtrl.status != AnimationStatus.completed) {
      _cardCtrl.forward();
    }
  }

  void _startStreams() {
    _marketSub = ApiService.streamMarket().listen((snap) {
      if (!mounted) return;
      _applySnapshot(snap);
    }, onError: (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    });
    _applySnapshot(MarketStore.instance.snapshot);
  }

  // ── Sorted views ──────────────────────────────────────────────
  List<StockQuote> get _gainers =>
      [..._stocks]..sort((a, b) => b.changePercent.compareTo(a.changePercent));
  List<StockQuote> get _losers =>
      [..._stocks]..sort((a, b) => a.changePercent.compareTo(b.changePercent));
  List<StockQuote> get _shown => _tab == 1
      ? _gainers.where((s) => s.change >= 0).take(15).toList()
      : _tab == 2
          ? _losers.where((s) => s.change < 0).take(15).toList()
          : _stocks;

  // ── Navigate to stock detail — passes the EXACT same StockQuote
  // from the store so price always matches what's shown on tile ───
  void _openStock(StockQuote q) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => StockDetailScreen(quote: q)));
  }

  // ── Navigate to sector detail ─────────────────────────────────
  void _openSector(SectorData sector) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => SectorDetailScreen(sector: sector)));
  }

  void _openAllIndicesSheet() {
    if (_indices.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AllIndicesSheet(indices: _indices),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _buildAppBar(),
      body: _loading && _stocks.isEmpty
          ? _buildShimmer()
          : _error != null && _stocks.isEmpty
              ? _buildError()
              : _stocks.isEmpty
                  ? _buildEmptyMarket()
                  : _buildBody(),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────
  AppBar _buildAppBar() => AppBar(
    backgroundColor: AppColors.bg,
    elevation: 0,
    systemOverlayStyle: SystemUiOverlayStyle.light,
    titleSpacing: 16,
    title: Row(children: [
      RichText(text: TextSpan(children: [
        TextSpan(text: 'Ne', style: TextStyle(fontFamily: 'Syne',
            fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.cyan)),
        const TextSpan(text: 'Vark', style: TextStyle(fontFamily: 'Syne',
            fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
      ])),
      const Spacer(),
      _LiveDot(isLive: _marketInfo.isOpen && ApiService.isLiveData),
    ]),
  );

  Widget _marketBanner() {
    if (_marketInfo.isOpen) return const SizedBox.shrink();
    final clr = _marketInfo.status == MarketStatus.weekend ||
            _marketInfo.status == MarketStatus.holiday
        ? AppColors.amber
        : AppColors.textMuted;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: clr.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: clr.withOpacity(0.25)),
      ),
      child: Row(children: [
        Icon(Icons.schedule_rounded, color: clr, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _marketInfo.message,
            style: TextStyle(
              fontFamily: 'Space Mono',
              fontSize: 10,
              color: clr,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ]),
    );
  }

  // ── Main body ─────────────────────────────────────────────────
  Widget _buildBody() => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.only(bottom: 100),
    children: [
      _marketBanner(),
        // ── Indices ───────────────────────────────────────────
        _IndicesRow(indices: _indices, onViewAll: _openAllIndicesSheet),

        // ── Market mood ───────────────────────────────────────
        if (_stocks.isNotEmpty)
          _MoodBar(
            gainers: _stocks.where((s) => s.change >= 0).length,
            losers:  _stocks.where((s) => s.change <  0).length,
            total:   _stocks.length,
          ),

        if (_stocks.isNotEmpty) _MarketInsightsPanel(),

        // ── Sector heatmap — TAPPABLE ─────────────────────────
        if (_sectors.isNotEmpty) ...[
          _SecHeader('Sector Intelligence', Icons.grid_view_rounded),
          _SectorGrid(
            sectors: _sectors,
            onTap:   _openSector,   // ✅ FIX: sector tiles now open detail
          ),
        ],

        // ── Top movers ────────────────────────────────────────
        if (_stocks.isNotEmpty) ...[
          _SecHeader('Top Movers', Icons.bolt_rounded),
          _MoversRow(
            gainers: _gainers.where((s) => s.change >= 0).take(5).toList(),
            losers:  _losers.where((s) =>  s.change <  0).take(5).toList(),
            onTap:   _openStock,
          ),
        ],

        // ── Stock list ────────────────────────────────────────
        const SizedBox(height: 8),
        _Tabs(tab: _tab, onTap: (i) => setState(() => _tab = i)),
        const SizedBox(height: 8),

        // ✅ FIX: each tile passes the exact StockQuote from store
        ..._shown.asMap().entries.map((e) => _StockCard(
          quote: e.value,
          index: e.key,
          ctrl:  _cardCtrl,
          onTap: () => _openStock(e.value),
        )),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            kSebiDisclaimer,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Space Mono',
              fontSize: 9,
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
        ),
      ],
    );

  // ── Shimmer ───────────────────────────────────────────────────
  Widget _buildShimmer() => AnimatedBuilder(
    animation: _shimCtrl,
    builder: (_, _) => ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Shimmer(h: 100, w: _shimCtrl.value),
        const SizedBox(height: 10),
        _Shimmer(h: 60,  w: _shimCtrl.value),
        const SizedBox(height: 10),
        _Shimmer(h: 140, w: _shimCtrl.value),
        const SizedBox(height: 10),
        ...List.generate(6, (_) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _Shimmer(h: 70, w: _shimCtrl.value))),
      ],
    ),
  );

  Widget _buildError() => Center(
        child: AppErrorState(
          message: '${_error ?? 'Could not load data'}\n\n'
              '${AngelOneAuth.lastError.isNotEmpty ? AngelOneAuth.lastError : 'Check internet and Angel One config.'}',
          onRetry: () async {
            setState(() {
              _loading = true;
              _error = null;
            });
            await ApiService.login();
            await ApiService.forceRefresh();
            _applySnapshot(MarketStore.instance.snapshot);
          },
        ),
      );

  Widget _buildEmptyMarket() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      _marketBanner(),
      const SizedBox(height: 32),
      Icon(Icons.schedule_rounded, size: 48, color: AppColors.amber),
      const SizedBox(height: 16),
      Text(
        _marketInfo.message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Syne',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'Live prices appear when the NSE is open (9:15 AM – 3:30 PM IST, Mon–Fri).\n\n'
        'If you opened the app outside market hours, this is expected. '
        'Open again during trading hours for live data.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textMuted,
          height: 1.6,
        ),
      ),
      if (!ApiService.isLiveData && AngelOneAuth.lastError.isNotEmpty) ...[
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.red.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.red.withOpacity(0.25)),
          ),
          child: Text(
            'Angel One login failed:\n${AngelOneAuth.lastError}',
            style: TextStyle(
              fontFamily: 'Space Mono',
              fontSize: 10,
              color: AppColors.red,
              height: 1.5,
            ),
          ),
        ),
      ],
    ],
  );
}

// ─────────────────────────────────────────────────────────────────
// LIVE DOT
// ─────────────────────────────────────────────────────────────────
class _LiveDot extends StatefulWidget {
  final bool isLive;
  const _LiveDot({required this.isLive});
  @override State<_LiveDot> createState() => _LiveDotState();
}
class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final clr = widget.isLive ? AppColors.green : AppColors.amber;
    return AnimatedBuilder(animation: _c, builder: (_, _) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: clr.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: clr.withOpacity(0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(
            color: clr.withOpacity(0.4 + _c.value * 0.6),
            shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(widget.isLive ? 'LIVE' : 'OFFLINE',
            style: TextStyle(fontFamily: 'Space Mono', fontSize: 9,
                fontWeight: FontWeight.w700, color: clr)),
      ]),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────
// INDICES ROW — shows NIFTY, BANKNIFTY, FINNIFTY (all from store)
// ─────────────────────────────────────────────────────────────────
class _IndicesRow extends StatelessWidget {
  final Map<String, StockQuote> indices;
  final VoidCallback onViewAll;

  const _IndicesRow({
    required this.indices,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final shown = kPrimaryIndexKeys.where(indices.containsKey).toList();
    if (shown.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          children: [
            Text(
              'MARKET OVERVIEW',
              style: TextStyle(
                fontFamily: 'Space Mono',
                fontSize: 9,
                color: AppColors.textMuted,
                letterSpacing: 2,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onViewAll,
              child: Text(
                'View all (${indices.length})',
                style: const TextStyle(
                  fontFamily: 'Space Mono',
                  fontSize: 10,
                  color: AppColors.cyan,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: shown
              .map(
                (sym) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: sym != shown.last ? 10.0 : 0.0),
                    child: _IndexCard(q: indices[sym]!),
                  ),
                ),
              )
              .toList(),
        ),
      ]),
    );
  }
}

class _IndexCard extends StatefulWidget {
  final StockQuote q;
  const _IndexCard({required this.q});
  @override
  State<_IndexCard> createState() => _IndexCardState();
}

class _IndexCardState extends State<_IndexCard> {
  double? _prevLtp;
  Color _flash = Colors.transparent;

  @override
  void didUpdateWidget(covariant _IndexCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_prevLtp != null && widget.q.ltp != _prevLtp) {
      _flash = widget.q.ltp > _prevLtp!
          ? AppColors.green.withOpacity(0.35)
          : AppColors.red.withOpacity(0.35);
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _flash = Colors.transparent);
      });
    }
    _prevLtp = widget.q.ltp;
  }

  @override
  Widget build(BuildContext context) {
    _prevLtp ??= widget.q.ltp;
    final q = widget.q;
    final isUp = q.change >= 0;
    final clr = isUp ? AppColors.green : AppColors.red;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _flash == Colors.transparent
            ? AppColors.surface
            : Color.alphaBlend(_flash, AppColors.surface),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: clr.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            q.symbol,
            style: TextStyle(
              fontFamily: 'Space Mono',
              fontSize: 9,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            q.ltp.toStringAsFixed(0),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Syne',
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Row(children: [
            Icon(
              isUp ? Icons.arrow_drop_up : Icons.arrow_drop_down,
              color: clr,
              size: 14,
            ),
            Flexible(
              child: Text(
                '${q.changePercent.abs().toStringAsFixed(2)}%',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Space Mono',
                  fontSize: 10,
                  color: clr,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// MOOD BAR
// ─────────────────────────────────────────────────────────────────
class _MoodBar extends StatelessWidget {
  final int gainers, losers, total;
  const _MoodBar({required this.gainers, required this.losers, required this.total});
  @override
  Widget build(BuildContext context) {
    final gPct    = total > 0 ? gainers / total : 0.5;
    final mood    = gPct > 0.6 ? 'BULLISH' : gPct < 0.4 ? 'BEARISH' : 'NEUTRAL';
    final moodClr = gPct > 0.6 ? AppColors.green
        : gPct < 0.4 ? AppColors.red : AppColors.amber;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Market Mood', style: TextStyle(fontFamily: 'Space Mono',
              fontSize: 10, color: AppColors.textMuted)),
          const Spacer(),
          Text(mood, style: TextStyle(fontFamily: 'Space Mono',
              fontSize: 10, color: moodClr, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(4),
          child: SizedBox(height: 6, child: Row(children: [
            Flexible(flex: gainers.clamp(1, 100),
                child: Container(color: AppColors.green)),
            Flexible(flex: losers.clamp(1, 100),
                child: Container(color: AppColors.red)),
          ]))),
        const SizedBox(height: 6),
        Row(children: [
          _dot(AppColors.green), const SizedBox(width: 4),
          Text('$gainers up', style: TextStyle(fontFamily: 'Space Mono',
              fontSize: 10, color: AppColors.textMuted)),
          const Spacer(),
          _dot(AppColors.red), const SizedBox(width: 4),
          Text('$losers down', style: TextStyle(fontFamily: 'Space Mono',
              fontSize: 10, color: AppColors.textMuted)),
        ]),
      ]),
    );
  }
  Widget _dot(Color c) => Container(width: 6, height: 6,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle));
}

// ─────────────────────────────────────────────────────────────────
// SECTOR GRID — ✅ FIXED: onTap opens SectorDetailScreen
// ─────────────────────────────────────────────────────────────────
class _SecHeader extends StatelessWidget {
  final String t; final IconData i;
  const _SecHeader(this.t, this.i);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
    child: Row(children: [
      Icon(i, color: AppColors.cyan, size: 16),
      const SizedBox(width: 6),
      Text(t, style: const TextStyle(fontFamily: 'Syne',
          fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
    ]),
  );
}

class _SectorGrid extends StatelessWidget {
  final Map<String, SectorData>      sectors;
  final void Function(SectorData)    onTap;
  const _SectorGrid({required this.sectors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final entries = sectors.entries.toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, childAspectRatio: 1.4,
            crossAxisSpacing: 8, mainAxisSpacing: 8),
        itemCount: entries.length,
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => onTap(entries[i].value), // ✅ tappable
          child: _SectorTile(s: entries[i].value),
        ),
      ),
    );
  }
}

class _SectorTile extends StatelessWidget {
  final SectorData s;
  const _SectorTile({required this.s});
  @override
  Widget build(BuildContext context) {
    final clr  = s.trend == 'BULLISH' ? AppColors.green
        : s.trend == 'BEARISH' ? AppColors.red : AppColors.amber;
    final icon = s.trend == 'BULLISH' ? Icons.trending_up
        : s.trend == 'BEARISH' ? Icons.trending_down : Icons.trending_flat;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: clr.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: clr.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: clr, size: 13),
          const Spacer(),
          Text('${s.confidence}%', style: TextStyle(
              fontFamily: 'Space Mono', fontSize: 9, color: clr)),
        ]),
        const Spacer(),
        Text(s.name, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Syne', fontSize: 11,
                fontWeight: FontWeight.w700, color: Colors.white)),
        Text(s.avgChangeStr, style: TextStyle(
            fontFamily: 'Space Mono', fontSize: 8, color: clr)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TOP MOVERS
// ─────────────────────────────────────────────────────────────────
class _MoversRow extends StatelessWidget {
  final List<StockQuote>             gainers, losers;
  final void Function(StockQuote)    onTap;
  const _MoversRow({
    required this.gainers, required this.losers, required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(height: 90, child: ListView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    children: [
      ...gainers.map((q) => _Chip(q: q, up: true,  onTap: () => onTap(q))),
      ...losers.map( (q) => _Chip(q: q, up: false, onTap: () => onTap(q))),
    ],
  ));
}

class _Chip extends StatelessWidget {
  final StockQuote q; final bool up; final VoidCallback onTap;
  const _Chip({required this.q, required this.up, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final clr  = up ? AppColors.green : AppColors.red;
    final sign = q.changePercent >= 0 ? '+' : '';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100, margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: clr.withOpacity(0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: clr.withOpacity(0.25))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(q.symbol, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Syne', fontSize: 11,
                  fontWeight: FontWeight.w700, color: Colors.white)),
          const Spacer(),
          Text('₹${q.ltp.toStringAsFixed(0)}',
              style: const TextStyle(fontFamily: 'Space Mono', fontSize: 11,
                  color: Colors.white, fontWeight: FontWeight.w700)),
          Text('$sign${q.changePercent.toStringAsFixed(2)}%',
              style: TextStyle(fontFamily: 'Space Mono',
                  fontSize: 10, color: clr, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TABS
// ─────────────────────────────────────────────────────────────────
class _Tabs extends StatelessWidget {
  final int tab; final void Function(int) onTap;
  const _Tabs({required this.tab, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(children: ['All', 'Gainers', 'Losers'].asMap().entries.map((e) =>
      GestureDetector(
        onTap: () => onTap(e.key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
              color: tab == e.key
                  ? AppColors.cyan.withOpacity(0.15) : AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: tab == e.key ? AppColors.cyan : AppColors.cardBorder)),
          child: Text(e.value, style: TextStyle(fontFamily: 'Space Mono',
              fontSize: 11,
              color: tab == e.key ? AppColors.cyan : AppColors.textMuted,
              fontWeight: FontWeight.w700)),
        ),
      )
    ).toList()),
  );
}

// ─────────────────────────────────────────────────────────────────
// STOCK CARD
// ✅ FIX: prediction computed from the SAME StockQuote passed to detail
// So dashboard pill == detail signal — they're the same object
// ─────────────────────────────────────────────────────────────────
class _StockCard extends StatefulWidget {
  final StockQuote quote;
  final int index;
  final AnimationController ctrl;
  final VoidCallback onTap;
  const _StockCard({
    required this.quote,
    required this.index,
    required this.ctrl,
    required this.onTap,
  });
  @override
  State<_StockCard> createState() => _StockCardState();
}

class _StockCardState extends State<_StockCard> {
  double? _prevLtp;
  Color _flash = Colors.transparent;

  @override
  void didUpdateWidget(covariant _StockCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_prevLtp != null && widget.quote.ltp != _prevLtp) {
      _flash = widget.quote.ltp > _prevLtp!
          ? AppColors.green.withOpacity(0.28)
          : AppColors.red.withOpacity(0.28);
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _flash = Colors.transparent);
      });
    }
    _prevLtp = widget.quote.ltp;
  }

  @override
  Widget build(BuildContext context) {
    _prevLtp ??= widget.quote.ltp;
    final quote = widget.quote;
    final isUp = quote.change >= 0;
    final clr = isUp ? AppColors.green : AppColors.red;
    final sign = quote.changePercent >= 0 ? '+' : '';
    final pred = XGBoostSignal.classify(quote);
    final delay = (widget.index * 0.04).clamp(0.0, 0.8);
    final anim = CurvedAnimation(
      parent: widget.ctrl,
      curve: Interval(
        delay,
        (delay + 0.4).clamp(0.0, 1.0),
        curve: Curves.easeOut,
      ),
    );

    return RepaintBoundary(
      child: AnimatedBuilder(
      animation: anim,
      builder: (_, child) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - anim.value)),
          child: child,
        ),
      ),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _flash == Colors.transparent
                ? AppColors.surface
                : Color.alphaBlend(_flash, AppColors.surface),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: clr.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  quote.symbol.length >= 2
                      ? quote.symbol.substring(0, 2)
                      : quote.symbol,
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: clr,
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
                    quote.symbol.replaceAll('-EQ', ''),
                    style: const TextStyle(
                      fontFamily: 'Syne',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(children: [
                    _SignalPill(pred.signal),
                    const SizedBox(width: 6),
                    Text(
                      '${pred.confidence}%',
                      style: TextStyle(
                        fontFamily: 'Space Mono',
                        fontSize: 9,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${quote.ltp.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontFamily: 'Space Mono',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: clr.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    '$sign${quote.changePercent.toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontFamily: 'Space Mono',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: clr,
                    ),
                  ),
                ),
              ],
            ),
          ]),
        ),
      ),
    ),
    );
  }
}

class _SignalPill extends StatelessWidget {
  final String s;
  const _SignalPill(this.s);
  @override
  Widget build(BuildContext context) {
    final clr = s == 'BUY' ? AppColors.green
        : s == 'SELL' ? AppColors.red : AppColors.amber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: clr.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4)),
      child: Text(s, style: TextStyle(fontFamily: 'Space Mono',
          fontSize: 9, color: clr, fontWeight: FontWeight.w700)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// SHIMMER
// ─────────────────────────────────────────────────────────────────
class _Shimmer extends StatelessWidget {
  final double h, w;
  const _Shimmer({required this.h, required this.w});
  @override
  Widget build(BuildContext context) => Container(
    height: h,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      gradient: LinearGradient(
        begin: Alignment(-1 + w * 2, 0), end: Alignment(w * 2, 0),
        colors: [AppColors.surface,
          Colors.white.withOpacity(0.04), AppColors.surface],
      ),
    ),
  );
}

class _AllIndicesSheet extends StatelessWidget {
  final Map<String, StockQuote> indices;
  const _AllIndicesSheet({required this.indices});

  @override
  Widget build(BuildContext context) {
    final entries = indices.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (_, controller) => Container(
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
                  'All Indices',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: entries.length,
                itemBuilder: (_, i) {
                  final q = entries[i].value;
                  final clr = q.isPositive ? AppColors.green : AppColors.red;
                  return ListTile(
                    title: Text(
                      q.symbol,
                      style: const TextStyle(
                        fontFamily: 'Syne',
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    subtitle: Text(
                      q.changePctStr,
                      style: TextStyle(
                        fontFamily: 'Space Mono',
                        fontSize: 11,
                        color: clr,
                      ),
                    ),
                    trailing: Text(
                      q.priceStr,
                      style: const TextStyle(
                        fontFamily: 'Space Mono',
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
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
}

class _MarketInsightsPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final m = IntelligenceEngine.marketInsights();
    final sentClr = m.marketSentiment == 'Bullish'
        ? AppColors.green
        : m.marketSentiment == 'Bearish'
            ? AppColors.red
            : AppColors.amber;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GlassCard(
        accent: sentClr,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.insights_rounded, color: sentClr, size: 18),
              const SizedBox(width: 8),
              const Text(
                'AI Market Insights',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                m.marketSentiment.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'Space Mono',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: sentClr,
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Text(
              m.summary,
              style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.5),
            ),
            const SizedBox(height: 12),
            _MarketInsightRow('Strongest sector', m.strongestSector),
            _MarketInsightRow('Weakest sector', m.weakestSector),
            if (m.mostBullishStock != null)
              _MarketInsightRow('Most bullish', m.mostBullishStock!),
            if (m.mostBearishStock != null)
              _MarketInsightRow('Most bearish', m.mostBearishStock!),
            if (m.topGainers.isNotEmpty)
              _MarketInsightRow(
                'Top gainer',
                '${m.topGainers.first.symbol} ${m.topGainers.first.changePctStr}',
              ),
            if (m.topLosers.isNotEmpty)
              _MarketInsightRow(
                'Top loser',
                '${m.topLosers.first.symbol} ${m.topLosers.first.changePctStr}',
              ),
            if (m.newsSentiment.articleCount > 0) ...[
              const SizedBox(height: 6),
              Text(
                'News: ${m.newsSentiment.summary}',
                style: TextStyle(
                  fontFamily: 'Space Mono',
                  fontSize: 9,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MarketInsightRow extends StatelessWidget {
  final String label;
  final String value;
  const _MarketInsightRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Space Mono',
                fontSize: 9,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Space Mono',
              fontSize: 10,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
