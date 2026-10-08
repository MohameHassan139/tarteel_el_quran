/// Counts consecutive active days ending today (or yesterday, so a streak
/// isn't lost just because today hasn't been logged yet), where a day counts
/// as active once at least [minSecondsForActiveDay] were logged.
int calculateCurrentStreak(Map<String, int> dailySeconds, {int minSecondsForActiveDay = 60}) {
  bool isActive(DateTime day) {
    final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return (dailySeconds[key] ?? 0) >= minSecondsForActiveDay;
  }

  final now = DateTime.now();
  // Calendar arithmetic (not Duration) so a DST day can't be skipped.
  DateTime dayBefore(DateTime d) => DateTime(d.year, d.month, d.day - 1);
  final today = DateTime(now.year, now.month, now.day);
  DateTime cursor = today;
  if (!isActive(today)) {
    cursor = dayBefore(today);
    if (!isActive(cursor)) return 0;
  }

  int streak = 0;
  // Hard cap guards against any pathological data (e.g. >10 years of days).
  while (isActive(cursor) && streak < 5000) {
    streak++;
    cursor = dayBefore(cursor);
  }
  return streak;
}
