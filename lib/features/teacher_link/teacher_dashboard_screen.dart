import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/app_colors.dart';
import '../../routes/app_routes.dart';
import '../shared/widgets/offline_banner.dart';
import 'teacher_dashboard_controller.dart';
import 'teacher_link_models.dart';
import 'utils/live_activity_text.dart';
import 'widgets/note_composer_sheet.dart';

class TeacherDashboardScreen extends GetView<TeacherDashboardController> {
  const TeacherDashboardScreen({super.key});

  static const Color _liveColor = Color(0xFF2E9E5B);
  static const Color _warnColor = Color(0xFFE8813A);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      appBar: AppBar(
        title: Text('teacher_link_teacher_card_title'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Obx(() {
            if (!controller.sync.isTeacher) return const SizedBox.shrink();
            return PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              color: isDark ? AppColors.cardDark : Colors.white,
              onSelected: (value) {
                if (value == 'deactivate') controller.deactivate();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'deactivate',
                  child: Row(
                    children: [
                      const Icon(Icons.logout, color: Colors.red, size: 20),
                      const SizedBox(width: 10),
                      Text('teacher_link_deactivate_action'.tr, style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: Obx(() {
              if (!controller.sync.isTeacher) {
                return _buildActivationForm(context, isDark);
              }
              return _buildDashboard(context, isDark);
            }),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Activation
  // ---------------------------------------------------------------------------

  Widget _buildActivationForm(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: const Icon(Icons.school_rounded, size: 40, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'teacher_link_teacher_form_intro'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 20),
          Card(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: controller.nameController,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => controller.activate(),
                    decoration: InputDecoration(
                      labelText: 'teacher_link_field_name'.tr,
                      prefixIcon: const Icon(Icons.person_outline, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Obx(() => SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: controller.isSaving.value ? null : controller.activate,
                          child: controller.isSaving.value
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                                )
                              : Text('teacher_link_become_teacher'.tr,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dashboard
  // ---------------------------------------------------------------------------

  Widget _buildDashboard(BuildContext context, bool isDark) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildHeaderCard(isDark),
              const SizedBox(height: 14),
              Obx(() => _buildSummaryRow(isDark)),
              const SizedBox(height: 16),
              _buildSearchAndFilters(context, isDark),
              const SizedBox(height: 8),
            ]),
          ),
        ),
        Obx(() {
          if (controller.isLoadingStudents.value && controller.students.isEmpty) {
            return const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            );
          }
          if (controller.students.isEmpty) {
            return SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState(isDark));
          }
          final list = controller.visibleStudents;
          if (list.isEmpty) {
            return SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text('teacher_dash_no_match'.tr, style: TextStyle(color: Colors.grey[500])),
                ),
              ),
            );
          }
          return SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _buildStudentCard(ctx, list[i], isDark),
                childCount: list.length,
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildHeaderCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF1B7A80)],
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Obx(() {
        final profile = controller.sync.teacherProfile.value;
        final name = profile?.displayName ?? '';
        final code = profile?.shareCode ?? '—';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name.isEmpty ? 'teacher_link_teacher_card_title'.tr : 'teacher_dash_hello'.trParams({'name': name}),
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            Text('teacher_dash_share_code_title'.tr, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        code,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: controller.copyShareCode,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: Text('teacher_dash_copy'.tr),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('teacher_link_share_code_hint'.tr, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        );
      }),
    );
  }

  Widget _buildSummaryRow(bool isDark) {
    controller.clockTick.value; // refresh "live" counts as entries go stale
    final selected = controller.filter.value;
    return Row(
      children: [
        Expanded(
          child: _summaryTile(
            isDark: isDark,
            icon: Icons.groups_rounded,
            color: AppColors.primary,
            value: '${controller.students.length}',
            label: 'teacher_dash_students_total'.tr,
            selected: selected == StudentFilter.all,
            onTap: () => controller.filter.value = StudentFilter.all,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryTile(
            isDark: isDark,
            icon: Icons.bolt_rounded,
            color: _liveColor,
            value: '${controller.activeTodayCount}',
            label: 'teacher_dash_active_today'.tr,
            badge: controller.liveCount > 0 ? '${controller.liveCount} ${'teacher_dash_live'.tr}' : null,
            selected: selected == StudentFilter.activeToday,
            onTap: () => controller.filter.value = StudentFilter.activeToday,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryTile(
            isDark: isDark,
            icon: Icons.notification_important_rounded,
            color: _warnColor,
            value: '${controller.needsAttentionCount}',
            label: 'teacher_dash_needs_attention'.tr,
            selected: selected == StudentFilter.needsAttention,
            onTap: () => controller.filter.value = StudentFilter.needsAttention,
          ),
        ),
      ],
    );
  }

  Widget _summaryTile({
    required bool isDark,
    required IconData icon,
    required Color color,
    required String value,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    String? badge,
  }) {
    return Material(
      color: selected ? color.withValues(alpha: 0.14) : (isDark ? AppColors.cardDark : Colors.white),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? color : color.withValues(alpha: 0.15), width: selected ? 1.5 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const Spacer(),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                      child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(BuildContext context, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller.searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'teacher_dash_search_hint'.tr,
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: Obx(() => controller.searchQuery.value.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: controller.searchController.clear,
                    )),
              filled: true,
              fillColor: isDark ? AppColors.cardDark : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Obx(() => PopupMenuButton<StudentSort>(
              tooltip: 'teacher_dash_sort_recent'.tr,
              initialValue: controller.sort.value,
              color: isDark ? AppColors.cardDark : Colors.white,
              onSelected: (v) => controller.sort.value = v,
              itemBuilder: (_) => [
                PopupMenuItem(value: StudentSort.recent, child: Text('teacher_dash_sort_recent'.tr)),
                PopupMenuItem(value: StudentSort.name, child: Text('teacher_dash_sort_name'.tr)),
                PopupMenuItem(value: StudentSort.streak, child: Text('teacher_dash_sort_streak'.tr)),
              ],
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.sort_rounded, color: AppColors.primary),
              ),
            )),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_add_alt_1_rounded, size: 56, color: Colors.grey[500]),
          const SizedBox(height: 12),
          Text(
            'teacher_link_no_students'.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            'teacher_link_share_code_hint'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Student card
  // ---------------------------------------------------------------------------

  ({String text, Color color}) _statusOf(StudentSummary s) {
    if (s.isLiveNow) return (text: 'teacher_status_live'.tr, color: _liveColor);
    final days = s.daysSinceActive;
    if (days == null) return (text: 'teacher_status_never'.tr, color: Colors.grey);
    if (days == 0) return (text: 'teacher_status_today'.tr, color: AppColors.primary);
    if (days == 1) return (text: 'teacher_status_yesterday'.tr, color: const Color(0xFFE4B93E));
    return (
      text: 'teacher_status_days_ago'.trParams({'days': '$days'}),
      color: days >= 3 ? _warnColor : const Color(0xFFE4B93E),
    );
  }

  Widget _buildStudentCard(BuildContext context, StudentSummary s, bool isDark) {
    final status = _statusOf(s);
    final displayName = s.name.isEmpty ? 'reciter_unknown'.tr : s.name;
    final initial = displayName.trim().isEmpty ? '?' : displayName.trim().characters.first.toUpperCase();
    final live = s.isLiveNow ? s.liveActivity : null;

    void openDetail() => Get.toNamed(
          AppRoutes.STUDENT_DETAIL,
          arguments: {'studentUid': s.uid, 'studentName': s.name},
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: status.color.withValues(alpha: s.needsAttention || s.isLiveNow ? 0.5 : 0.12)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: openDetail,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 6, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: status.color.withValues(alpha: 0.15),
                          child: Text(
                            initial,
                            style: TextStyle(color: status.color, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ),
                        PositionedDirectional(
                          end: -1,
                          bottom: -1,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: status.color,
                              shape: BoxShape.circle,
                              border: Border.all(color: isDark ? AppColors.cardDark : Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            status.text,
                            style: TextStyle(color: status.color, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'teacher_dash_quick_note'.tr,
                      icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary),
                      onPressed: () => showNoteComposerSheet(
                        context: context,
                        studentName: s.name,
                        onSend: (text) => controller.sendQuickNote(s, text),
                      ),
                    ),
                    Icon(
                      Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left : Icons.chevron_right,
                      color: Colors.grey,
                    ),
                  ],
                ),
                if (live != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: _liveColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.graphic_eq_rounded, color: _liveColor, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${liveActivityFeatureLabel(live)} • ${liveActivitySubject(live)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(liveActivityElapsed(live), style: const TextStyle(fontSize: 12, color: _liveColor)),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _metricChip(
                      Icons.local_fire_department_rounded,
                      Colors.orange,
                      '${'teacher_stat_streak'.tr}: ${'teacher_stat_days_unit'.trParams({'count': '${s.currentStreakDays}'})}',
                      isDark,
                    ),
                    _metricChip(
                      Icons.task_alt_rounded,
                      AppColors.primary,
                      '${'teacher_stat_sessions'.tr}: ${s.totalSessionsSynced}',
                      isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metricChip(IconData icon, Color color, String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? AppColors.secondaryDark : AppColors.secondaryLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
