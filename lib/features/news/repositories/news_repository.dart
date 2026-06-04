// lib/features/news/repositories/news_repository.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/news_item.dart';
import '../services/news_pipeline_log.dart';
import '../services/news_service.dart';

final newsRepositoryProvider =
    AsyncNotifierProvider<NewsRepository, List<NewsItem>>(
  NewsRepository.new,
);

class NewsRepository extends AsyncNotifier<List<NewsItem>> {
  @override
  Future<List<NewsItem>> build() async {
    ref.keepAlive();
    NewsPipelineLog.state('build() start');
    try {
      final items = await NewsService.fetchAll();
      NewsPipelineLog.state('build() done', count: items.length);
      if (items.isEmpty) {
        NewsPipelineLog.i('build() got 0 items — forcing refresh');
        await NewsService.clearCache();
        final retry = await NewsService.fetchAll(forceRefresh: true);
        NewsPipelineLog.state('build() retry', count: retry.length);
        return retry;
      }
      return items;
    } catch (e) {
      NewsPipelineLog.state('build() failed', error: e.toString());
      rethrow;
    }
  }

  Future<void> refresh() async {
    NewsPipelineLog.state('refresh() start');
    state = const AsyncValue.loading();
    await NewsService.clearCache();
    state = await AsyncValue.guard(
      () async {
        final items = await NewsService.fetchAll(forceRefresh: true);
        NewsPipelineLog.state('refresh() done', count: items.length);
        return items;
      },
    );
    state.whenOrNull(
      data: (d) => NewsPipelineLog.state('refresh() UI state', count: d.length),
      error: (e, _) => NewsPipelineLog.state('refresh() UI error', error: '$e'),
    );
  }
}

final allNewsProvider = Provider<AsyncValue<List<NewsItem>>>((ref) {
  return ref.watch(newsRepositoryProvider);
});

final filteredNewsProvider =
    Provider.family<AsyncValue<List<NewsItem>>, String>((ref, sector) {
  final all = ref.watch(newsRepositoryProvider);
  if (sector == 'All') return all;

  return all.when(
    data: (items) {
      final filtered = items
          .where((n) =>
              n.sector.toLowerCase() == sector.toLowerCase() ||
              (sector == 'Real Estate' && n.sector == 'Realty') ||
              (sector == 'Finance' &&
                  (n.sector == 'Finance' || n.sector == 'Banking')))
          .toList();
      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

final positiveNewsProvider = Provider<AsyncValue<List<NewsItem>>>((ref) {
  return ref.watch(newsRepositoryProvider).whenData(
        (items) => (items.toList()
              ..sort((a, b) => b.sentimentScore.compareTo(a.sentimentScore)))
            .take(10)
            .toList(),
      );
});

final negativeNewsProvider = Provider<AsyncValue<List<NewsItem>>>((ref) {
  return ref.watch(newsRepositoryProvider).whenData(
        (items) => (items.toList()
              ..sort((a, b) => a.sentimentScore.compareTo(b.sentimentScore)))
            .take(10)
            .toList(),
      );
});

/// Articles mentioning tracked NSE symbols (not only non-empty relatedStocks).
final stockNewsProvider = Provider<AsyncValue<List<NewsItem>>>((ref) {
  return ref.watch(newsRepositoryProvider).whenData((items) {
    return items
        .where((n) =>
            n.relatedStocks.isNotEmpty ||
            n.title.toUpperCase().contains('NIFTY') ||
            n.title.toUpperCase().contains('SENSEX'))
        .toList();
  });
});

final trendingNewsProvider = Provider<AsyncValue<List<NewsItem>>>((ref) {
  return ref.watch(newsRepositoryProvider).whenData(
        (items) => items.take(10).toList(),
      );
});
