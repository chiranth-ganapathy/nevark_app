// lib/features/news/news_screen.dart
//
// Production-ready News screen for NeVark.
// Design: dark theme + glassmorphism + neon accents — matches existing app style.

// dart:ui removed — all used elements provided by flutter/material.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import 'models/news_item.dart';
import 'repositories/news_repository.dart';
import 'services/news_pipeline_log.dart';

// ── Sector filter chips ────────────────────────────────────────────────────

const List<String> _kSectorFilters = [
  'All',
  'IT',
  'Banking',
  'Pharma',
  'Energy',
  'FMCG',
  'Agriculture',
  'Auto',
  'Finance',
  'Metal',
  'Telecom',
  'Real Estate',
];

// ═══════════════════════════════════════════════════════════════════════════
// NewsScreen
// ═══════════════════════════════════════════════════════════════════════════

class NewsScreen extends ConsumerStatefulWidget {
  const NewsScreen({super.key});

  @override
  ConsumerState<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends ConsumerState<NewsScreen> {
  String _selectedSector = 'All';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final async = ref.read(newsRepositoryProvider);
      if (async.hasError ||
          (async.hasValue && (async.value == null || async.value!.isEmpty))) {
        NewsPipelineLog.ui('init', error: async.hasError);
        ref.read(newsRepositoryProvider.notifier).refresh();
      }
    });
  }

  Future<void> _refresh() async {
    await ref.read(newsRepositoryProvider.notifier).refresh();
  }

  void _setSector(String s) => setState(() => _selectedSector = s);

  @override
  Widget build(BuildContext context) {
    final newsAsync = ref.watch(filteredNewsProvider(_selectedSector));
    final trendingAsync = ref.watch(trendingNewsProvider);
    final positiveAsync = ref.watch(positiveNewsProvider);
    final negativeAsync = ref.watch(negativeNewsProvider);
    final stockAsync = ref.watch(stockNewsProvider);

    ref.listen<AsyncValue<List<NewsItem>>>(newsRepositoryProvider, (prev, next) {
      next.when(
        data: (items) => NewsPipelineLog.ui('listen', count: items.length),
        loading: () => NewsPipelineLog.ui('listen', loading: true),
        error: (_, _) => NewsPipelineLog.ui('listen', error: true),
      );
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.cyan,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── App Bar ────────────────────────────────────────────────
            _NewsAppBar(
              onRefresh: _refresh,
              articleCount: newsAsync.valueOrNull?.length,
            ),

            // ── Sector filter chips ────────────────────────────────────
            SliverToBoxAdapter(
              child: _SectorFilterBar(
                selected: _selectedSector,
                onSelect: _setSector,
              ),
            ),

            // ── Body ──────────────────────────────────────────────────
            newsAsync.when(
              loading: () => SliverToBoxAdapter(child: _ShimmerList()),
              error: (e, _) => SliverToBoxAdapter(
                child: _ErrorState(message: e.toString(), onRetry: _refresh),
              ),
              data: (items) {
                NewsPipelineLog.ui(
                  'build',
                  count: items.length,
                );
                return SliverToBoxAdapter(
                  child: items.isEmpty
                      ? _EmptyState(
                          sector: _selectedSector,
                          onRetry: _refresh,
                        )
                      : _NewsSections(
                          allItems: items,
                          trendingAsync: trendingAsync,
                          positiveAsync: positiveAsync,
                          negativeAsync: negativeAsync,
                          stockAsync: stockAsync,
                          selectedSector: _selectedSector,
                        ),
                );
              },
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// App Bar
// ═══════════════════════════════════════════════════════════════════════════

class _NewsAppBar extends StatelessWidget {
  final VoidCallback onRefresh;
  final int? articleCount;
  const _NewsAppBar({required this.onRefresh, this.articleCount});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      backgroundColor: AppColors.bg,
      elevation: 0,
      pinned: true,
      expandedHeight: 100,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 16, bottom: 12),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Market News',
              style: TextStyle(
                fontFamily: 'Syne',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              articleCount != null && articleCount! > 0
                  ? '$articleCount articles · Yahoo Finance · Live Sentiment'
                  : 'Yahoo Finance · NSE · Live Sentiment',
              style: TextStyle(
                fontFamily: 'Space Mono',
                fontSize: 9,
                color: AppColors.cyan.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: AppColors.cyan),
          tooltip: 'Refresh news',
          onPressed: onRefresh,
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Sector filter bar
// ═══════════════════════════════════════════════════════════════════════════

class _SectorFilterBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const _SectorFilterBar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _kSectorFilters.length,
        separatorBuilder: (_, x) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final sector = _kSectorFilters[i];
          final isSelected = sector == selected;
          return GestureDetector(
            onTap: () => onSelect(sector),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.cyan.withValues(alpha: 0.15)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.cyan : AppColors.cardBorder,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Text(
                sector,
                style: TextStyle(
                  fontFamily: 'Space Mono',
                  fontSize: 11,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.normal,
                  color:
                      isSelected ? AppColors.cyan : AppColors.textMuted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// News Sections layout
// ═══════════════════════════════════════════════════════════════════════════

class _NewsSections extends StatelessWidget {
  final List<NewsItem> allItems;
  final AsyncValue<List<NewsItem>> trendingAsync;
  final AsyncValue<List<NewsItem>> positiveAsync;
  final AsyncValue<List<NewsItem>> negativeAsync;
  final AsyncValue<List<NewsItem>> stockAsync;
  final String selectedSector;

  const _NewsSections({
    required this.allItems,
    required this.trendingAsync,
    required this.positiveAsync,
    required this.negativeAsync,
    required this.stockAsync,
    required this.selectedSector,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),

        // ── Trending (horizontal scroll) ────────────────────────────
        if (selectedSector == 'All') ...[
          _SectionHeader(
              title: 'Trending Now',
              icon: Icons.local_fire_department_rounded,
              iconColor: AppColors.amber),
          trendingAsync.whenOrNull(
                data: (items) => items.isEmpty
                    ? const SizedBox.shrink()
                    : _HorizontalNewsRow(items: items.take(6).toList()),
              ) ??
              const SizedBox.shrink(),
          const SizedBox(height: 16),
        ],

        // ── Latest / filtered news ───────────────────────────────────
        _SectionHeader(
          title: selectedSector == 'All'
              ? 'Latest Market News'
              : '$selectedSector News',
          icon: Icons.article_rounded,
          iconColor: AppColors.cyan,
        ),
        ...allItems
            .take(selectedSector == 'All' ? 8 : 20)
            .map((n) => _NewsCard(item: n)),

        // ── Most Positive ────────────────────────────────────────────
        if (selectedSector == 'All') ...[
          const SizedBox(height: 8),
          _SectionHeader(
              title: 'Most Positive',
              icon: Icons.trending_up_rounded,
              iconColor: AppColors.green),
          positiveAsync.whenOrNull(
                data: (items) => Column(
                  children:
                      items.take(5).map((n) => _NewsCard(item: n)).toList(),
                ),
              ) ??
              const SizedBox.shrink(),
        ],

        // ── Most Negative ────────────────────────────────────────────
        if (selectedSector == 'All') ...[
          const SizedBox(height: 8),
          _SectionHeader(
              title: 'Most Negative',
              icon: Icons.trending_down_rounded,
              iconColor: AppColors.red),
          negativeAsync.whenOrNull(
                data: (items) => Column(
                  children:
                      items.take(5).map((n) => _NewsCard(item: n)).toList(),
                ),
              ) ??
              const SizedBox.shrink(),
        ],

        // ── Stock-Specific ────────────────────────────────────────────
        if (selectedSector == 'All') ...[
          const SizedBox(height: 8),
          _SectionHeader(
              title: 'Stock-Specific News',
              icon: Icons.show_chart_rounded,
              iconColor: AppColors.purple),
          stockAsync.whenOrNull(
                data: (items) => Column(
                  children:
                      items.take(8).map((n) => _NewsCard(item: n)).toList(),
                ),
              ) ??
              const SizedBox.shrink(),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Section Header
// ═══════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;

  const _SectionHeader(
      {required this.title, required this.icon, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Space Mono',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: iconColor,
            letterSpacing: 1.2,
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Horizontal trending row
// ═══════════════════════════════════════════════════════════════════════════

class _HorizontalNewsRow extends StatelessWidget {
  final List<NewsItem> items;
  const _HorizontalNewsRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, i) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _TrendingCard(item: items[i]),
      ),
    );
  }
}

class _TrendingCard extends StatelessWidget {
  final NewsItem item;
  const _TrendingCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final sentColor = _sentimentColor(item.sentiment);

    return GestureDetector(
      onTap: () => _openUrl(item.url),
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: item.imageUrl.isNotEmpty
                  ? Image.network(
                      item.imageUrl,
                      height: 100,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, e, st) => _PlaceholderImage(),
                    )
                  : _PlaceholderImage(),
            ),

            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges
                  Row(children: [
                    _Badge(item.sentimentLabel, sentColor),
                    const SizedBox(width: 6),
                    _Badge(item.sector, AppColors.cyan),
                  ]),
                  const SizedBox(height: 6),
                  // Title
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${item.source}  ·  ${item.timeAgo}',
                    style: TextStyle(
                      fontFamily: 'Space Mono',
                      fontSize: 9,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// News Card (vertical list)
// ═══════════════════════════════════════════════════════════════════════════

class _NewsCard extends StatefulWidget {
  final NewsItem item;
  const _NewsCard({required this.item});

  @override
  State<_NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends State<_NewsCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final sentColor = _sentimentColor(item.sentiment);

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        _openUrl(item.url);
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(color: sentColor, width: 3),
              top: BorderSide(color: AppColors.cardBorder),
              right: BorderSide(color: AppColors.cardBorder),
              bottom: BorderSide(color: AppColors.cardBorder),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Content ────────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badges row
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _Badge(item.sentimentLabel, sentColor),
                          _Badge(item.sector, AppColors.cyan),
                          if (item.relatedStocks.isNotEmpty)
                            _Badge(
                                item.relatedStocks.first, AppColors.purple),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Title
                      Text(
                        item.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Description
                      if (item.description.isNotEmpty)
                        Text(
                          item.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            height: 1.5,
                          ),
                        ),
                      const SizedBox(height: 8),
                      // Source + time
                      Row(children: [
                        Icon(Icons.circle,
                            size: 6, color: sentColor),
                        const SizedBox(width: 6),
                        Text(
                          item.source,
                          style: TextStyle(
                            fontFamily: 'Space Mono',
                            fontSize: 9,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          item.timeAgo,
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
              ),

              // ── Thumbnail ─────────────────────────────────────────
              if (item.imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  child: Image.network(
                    item.imageUrl,
                    width: 90,
                    height: 110,
                    fit: BoxFit.cover,
                    errorBuilder: (_, e, st) => const SizedBox.shrink(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Badge widget
// ═══════════════════════════════════════════════════════════════════════════

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Space Mono',
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Placeholder image
// ═══════════════════════════════════════════════════════════════════════════

class _PlaceholderImage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      width: double.infinity,
      color: AppColors.surface2,
      child: Center(
        child: Icon(Icons.newspaper_rounded,
            color: AppColors.textMuted, size: 32),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Shimmer skeleton
// ═══════════════════════════════════════════════════════════════════════════

class _ShimmerList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surface2,
      child: Column(
        children: List.generate(
          6,
          (_) => Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Error state
// ═══════════════════════════════════════════════════════════════════════════

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 48),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
            ),
            child:
                Icon(Icons.wifi_off_rounded, color: AppColors.red, size: 32),
          ),
          const SizedBox(height: 20),
          const Text(
            'News Unavailable',
            style: TextStyle(
              fontFamily: 'Syne',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message.length > 120 ? '${message.substring(0, 120)}…' : message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Space Mono',
              fontSize: 11,
              color: AppColors.textMuted,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.cyan,
              textStyle: const TextStyle(fontFamily: 'Space Mono'),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Empty state
// ═══════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final String sector;
  final VoidCallback? onRetry;
  const _EmptyState({required this.sector, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 32),
      child: Column(children: [
        Icon(Icons.newspaper_rounded,
            color: AppColors.textMuted, size: 48),
        const SizedBox(height: 16),
        Text(
          sector == 'All'
              ? 'No articles loaded yet'
              : 'No $sector news — try All',
          style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Refresh news'),
            style: TextButton.styleFrom(foregroundColor: AppColors.cyan),
          ),
        ],
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════════

Color _sentimentColor(Sentiment s) {
  switch (s) {
    case Sentiment.positive:
      return AppColors.green;
    case Sentiment.negative:
      return AppColors.red;
    case Sentiment.neutral:
      return AppColors.amber;
  }
}

Future<void> _openUrl(String url) async {
  if (url.isEmpty) {
    NewsPipelineLog.i('Open article skipped: empty URL');
    return;
  }
  final uri = Uri.tryParse(url);
  if (uri == null) {
    NewsPipelineLog.i('Open article failed: invalid URL $url');
    return;
  }
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  NewsPipelineLog.i('Open article: $url → $ok');
}