import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/app_colors.dart';
import '../teacher_link_models.dart';

const Color kMushafColor = AppColors.primary;
const Color kHifzColor = Colors.blueAccent;
const Color kAudioColor = Colors.teal;

/// Minutes-per-day stacked bar chart (Mushaf/Hifz/Audio Hub), fed by a
/// date(YYYY-MM-DD)->DailyActivity map (the synced daily_ward docs). Days
/// written before the per-feature breakdown existed render as a single
/// muted bar using just the plain total.
class DailyTimeBarChart extends StatelessWidget {
  final Map<String, DailyActivity> dailyActivity;
  final int daysToShow;

  const DailyTimeBarChart({super.key, required this.dailyActivity, this.daysToShow = 14});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(daysToShow, (i) => now.subtract(Duration(days: daysToShow - 1 - i)));

    double maxMinutes = 1;
    final groups = <BarChartGroupData>[];
    for (int i = 0; i < days.length; i++) {
      final key = '${days[i].year}-${days[i].month.toString().padLeft(2, '0')}-${days[i].day.toString().padLeft(2, '0')}';
      final activity = dailyActivity[key] ?? DailyActivity.zero;
      final rod = _buildRod(activity);
      if (rod.toY > maxMinutes) maxMinutes = rod.toY;
      groups.add(BarChartGroupData(x: i, barRods: [rod]));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 160,
          child: BarChart(
            BarChartData(
              maxY: maxMinutes * 1.2,
              barGroups: groups,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= days.length) return const SizedBox.shrink();
                      final labelEvery = (days.length / 8).ceil().clamp(1, days.length);
                      if (idx % labelEvery != 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('${days[idx].day}/${days[idx].month}', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final d = days[group.x.toInt()];
                    return BarTooltipItem(
                      '${d.year}/${d.month}/${d.day}\n${rod.toY.round()} min',
                      const TextStyle(color: Colors.white, fontSize: 11),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            _legendDot(kMushafColor, 'teacher_link_feature_mushaf'.tr),
            _legendDot(kHifzColor, 'teacher_link_feature_hifz'.tr),
            _legendDot(kAudioColor, 'teacher_link_feature_audio'.tr),
          ],
        ),
      ],
    );
  }

  BarChartRodData _buildRod(DailyActivity activity) {
    if (activity.hasBreakdown) {
      final mushaf = activity.mushafSeconds / 60.0;
      final hifz = activity.hifzSeconds / 60.0;
      final audio = activity.audioSeconds / 60.0;
      final total = mushaf + hifz + audio;
      return BarChartRodData(
        toY: total,
        width: 10,
        borderRadius: BorderRadius.circular(4),
        rodStackItems: [
          BarChartRodStackItem(0, mushaf, kMushafColor),
          BarChartRodStackItem(mushaf, mushaf + hifz, kHifzColor),
          BarChartRodStackItem(mushaf + hifz, total, kAudioColor),
        ],
      );
    }
    final minutes = activity.seconds / 60.0;
    return BarChartRodData(
      toY: minutes,
      width: 10,
      borderRadius: BorderRadius.circular(4),
      color: AppColors.primary.withValues(alpha: 0.35),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
