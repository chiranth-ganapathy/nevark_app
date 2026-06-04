import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/config/display_mode.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/models/stock_quote.dart';
import '../../services/api_service.dart';
import '../../services/market_store.dart';
import '../../services/prediction_service.dart';
import '../../services/intelligence/intelligence_engine.dart';
import '../stock/stock_detail_screen.dart';

class SectorDetailScreen extends StatefulWidget {
  final SectorData sector;
  const SectorDetailScreen({super.key, required this.sector});

  @override
  State<SectorDetailScreen> createState() => _SectorDetailScreenState();
}

class _SectorDetailScreenState extends State<SectorDetailScreen> {
  late SectorData _sector;
  late List<StockQuote> _stocks;
  SectorPrediction? _pred;
  SectorIntelligence? _intel;
  StreamSubscription<MarketSnapshot>? _sub;

  @override
  void initState() {
    super.initState();
    _sector = widget.sector;
    _stocks = widget.sector.stocks;
    _pred = MarketStore.instance.sector(widget.sector.name);
    _intel = SectorIntelligence.forSector(widget.sector.name);
    _sub = ApiService.streamMarket().listen((_) => _sync());
    _sync();
  }

  void _sync() {
    if (!mounted) return;
    final sd = MarketStore.instance.sectorData(widget.sector.name);
    final pred = MarketStore.instance.sector(widget.sector.name);
    setState(() {
      _sector = sd;
      _stocks = sd.stocks;
      _pred = pred;
      _intel = SectorIntelligence.forSector(widget.sector.name);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _sector;
    final pred = _pred;
    final clr = s.trend == 'BULLISH'
        ? AppColors.green
        : s.trend == 'BEARISH'
            ? AppColors.red
            : AppColors.amber;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          s.name,
          style: const TextStyle(
            fontFamily: 'Syne',
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
      body: _stocks.isEmpty
          ? AppEmptyState(
              title: 'No sector data yet',
              subtitle: MarketStore.instance.lastError ??
                  'Live quotes appear when the market is open.',
              icon: Icons.pie_chart_outline_rounded,
            )
          : ValueListenableBuilder<bool>(
              valueListenable: DisplayMode.isProfessional,
              builder: (context, isPro, _) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: clr.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: clr.withOpacity(0.3), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SECTOR TREND',
                              style: TextStyle(
                                fontFamily: 'Space Mono',
                                fontSize: 10,
                                color: clr.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              s.trend,
                              style: TextStyle(
                                fontFamily: 'Syne',
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: clr,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Average move today: ${s.avgChangeStr}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                                height: 1.5,
                              ),
                            ),
                            if (s.reason.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                s.reason,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            '${s.confidence}%',
                            style: TextStyle(
                              fontFamily: 'Syne',
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: clr,
                            ),
                          ),
                          Text(
                            'confidence',
                            style: TextStyle(
                              fontFamily: 'Space Mono',
                              fontSize: 9,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: clr.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              s.signal,
                              style: TextStyle(
                                fontFamily: 'Space Mono',
                                fontSize: 11,
                                color: clr,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_intel != null) ...[
                  const SizedBox(height: 14),
                  if (isPro)
                    _sectorInsightCard(_intel!, pro: true)
                  else
                    _sectorBeginnerCard(_intel!, s),
                ],
                if (isPro) ...[
                  const SizedBox(height: 14),
                  _metricsGrid(s, pred),
                ],
                const SizedBox(height: 20),
                if (_stocks.isNotEmpty) ...[
                  _sectionTitle('Stock Performance Today'),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      children: _stocks.map((q) => _PerfBar(quote: q)).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                _sectionTitle('All Stocks in ${s.name}'),
                ..._stocks.map(
                  (q) => GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StockDetailScreen(quote: q),
                      ),
                    ),
                    child: _SectorStockCard(quote: q),
                  ),
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 32),
              ],
            ),
          ),
    );
  }

