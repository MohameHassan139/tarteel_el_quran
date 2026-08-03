import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/app_colors.dart';
import '../shared/widgets/offline_banner.dart';
import 'student_detail_controller.dart';
import 'widgets/daily_time_bar_chart.dart';
import 'widgets/streak_heatmap.dart';
import 'widgets/session_timeline_tile.dart';

class StudentDetailScreen extends GetView<StudentDetailController> {
  const StudentDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(controller.studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Obx(() {
              if (!controller.isLiveActivityFresh) return const SizedBox.shrink();
              return _buildLiveActivityBanner(isDark);
            }),
            Obx(() {
              if (controller.isLoadingProfile.value) {
                return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.primary)));
              }
              final p = controller.profile.value;
              if (p == null) {
                return Text('teacher_link_profile_unavailable'.tr, style: TextStyle(color: Colors.grey[500]));
              }
              return Card(
                color: isDark ? AppColors.cardDark : AppColors.cardLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow(Icons.cake_outlined, 'teacher_link_field_age'.tr, '${p.age}'),
                      _infoRow(Icons.phone_outlined, 'teacher_link_field_phone'.tr, p.phone),
                      _infoRow(Icons.chat_outlined, 'teacher_link_field_whatsapp'.tr, p.whatsapp),
                      _infoRow(Icons.family_restroom_outlined, 'teacher_link_field_father_phone'.tr, p.fatherPhone),
                      const Divider(height: 24),
                      _infoRow(Icons.local_fire_department, 'teacher_link_current_streak_label'.tr, '${p.currentStreakDays}'),
                      _infoRow(Icons.check_circle_outline, 'teacher_link_total_sessions_label'.tr, '${p.totalSessionsSynced}'),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 20),
            _buildRangeSelector(isDark),
            const SizedBox(height: 12),
            Obx(() => _buildStatsGrid(isDark)),
            const SizedBox(height: 20),
            Card(
              color: isDark ? AppColors.cardDark : AppColors.cardLight,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('teacher_link_consistency_title'.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 14),
                    Obx(() => StreakHeatmap(dailyActivity: Map.of(controller.dailyWard))),
                    const SizedBox(height: 20),
                    Text('teacher_link_daily_time_title'.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    Obx(() => DailyTimeBarChart(
                          dailyActivity: Map.of(controller.dailyWard),
                          daysToShow: switch (controller.selectedRange.value) {
                            TimeRange.day || TimeRange.week => 14,
                            TimeRange.month => 30,
                            TimeRange.all => 90,
                          },
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              color: isDark ? AppColors.cardDark : AppColors.cardLight,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('teacher_link_write_note_title'.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: controller.noteController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'teacher_link_note_hint'.tr,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Obx(() => SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: controller.isSendingNote.value ? null : controller.sendNote,
                            icon: const Icon(Icons.send, color: Colors.white, size: 18),
                            label: Text('teacher_link_send_note'.tr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('teacher_link_session_history_title'.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Obx(() {
              final list = controller.filteredSessions;
              if (list.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('teacher_link_no_sessions'.tr, style: TextStyle(color: Colors.grey[500]))),
                );
              }
              return Column(
                children: List.generate(list.length, (i) {
                  return SessionTimelineTile(
                    session: list[i],
                    isFirst: i == 0,
                    isLast: i == list.length - 1,
                  );
                }),
              );
            }),
          ],
        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveActivityBanner(bool isDark) {
    final activity = controller.liveActivity.value ?? {};
    final feature = activity['feature'] as String? ?? '';
    final label = activity['label'] as String? ?? '';
    final elapsedSeconds = activity['elapsedSeconds'] as int? ?? 0;
    final minutes = elapsedSeconds ~/ 60;
    final seconds = elapsedSeconds % 60;

    final featureLabel = feature == 'hifz'
        ? 'teacher_link_feature_hifz'.tr
        : feature == 'audio'
            ? 'teacher_link_feature_audio'.tr
            : 'teacher_link_feature_mushaf'.tr;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'teacher_link_live_now'.trParams({
                'feature': featureLabel,
                'label': label,
                'elapsed': '$minutes:${seconds.toString().padLeft(2, '0')}',
              }),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeSelector(bool isDark) {
    return Obx(() => SegmentedButton<TimeRange>(
          segments: [
            ButtonSegment(value: TimeRange.day, label: Text('teacher_link_range_day'.tr)),
            ButtonSegment(value: TimeRange.week, label: Text('teacher_link_range_week'.tr)),
            ButtonSegment(value: TimeRange.month, label: Text('teacher_link_range_month'.tr)),
            ButtonSegment(value: TimeRange.all, label: Text('teacher_link_range_all'.tr)),
          ],
          selected: {controller.selectedRange.value},
          onSelectionChanged: (set) => controller.setRange(set.first),
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return AppColors.primary;
              return isDark ? AppColors.cardDark : AppColors.cardLight;
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return Colors.white;
              return isDark ? Colors.white70 : Colors.black87;
            }),
          ),
        ));
  }

  Widget _buildStatsGrid(bool isDark) {
    final stats = <(IconData, String, String)>[
      (Icons.menu_book, 'teacher_link_feature_mushaf'.tr, '${controller.totalMushafMinutes}m'),
      (Icons.psychology, 'teacher_link_feature_hifz'.tr, '${controller.totalHifzMinutes}m'),
      (Icons.headphones, 'teacher_link_feature_audio'.tr, '${controller.totalAudioMinutes}m'),
      (Icons.event_available, 'teacher_link_active_days'.tr, '${controller.activeDaysInRange}'),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.4,
      children: stats.map((s) {
        return Card(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(s.$1, color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(s.$3, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(s.$2, style: TextStyle(fontSize: 11, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[500]),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          const Spacer(),
          Text(value.isEmpty ? '—' : value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
