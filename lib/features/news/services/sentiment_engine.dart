// lib/features/news/services/sentiment_engine.dart

import '../models/news_item.dart';

class SentimentResult {
  final Sentiment sentiment;
  final int score; // -100 to +100

  const SentimentResult(this.sentiment, this.score);
}

class SentimentEngine {
  // ── Positive signal words ────────────────────────────────────────────────
  static const _positiveWords = {
    'gain', 'gains', 'gained', 'gaining',
    'growth', 'grow', 'grew', 'growing',
    'profit', 'profits', 'profitable',
    'bullish', 'bull',
    'surge', 'surged', 'surging', 'surges',
    'buy', 'buying', 'buyers',
    'strong', 'strength', 'stronger', 'strongest',
    'record', 'records',
    'upgrade', 'upgraded', 'upgrades',
    'beat', 'beats', 'outperform', 'outperformed',
    'estimates', // combined with beat
    'rally', 'rallied', 'rallying',
    'rise', 'rose', 'risen', 'rising',
    'up', 'upside', 'uptick', 'uptrend',
    'positive', 'positively',
    'opportunity', 'opportunities',
    'high', 'highs', 'all-time',
    'recover', 'recovery', 'recovered',
    'momentum', 'accelerate', 'accelerated',
    'boom', 'booming', 'robust',
    'expansion', 'expanding',
    'partnership', 'deal', 'contract', 'win', 'wins',
    'dividend', 'buyback',
    'ai', 'innovation',
  };

  // ── Negative signal words ────────────────────────────────────────────────
  static const _negativeWords = {
    'loss', 'losses', 'losing',
    'fall', 'falls', 'fell', 'fallen', 'falling',
    'decline', 'declined', 'declining', 'declines',
    'bearish', 'bear',
    'drop', 'dropped', 'dropping', 'drops',
    'sell', 'selling', 'sellers',
    'weak', 'weakness', 'weaker', 'weakest',
    'crash', 'crashed', 'crashing',
    'downgrade', 'downgraded', 'downgrades',
    'miss', 'missed', 'misses',
    'down', 'downside', 'downtick', 'downtrend',
    'negative', 'negatively',
    'risk', 'risks', 'risky',
    'low', 'lows',
    'plunge', 'plunged', 'plunging',
    'slump', 'slumped', 'slumping',
    'concern', 'concerns', 'worried', 'worry', 'worries',
    'pressure', 'pressured',
    'warning', 'warn', 'warned',
    'debt', 'default',
    'lawsuit', 'penalty', 'fine', 'probe', 'investigation',
    'cut', 'cuts', 'layoff', 'layoffs',
    'headwind', 'headwinds',
    'contraction', 'contracting',
  };

  /// Analyse a text blob (title + description) and return sentiment + score.
  static SentimentResult analyse(String text) {
    if (text.trim().isEmpty) return const SentimentResult(Sentiment.neutral, 0);

    final words = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z\s-]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    int positiveHits = 0;
    int negativeHits = 0;

    for (final word in words) {
      if (_positiveWords.contains(word)) positiveHits++;
      if (_negativeWords.contains(word)) negativeHits++;
    }

    // Special compound boost: "beat estimates" / "miss estimates"
    final lower = text.toLowerCase();
    if (lower.contains('beat estimates') || lower.contains('beats estimates')) {
      positiveHits += 2;
    }
    if (lower.contains('miss estimates') || lower.contains('missed estimates')) {
      negativeHits += 2;
    }

    final net = positiveHits - negativeHits;
    // Normalise to -100..+100; cap individual signal count to 10 for scale
    final rawScore = (net / 10).clamp(-1.0, 1.0);
    final score = (rawScore * 100).round();

    Sentiment sentiment;
    if (score >= 10) {
      sentiment = Sentiment.positive;
    } else if (score <= -10) {
      sentiment = Sentiment.negative;
    } else {
      sentiment = Sentiment.neutral;
    }

    return SentimentResult(sentiment, score);
  }
}
