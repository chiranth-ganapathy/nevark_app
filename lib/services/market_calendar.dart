/// NSE market calendar using India Standard Time (IST), not device local time.
class MarketCalendar {
  MarketCalendar._();

  static const Duration _istOffset = Duration(hours: 5, minutes: 30);
  static const int _openMinutes = 9 * 60 + 15; // 9:15 AM
  static const int _closeMinutes = 15 * 60 + 30; // 3:30 PM

  static const Set<String> nseHolidays = {
    '2025-01-26',
    '2025-02-26',
    '2025-03-14',
    '2025-03-31',
    '2025-04-10',
    '2025-04-14',
    '2025-04-18',
    '2025-05-01',
    '2025-08-15',
    '2025-08-27',
    '2025-10-02',
    '2025-10-20',
    '2025-10-21',
    '2025-11-05',
    '2025-12-25',
    '2026-01-26',
    '2026-03-03',
    '2026-03-26',
    '2026-03-27',
    '2026-04-03',
    '2026-04-14',
    '2026-04-21',
    '2026-05-01',
    '2026-05-28',
    '2026-06-26',
    '2026-09-14',
    '2026-10-02',
    '2026-10-20',
    '2026-11-10',
    '2026-11-24',
    '2026-12-25',
  };

  /// Wall-clock components for IST, stored in a UTC-labelled [DateTime].
  static DateTime get istNow {
    final ms =
        DateTime.now().toUtc().millisecondsSinceEpoch + _istOffset.inMilliseconds;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  static String get dateKey {
    final t = istNow;
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  static int get minutesSinceMidnight {
    final t = istNow;
    return t.hour * 60 + t.minute;
  }

  static bool get isWeekend {
    final w = istNow.weekday;
    return w == DateTime.saturday || w == DateTime.sunday;
  }

  static bool get isHoliday => nseHolidays.contains(dateKey);

  /// NSE regular session: 9:15 AM – 3:30 PM IST (inclusive open, exclusive close).
  static bool get isWithinSession {
    final m = minutesSinceMidnight;
    return m >= _openMinutes && m < _closeMinutes;
  }

  static bool get isNseOpen => !isWeekend && !isHoliday && isWithinSession;

  static String get sessionLabel {
    if (isWeekend) return 'Market Closed — Weekend';
    if (isHoliday) return 'Market Closed — NSE Holiday';
    if (isWithinSession) return 'Market Open';
    if (minutesSinceMidnight < _openMinutes) {
      return 'Market opens at 9:15 AM IST';
    }
    return 'Market Closed — After hours (3:30 PM IST)';
  }
}
