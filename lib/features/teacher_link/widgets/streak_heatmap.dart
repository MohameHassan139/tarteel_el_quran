import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/app_colors.dart';
import '../teacher_link_models.dart';
import '../utils/streak_utils.dart';

/// GitHub-contribution-style density grid: one column per week, one cell per
/// day, color intensity mapped to minutes read that day.
class StreakHeatmap extends StatelessWidget {
  final Map<String, DailyActivity> dailyActivity;
  final int weeksToShow;

  const StreakHeatmap({super.key, required this.dailyActivity, this.weeksToShow = 10});

  Color _colorFor(int seconds, bool isDark) {
    final base = AppColors.primary;
    if (seconds <= 0) return isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05);
    final minutes = seconds / 60.0;
    final intensity = (minutes / 30.0).clamp(0.25, 1.0); // 30+ min/day = full intensity
    return base.withValues(alpha: intensity);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Columns are Sunday→Saturday weeks; the LAST column is the current week
    // (it contains today, later days are left blank). Built with calendar
    // arithmetic (not Duration) so DST changes can't skip/duplicate a day.
    final daysSinceSunday = today.weekday % 7;
    final gridStart = DateTime(today.year, today.month, today.day - daysSinceSunday - weeksToShow * 7);

    final dailySeconds = dailyActivity.map((k, v) => MapEntry(k, v.seconds));
    final streak = calculateCurrentStreak(dailySeconds);

    final weeks = <List<DateTime>>[];
    for (int w = 0; w < weeksToShow + 1; w++) {
      weeks.add(List.generate(7, (d) => DateTime(gridStart.year, gridStart.month, gridStart.day + w * 7 + d)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.local_fire_department, color: Colors.orange, size: 20),
            const SizedBox(width: 6),
            Text(
              'teacher_link_current_streak'.trParams({'days': '$streak'}),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: Row(
            children: weeks.map((week) {
              return Padding(
                padding: const EdgeInsets.only(left: 3),
                child: Column(
                  children: week.map((day) {
                    if (day.isAfter(today)) {
                      return const Padding(padding: EdgeInsets.only(bottom: 3), child: SizedBox(width: 14, height: 14));
                    }
                    final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
                    final seconds = dailySeconds[key] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: _colorFor(seconds, isDark),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
