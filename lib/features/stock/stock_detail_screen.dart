import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/stock_quote.dart';
import '../../services/api_service.dart';
import '../../services/market_store.dart';
import '../../services/prediction_service.dart';
import '../../core/config/display_mode.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/glass_card.dart';
import '../../services/intelligence/intelligence_engine.dart';

class StockDetailScreen extends StatefulWidget {
  final StockQuote quote;
  const StockDetailScreen({super.key, required this.quote});
  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  StockQuote? _quote;
  StockPrediction? _pred;
  StockIntelligence? _intel;
  String? _error;
  StreamSubscription<MarketSnapshot>? _sub;

  @override
  void initState() {
    super.initState();
    _quote = widget.quote.ltp > 0 ? widget.quote : null;
    _pred = _quote != null ? StockPrediction.fromQuote(_quote!) : null;
    _intel = _quote != null ? StockIntelligence.fromQuote(_quote!) : null;
    _sub = ApiService.streamMarket().listen((_) => _sync());
    _sync();
  }

  void _sync() {
    final q = MarketStore.instance.quote(widget.quote.symbol);
    if (q != null && q.ltp > 0) {
      setState(() {
        _quote = q;
        _pred = MarketStore.instance.prediction(q.symbol) ??
            StockPrediction.fromQuote(q);
        _intel = IntelligenceEngine.stock(q.symbol);
        _error = null;
      });
    } else if (_quote == null) {
      setState(() {
        _error = MarketStore.instance.lastError ?? 'Live quote unavailable';
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_quote == null || _pred == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          title: Text(widget.quote.symbol),
        ),
        body: _error != null
            ? AppErrorState(
                message: _error!,
                onRetry: _sync,
              )
            : const AppLoadingState(message: 'Loading live quote…'),
      );
    }

    final q = _quote!;
    final pred = _pred!;
    final ind = pred.signal.indicators;
    final fc = pred.forecast;
    final sigClr = pred.signalStr == 'BUY'
        ? AppColors.green
        : pred.signalStr == 'SELL'
            ? AppColors.red
            : AppColors.amber;
    final rskClr = pred.risk == 'Low'
        ? AppColors.green
        : pred.risk == 'High'
            ? AppColors.red
            : AppColors.amber;
    final pClr = q.isPositive ? AppColors.green : AppColors.red;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Row(children: [
          Text(
            q.symbol,
            style: const TextStyle(
              fontFamily: 'Syne',
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          if (ApiService.marketInfo.isOpen)
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: AppColors.green,
                shape: BoxShape.circle,
              ),
            ),
        ]),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: DisplayMode.isProfessional,
            builder: (_, pro, _) => IconButton(
              tooltip: pro ? 'Switch to Beginner' : 'Switch to Professional',
              icon: Icon(
                pro ? Icons.school_rounded : Icons.analytics_outlined,
                color: AppColors.cyan,
              ),
              onPressed: () async {
                await DisplayMode.setProfessional(!pro);
              },
            ),
          ),
        ],
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: DisplayMode.isProfessional,
        builder: (context, isPro, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _modeChip(isPro),
          Text(
            q.priceStr,
            style: const TextStyle(
              fontFamily: 'Syne',
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Row(children: [
            Icon(
              q.isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 14,
              color: pClr,
            ),
            const SizedBox(width: 4),
            Text(
              '${q.changeStr}  (${q.changePctStr})',
              style: TextStyle(
                fontFamily: 'Space Mono',
                fontSize: 13,
                color: pClr,
                fontWeight: FontWeight.w700,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _OhlcItem('OPEN', q.open),
                _OhlcItem('HIGH', q.high, color: AppColors.green),
                _OhlcItem('LOW', q.low, color: AppColors.red),
                _OhlcItem('PREV', q.close),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _infoRow('Volume', _vol(q.volume)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: sigClr.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: sigClr.withOpacity(0.3), width: 1.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI SIGNAL',
                        style: TextStyle(
                          fontFamily: 'Space Mono',
                          fontSize: 10,
                          color: sigClr.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pred.signalStr,
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: sigClr,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        pred.reason,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '${pred.confidence}%',
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: sigClr,
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: rskClr.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${pred.risk} Risk',
                        style: TextStyle(
                          fontFamily: 'Space Mono',
                          fontSize: 10,
                          color: rskClr,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!isPro && _intel != null) ...[
            const SizedBox(height: 16),
            GlassCard(
              accent: sigClr,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BEGINNER INSIGHTS',
                    style: TextStyle(
                      fontFamily: 'Space Mono',
                      fontSize: 10,
                      color: sigClr.withValues(alpha: 0.8),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _insightBlock('What happened?', _intel!.whatHappened),
                  _insightBlock('Why?', _intel!.why),
                  _insightBlock('What should I do?', _intel!.actionHint),
                  _insightBlock('Risk level', '${pred.risk} — ${pred.whatToWatch}'),
                ],
              ),
            ),
          ],
          if (isPro) ...[
          const SizedBox(height: 14),
          _CardSection('Technical Indicators', [
            _metricRow('RSI (14)', ind.rsi.toStringAsFixed(1), ind.rsiLabel),
            if (_intel != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Text(
                  _intel!.narratives.rsi,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    height: 1.5,
                  ),
                ),
              ),
            _metricRow('EMA9', '₹${ind.ema9.toStringAsFixed(2)}', pred.maLabel),
            if (_intel != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Text(
                  _intel!.narratives.ema,
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.5),
                ),
              ),
            _metricRow('SMA50', '₹${ind.sma50.toStringAsFixed(2)}', ''),
            _metricRow('MACD', ind.macd.toStringAsFixed(2), ind.macdLabel),
            if (_intel != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Text(
                  _intel!.narratives.macd,
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.5),
                ),
              ),
            _metricRow('ATR', ind.atr.toStringAsFixed(2), ''),
            if (_intel != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: Text(
                  _intel!.narratives.atr,
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.5),
                ),
              ),
            _metricRow(
              'Bollinger',
              '₹${ind.bbLower.toStringAsFixed(0)} – ₹${ind.bbUpper.toStringAsFixed(0)}',
              '',
            ),
            if (_intel != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Text(
                  _intel!.narratives.bollinger,
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.5),
                ),
              ),
            _metricRow('Volume', ind.volumeLabel, ''),
            if (_intel != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Text(
                  _intel!.narratives.volume,
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.5),
                ),
              ),
            if (_intel != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Text(
                  _intel!.narratives.volatility,
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.5),
                ),
              ),
          ]),
          const SizedBox(height: 14),
          _CardSection('Forecast', [
            _forecastRow('5-Day', fc.price5dStr, fc.trend),
            _forecastRow(
              '10-Day',
              fc.price10dStr,
              'Range ±₹${(fc.upperBand - fc.lowerBand).abs().toStringAsFixed(0)}',
            ),
            _forecastRow('30-Day', fc.price30dStr, 'Conf ${fc.confStr}'),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'Trend: ${fc.trend}',
                style: TextStyle(
                  fontFamily: 'Space Mono',
                  fontSize: 11,
                  color: fc.trend == 'Uptrend'
                      ? AppColors.green
                      : fc.trend == 'Downtrend'
                          ? AppColors.red
                          : AppColors.amber,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ]),
          ],
          const SizedBox(height: 14),
          _CardSection("Today's Range", [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₹${q.low.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontFamily: 'Space Mono',
                          fontSize: 12,
                          color: AppColors.red,
                        ),
                      ),
                      Text(
                        '₹${q.high.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontFamily: 'Space Mono',
                          fontSize: 12,
                          color: AppColors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                    ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: q.high > q.low ? (q.ltp - q.low) / (q.high - q.low) : 0.5,
                      backgroundColor: AppColors.red.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation(AppColors.green),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.amber.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.amber.withOpacity(0.2)),
            ),
            child: Text(
              kSebiDisclaimer,
              style: TextStyle(
                fontFamily: 'Space Mono',
                fontSize: 10,
                color: AppColors.amber.withOpacity(0.8),
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
      ),
    );
  }

  Widget _modeChip(bool isPro) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.cyan.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.cyan.withValues(alpha: 0.35)),
          ),
          child: Text(
            isPro ? 'Professional mode' : 'Beginner mode',
            style: TextStyle(
              fontFamily: 'Space Mono',
              fontSize: 10,
              color: AppColors.cyan,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );

  static String _vol(int v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return '$v';
  }

  Widget _insightBlock(String title, String body) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontFamily: 'Space Mono',
                fontSize: 9,
                color: AppColors.cyan.withOpacity(0.9),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              body,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                height: 1.55,
              ),
            ),
          ],
        ),
      );

  Widget _infoRow(String label, String value) => Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Space Mono',
              fontSize: 10,
              color: AppColors.textMuted,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Space Mono',
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );

  Widget _metricRow(String label, String value, String tag) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Space Mono',
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Space Mono',
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (tag.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                tag,
                style: TextStyle(
                  fontFamily: 'Space Mono',
                  fontSize: 9,
                  color: AppColors.cyan,
                ),
              ),
            ],
          ],
        ),
      );

  Widget _forecastRow(String label, String price, String sub) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Space Mono',
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: const TextStyle(
                    fontFamily: 'Syne',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  sub,
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
      );
}

class _OhlcItem extends StatelessWidget {
  final String label;
  final double value;
  final Color? color;
  const _OhlcItem(this.label, this.value, {this.color});
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Space Mono',
              fontSize: 9,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '₹${value.toStringAsFixed(0)}',
            style: TextStyle(
              fontFamily: 'Space Mono',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color ?? Colors.white,
            ),
          ),
        ],
      );
}

class _CardSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _CardSection(this.title, this.children);
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'Space Mono',
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Divider(color: AppColors.cardBorder, height: 1),
            ...children,
          ],
        ),
      );
}
