/// Counts consecutive active days ending today (or yesterday, so a streak
/// isn't lost just because today hasn't been logged yet), where a day counts
/// as active once at least [minSecondsForActiveDay] were logged.
int calculateCurrentStreak(Map<String, int> dailySeconds, {int minSecondsForActiveDay = 60}) {
  bool isActive(DateTime day) {
    final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return (dailySeconds[key] ?? 0) >= minSecondsForActiveDay;
  }

  final today = DateTime.now();
  DateTime cursor = today;
  if (!isActive(today)) {
    cursor = today.subtract(const Duration(days: 1));
    if (!isActive(cursor)) return 0;
  }

  int streak = 0;
  while (isActive(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}
