import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../core/app_colors.dart';
import '../../core/surah_display.dart';
import '../shared/widgets/offline_banner.dart';
import 'student_detail_controller.dart';
import 'utils/live_activity_text.dart';
import 'widgets/daily_time_bar_chart.dart';
import 'widgets/note_composer_sheet.dart';
import 'widgets/session_timeline_tile.dart';
import 'widgets/streak_heatmap.dart';

class StudentDetailScreen extends GetView<StudentDetailController> {
  const StudentDetailScreen({super.key});

  static const Color _liveColor = Color(0xFF2E9E5B);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = controller.studentName.isEmpty ? 'reciter_unknown'.tr : controller.studentName;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
        appBar: AppBar(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              tooltip: 'teacher_dash_quick_note'.tr,
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              onPressed: () => _openComposer(context),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Container(
              height: 44,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(22)),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: [
                  Tab(text: 'student_tab_overview'.tr),
                  Tab(text: 'student_tab_sessions'.tr),
                  Tab(text: 'student_tab_notes'.tr),
                ],
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: TabBarView(
                children: [
                  _buildOverviewTab(context, isDark),
                  _buildSessionsTab(context, isDark),
                  _buildNotesTab(context, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openComposer(BuildContext context, {String initialText = ''}) {
    showNoteComposerSheet(
      context: context,
      studentName: controller.studentName,
      initialText: initialText,
      onSend: controller.sendNoteText,
    );
  }

  Color _cardColor(bool isDark) => isDark ? AppColors.cardDark : Colors.white;

  // ---------------------------------------------------------------------------
  // Overview
  // ---------------------------------------------------------------------------

  Widget _buildOverviewTab(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Obx(() {
          if (!controller.isLiveActivityFresh) return const SizedBox.shrink();
          return _buildLiveActivityBanner(controller.liveActivity.value ?? const {});
        }),
        Obx(() => _buildProfileCard(context, isDark)),
        const SizedBox(height: 16),
        _buildRangeSelector(isDark),
        const SizedBox(height: 12),
        Obx(() => _buildStatsGrid(isDark)),
        const SizedBox(height: 16),
        _sectionCard(
          isDark: isDark,
          icon: Icons.local_fire_department_rounded,
          title: 'teacher_link_consistency_title'.tr,
          child: Obx(() => StreakHeatmap(dailyActivity: Map.of(controller.dailyWard))),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          isDark: isDark,
          icon: Icons.bar_chart_rounded,
          title: 'teacher_link_daily_time_title'.tr,
          child: Obx(() => DailyTimeBarChart(
                dailyActivity: Map.of(controller.dailyWard),
                daysToShow: switch (controller.selectedRange.value) {
                  TimeRange.day || TimeRange.week => 14,
                  TimeRange.month => 30,
                  TimeRange.all => 90,
                },
              )),
        ),
      ],
    );
  }

  Widget _buildLiveActivityBanner(Map<String, dynamic> activity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _liveColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _liveColor.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: const BoxDecoration(color: _liveColor, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'teacher_link_live_now'.trParams({
                'feature': liveActivityFeatureLabel(activity),
                'label': liveActivitySubject(activity),
                'elapsed': liveActivityElapsed(activity),
              }),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, bool isDark) {
    if (controller.isLoadingProfile.value) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    final p = controller.profile.value;
    if (p == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text('teacher_link_profile_unavailable'.tr, style: TextStyle(color: Colors.grey[500])),
      );
    }

    final name = p.name.isEmpty ? controller.studentName : p.name;
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    final days = p.daysSinceActive;
    final lastActive = days == null
        ? 'teacher_status_never'.tr
        : days == 0
            ? 'teacher_status_today'.tr
            : days == 1
                ? 'teacher_status_yesterday'.tr
                : 'teacher_status_days_ago'.trParams({'days': '$days'});

    return Container(
      decoration: BoxDecoration(color: _cardColor(isDark), borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text(initial, style: const TextStyle(color: AppColors.primary, fontSize: 22, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                      const SizedBox(height: 4),
                      Text(lastActive, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _miniStat(
                    isDark,
                    Icons.local_fire_department_rounded,
                    Colors.orange,
                    'teacher_stat_days_unit'.trParams({'count': '${p.currentStreakDays}'}),
                    'teacher_link_current_streak_label'.tr,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _miniStat(
                    isDark,
                    Icons.task_alt_rounded,
                    AppColors.primary,
                    '${p.totalSessionsSynced}',
                    'teacher_link_total_sessions_label'.tr,
                  ),
                ),
              ],
            ),
          ),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              leading: const Icon(Icons.contact_phone_outlined, color: AppColors.primary),
              title: Text('student_contact_info'.tr, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              children: [
                _contactRow(Icons.phone_outlined, 'teacher_link_field_phone'.tr, p.phone),
                _contactRow(Icons.chat_outlined, 'teacher_link_field_whatsapp'.tr, p.whatsapp),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(bool isDark, IconData icon, Color color, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.secondaryDark : AppColors.secondaryLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String label, String value) {
    final hasValue = value.trim().isNotEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: hasValue
          ? () {
              Clipboard.setData(ClipboardData(text: value));
              Get.snackbar('student_copied'.tr, value, snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 2));
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey[500]),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            const Spacer(),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(hasValue ? value : '—', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            if (hasValue) ...[
              const SizedBox(width: 6),
              Icon(Icons.copy_rounded, size: 14, color: Colors.grey[500]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRangeSelector(bool isDark) {
    const ranges = [TimeRange.day, TimeRange.week, TimeRange.month, TimeRange.all];
    String labelOf(TimeRange r) => switch (r) {
          TimeRange.day => 'teacher_link_range_day'.tr,
          TimeRange.week => 'teacher_link_range_week'.tr,
          TimeRange.month => 'teacher_link_range_month'.tr,
          TimeRange.all => 'teacher_link_range_all'.tr,
        };

    return Obx(() {
      final selected = controller.selectedRange.value;
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: _cardColor(isDark), borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: ranges.map((r) {
            final isSel = r == selected;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => controller.setRange(r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: isSel ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labelOf(r),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSel ? Colors.white : Colors.grey,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
    });
  }

  String _minutes(int m) => 'student_minutes_value'.trParams({'count': '$m'});

  Widget _buildStatsGrid(bool isDark) {
    final avg = controller.averageRating;
    final stats = <(IconData, Color, String, String)>[
      (Icons.timer_outlined, AppColors.primary, _minutes(controller.totalMinutes), 'student_total_time'.tr),
      (Icons.event_available_rounded, const Color(0xFF2E9E5B), '${controller.activeDaysInRange}', 'teacher_link_active_days'.tr),
      (Icons.menu_book_rounded, AppColors.primary, _minutes(controller.totalMushafMinutes), 'teacher_link_feature_mushaf'.tr),
      (Icons.psychology_rounded, Colors.blueAccent, _minutes(controller.totalHifzMinutes), 'teacher_link_feature_hifz'.tr),
      (Icons.headphones_rounded, Colors.teal, _minutes(controller.totalAudioMinutes), 'teacher_link_feature_audio'.tr),
      (Icons.star_rounded, const Color(0xFFE4B93E), avg > 0 ? avg.toStringAsFixed(1) : '—', 'student_avg_rating'.tr),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.3,
      children: stats.map((s) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: _cardColor(isDark), borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: s.$2.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(s.$1, color: s.$2, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(s.$3, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    Text(s.$4, style: TextStyle(fontSize: 11, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _sectionCard({required bool isDark, required IconData icon, required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor(isDark), borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sessions (review)
  // ---------------------------------------------------------------------------

  Widget _buildSessionsTab(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _buildRangeSelector(isDark),
        const SizedBox(height: 12),
        Obx(() => _buildSessionSummary(isDark)),
        const SizedBox(height: 12),
        Obx(() => _buildSessionFilters(isDark)),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.lock_outline_rounded, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 6),
            Expanded(
              child: Text('student_sessions_shared_hint'.tr, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Obx(() {
          if (controller.isLoadingSessions.value && controller.sessions.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            );
          }
          final list = controller.reviewSessions;
          if (list.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.event_note_outlined, size: 48, color: Colors.grey[500]),
                  const SizedBox(height: 10),
                  Text('teacher_link_no_sessions'.tr, style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            );
          }
          return Column(
            children: List.generate(list.length, (i) {
              final session = list[i];
              return SessionTimelineTile(
                session: session,
                isFirst: i == 0,
                isLast: i == list.length - 1,
                onComment: () => _openComposer(
                  context,
                  initialText: 'student_note_about_session'.trParams({
                    'session': SurahDisplay.rangeTitle(
                      session.chapterId,
                      session.reachedStartAyah,
                      session.reachedEndAyah,
                      fallback: session.chapterName,
                    ),
                  }),
                ),
              );
            }),
          );
        }),
      ],
    );
  }

  Widget _buildSessionSummary(bool isDark) {
    final list = controller.filteredSessions;
    final avg = controller.averageRating;
    final items = <(String, String, Color)>[
      ('${list.length}', 'teacher_stat_sessions'.tr, AppColors.primary),
      (avg > 0 ? avg.toStringAsFixed(1) : '—', 'student_avg_rating'.tr, const Color(0xFFE4B93E)),
      ('${controller.completionPercent}%', 'student_completion_rate'.tr, const Color(0xFF2E9E5B)),
      ('${controller.ayahsReviewed}', 'student_ayahs_reviewed'.tr, Colors.blueAccent),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(color: _cardColor(isDark), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: items.map((it) {
          return Expanded(
            child: Column(
              children: [
                Text(it.$1, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: it.$3)),
                const SizedBox(height: 2),
                Text(
                  it.$2,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSessionFilters(bool isDark) {
    final selected = controller.sessionFilter.value;
    final filters = <(SessionFilter, String)>[
      (SessionFilter.all, 'student_filter_all'.tr),
      (SessionFilter.completed, 'student_filter_completed'.tr),
      (SessionFilter.partial, 'student_filter_partial'.tr),
      (SessionFilter.lowRating, 'student_filter_low_rating'.tr),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSel = f.$1 == selected;
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: ChoiceChip(
              label: Text(f.$2),
              selected: isSel,
              selectedColor: AppColors.primary,
              backgroundColor: _cardColor(isDark),
              labelStyle: TextStyle(
                color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              onSelected: (_) => controller.sessionFilter.value = f.$1,
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Notes
  // ---------------------------------------------------------------------------

  Widget _buildNotesTab(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _cardColor(isDark), borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.edit_note_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('teacher_link_write_note_title'.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              const SizedBox(height: 14),
              Text('student_note_templates'.tr, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kNoteTemplateKeys.map((k) {
                  return ActionChip(
                    label: Text(k.tr, style: const TextStyle(fontSize: 12)),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.25)),
                    onPressed: () {
                      final current = controller.noteController.text.trimRight();
                      final next = current.isEmpty ? k.tr : '$current ${k.tr}';
                      controller.noteController.value = TextEditingValue(
                        text: next,
                        selection: TextSelection.collapsed(offset: next.length),
                      );
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller.noteController,
                minLines: 4,
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: 'teacher_link_note_hint'.tr,
                  filled: true,
                  fillColor: isDark ? AppColors.secondaryDark : AppColors.secondaryLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 14),
              Obx(() => ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: controller.isSendingNote.value ? null : controller.sendNote,
                    icon: controller.isSendingNote.value
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text('teacher_link_send_note'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
                  )),
            ],
          ),
        ),
      ],
    );
  }
}