  Widget _sectorBeginnerCard(SectorIntelligence intel, SectorData s) {
    final risk = s.confidence >= 70
        ? 'Moderate'
        : s.confidence >= 50
            ? 'Elevated'
            : 'High — sector signals are mixed';
    return GlassCard(
      accent: s.trend == 'BULLISH'
          ? AppColors.green
          : s.trend == 'BEARISH'
              ? AppColors.red
              : AppColors.amber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BEGINNER INSIGHTS',
            style: TextStyle(
              fontFamily: 'Space Mono',
              fontSize: 10,
              color: AppColors.cyan.withValues(alpha: 0.85),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          _beginnerRow('What happened?', intel.whatHappened),
          _beginnerRow('Why?', s.reason.isNotEmpty ? s.reason : intel.prediction.reason),
          _beginnerRow('What should I do?', intel.actionHint),
          _beginnerRow('Risk level', '$risk — ${s.signal} bias at ${s.confidence}% confidence'),
        ],
      ),
    );
  }

  Widget _beginnerRow(String label, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Syne',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              body,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
          ],
        ),
      );

  Widget _metricsGrid(SectorData s, SectorPrediction? pred) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            _metricTile('Sector RSI', s.avgRsi.toStringAsFixed(0)),
            _metricTile('Strength', s.strength),
            _metricTile('Momentum', s.momentum),
            if (pred != null)
              _metricTile(
                'BUY signals',
                '${pred.stockPredictions.where((p) => p.signalStr == 'BUY').length}/${pred.stockPredictions.length}',
              ),
          ],
        ),
      );

  Widget _metricTile(String label, String value) => Expanded(
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Syne',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Space Mono',
                fontSize: 8,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );

  Widget _sectorInsightCard(SectorIntelligence intel, {bool pro = false}) {
    final p = intel.prediction;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SECTOR INTELLIGENCE',
            style: TextStyle(
              fontFamily: 'Space Mono',
              fontSize: 10,
              color: AppColors.cyan.withOpacity(0.8),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(intel.whatHappened,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.5)),
          const SizedBox(height: 8),
          Text(intel.actionHint,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.5)),
          if (intel.topStocks.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Top: ${intel.topStocks.map((q) => "${q.symbol} ${q.changePctStr}").join(" · ")}',
                style: const TextStyle(fontFamily: 'Space Mono', fontSize: 10, color: AppColors.green)),
          ],
          if (intel.weakStocks.isNotEmpty &&
              intel.weakStocks.first.changePercent < 0) ...[
            const SizedBox(height: 6),
            Text(
                'Weak: ${intel.weakStocks.map((q) => "${q.symbol} ${q.changePctStr}").join(" · ")}',
                style: const TextStyle(fontFamily: 'Space Mono', fontSize: 10, color: AppColors.red)),
          ],
          if (intel.newsSentiment.articleCount > 0) ...[
            const SizedBox(height: 8),
            Text('News: ${intel.newsSentiment.summary}',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.4)),
          ],
          const SizedBox(height: 6),
          Text('Signal ${p.signal} · ${p.confidence}% confidence',
              style: TextStyle(fontFamily: 'Space Mono', fontSize: 10, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          t,
          style: TextStyle(
            fontFamily: 'Space Mono',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
          ),
        ),
      );
}

class _PerfBar extends StatelessWidget {
  final StockQuote quote;
  const _PerfBar({required this.quote});

  @override
  Widget build(BuildContext context) {
    final pct = quote.changePercent;
    final clr = pct >= 0 ? AppColors.green : AppColors.red;
    final barW = (pct.abs().clamp(0.0, 5.0) / 5.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              quote.symbol,
              style: const TextStyle(
                fontFamily: 'Space Mono',
                fontSize: 11,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: barW,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: clr,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 60,
            child: Text(
              quote.changePctStr,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'Space Mono',
                fontSize: 11,
                color: clr,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectorStockCard extends StatelessWidget {
  final StockQuote quote;
  const _SectorStockCard({required this.quote});

  @override
  Widget build(BuildContext context) {
    final pred = StockPrediction.fromQuote(quote);
    final sigClr = pred.signalStr == 'BUY'
        ? AppColors.green
        : pred.signalStr == 'SELL'
            ? AppColors.red
            : AppColors.amber;
    final prcClr = quote.isPositive ? AppColors.green : AppColors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quote.symbol,
                      style: const TextStyle(
                        fontFamily: 'Syne',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'H:₹${quote.high.toStringAsFixed(0)}  '
                      'L:₹${quote.low.toStringAsFixed(0)}  '
                      'O:₹${quote.open.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontFamily: 'Space Mono',
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    quote.priceStr,
                    style: const TextStyle(
                      fontFamily: 'Syne',
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    quote.changePctStr,
                    style: TextStyle(
                      fontFamily: 'Space Mono',
                      fontSize: 11,
                      color: prcClr,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: sigClr.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: sigClr.withOpacity(0.3)),
                ),
                child: Text(
                  pred.signalStr,
                  style: TextStyle(
                    fontFamily: 'Space Mono',
                    fontSize: 10,
                    color: sigClr,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            pred.reason,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
