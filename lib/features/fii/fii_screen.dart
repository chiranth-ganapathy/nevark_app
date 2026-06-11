import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../news/models/news_item.dart';
import '../news/repositories/news_repository.dart';
import '../news/services/fii_dii_intelligence.dart';

class FiiDiiScreen extends ConsumerWidget {
  const FiiDiiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(fiiDiiSnapshotProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: const Text('FII / DII Activity'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(fiiDiiSnapshotProvider),
            icon: Icon(Icons.refresh_rounded, color: AppColors.cyan),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.cyan,
        backgroundColor: AppColors.surface,
        onRefresh: () async => ref.refresh(fiiDiiSnapshotProvider.future),
        child: snapshotAsync.when(
          loading: () => const _LoadingState(),
          error: (error, _) => _ErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(fiiDiiSnapshotProvider),
          ),
          data: (snapshot) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _OverviewCard(snapshot: snapshot),
              const SizedBox(height: 16),
              _InsightCard(snapshot: snapshot),
              const SizedBox(height: 16),
              _SectionLabel('Institutional Flow News', AppColors.cyan),
              const SizedBox(height: 10),
              if (snapshot.newsItems.isEmpty)
                const _EmptyNewsState()
              else
                ...snapshot.newsItems.map((item) => _NewsCard(item: item)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final FiiDiiSnapshot snapshot;

  const _OverviewCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Institutional Flow Summary',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _StatusPill(snapshot.bias, _biasColor(snapshot.bias)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            snapshot.dataSource,
            style: TextStyle(
              fontFamily: 'Space Mono',
              fontSize: 10,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'FII Net Buy/Sell',
                  value: snapshot.fiiDisplay,
                  color: _recordColor(snapshot.fii),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  label: 'DII Net Buy/Sell',
                  value: snapshot.diiDisplay,
                  color: _recordColor(snapshot.dii),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'Daily Institutional Flow',
                  value: snapshot.dailyFlowDisplay,
                  color: _flowColor(snapshot.dailyInstitutionalFlowCrore),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  label: 'Trend',
                  value: snapshot.trend,
                  color: _biasColor(snapshot.bias),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 14, color: AppColors.cyan),
              const SizedBox(width: 8),
              Text(
                'Last updated: ${_formatTimestamp(snapshot.lastUpdated)}',
                style: TextStyle(
                  fontFamily: 'Space Mono',
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final FiiDiiSnapshot snapshot;

  const _InsightCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('Institutional Insights', AppColors.green),
          const SizedBox(height: 10),
          ...snapshot.insights.map(
                (insight) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.circle, size: 7, color: AppColors.green),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          insight,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          if (!snapshot.hasRealData)
            Text(
              'Real FII/DII values are shown only when they are explicitly reported by the configured sources.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                height: 1.45,
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Space Mono',
              fontSize: 9,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Space Mono',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final Color color;

  const _SectionLabel(this.title, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Space Mono',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _NewsCard extends StatelessWidget {
  final NewsItem item;

  const _NewsCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final sentimentColor = _sentimentColor(item.sentiment);
    return GestureDetector(
      onTap: item.url.isEmpty ? null : () => _openUrl(item.url),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(color: sentimentColor, width: 3),
            top: BorderSide(color: AppColors.cardBorder),
            right: BorderSide(color: AppColors.cardBorder),
            bottom: BorderSide(color: AppColors.cardBorder),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _StatusPill(item.sentimentLabel, sentimentColor),
                _StatusPill(item.source, AppColors.cyan),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.45,
              ),
            ),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 12, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  item.timeAgo,
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
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: List.generate(
        4,
        (_) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.error_outline_rounded, size: 44, color: AppColors.red),
        const SizedBox(height: 16),
        const Text(
          'Institutional data unavailable',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Retry'),
          style: TextButton.styleFrom(foregroundColor: AppColors.cyan),
        ),
      ],
    );
  }
}

class _EmptyNewsState extends StatelessWidget {
  const _EmptyNewsState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Text(
        'No institutional-flow headlines are available right now.',
        style: TextStyle(
          fontSize: 11,
          color: AppColors.textMuted,
          height: 1.5,
        ),
      ),
    );
  }
}

Color _biasColor(String bias) {
  switch (bias) {
    case 'Bullish':
      return AppColors.green;
    case 'Bearish':
      return AppColors.red;
    default:
      return AppColors.amber;
  }
}

Color _flowColor(double? value) {
  if (value == null) return AppColors.textMuted;
  if (value > 0) return AppColors.green;
  if (value < 0) return AppColors.red;
  return AppColors.amber;
}

Color _recordColor(InstitutionalFlowRecord? record) {
  if (record == null) return AppColors.textMuted;
  return record.isBuy ? AppColors.green : AppColors.red;
}

Color _sentimentColor(Sentiment sentiment) {
  switch (sentiment) {
    case Sentiment.positive:
      return AppColors.green;
    case Sentiment.negative:
      return AppColors.red;
    case Sentiment.neutral:
      return AppColors.amber;
  }
}

String _formatTimestamp(DateTime? timestamp) {
  if (timestamp == null) return 'Unavailable';
  final local = timestamp.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  final dd = local.day.toString().padLeft(2, '0');
  final mo = local.month.toString().padLeft(2, '0');
  return '$dd/$mo/${local.year} $hh:$mm';
}

Future<void> _openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
