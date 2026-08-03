import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/app_colors.dart';
import '../../routes/app_routes.dart';
import '../shared/widgets/offline_banner.dart';
import 'teacher_dashboard_controller.dart';

class TeacherDashboardScreen extends GetView<TeacherDashboardController> {
  const TeacherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('teacher_link_teacher_card_title'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
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

  Widget _buildActivationForm(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('teacher_link_teacher_form_intro'.tr, style: TextStyle(color: Colors.grey[500], fontSize: 13, height: 1.5)),
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
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                              : Text('teacher_link_become_teacher'.tr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  Widget _buildDashboard(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('teacher_link_your_share_code'.tr, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Obx(() => Text(
                              controller.sync.teacherProfile.value?.shareCode ?? '—',
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 1.5),
                            )),
                      ),
                      IconButton(icon: const Icon(Icons.copy, color: AppColors.primary), onPressed: controller.copyShareCode),
                    ],
                  ),
                  Text('teacher_link_share_code_hint'.tr, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('teacher_link_your_students'.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Obx(() {
            if (controller.students.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('teacher_link_no_students'.tr, style: TextStyle(color: Colors.grey[500], fontSize: 13), textAlign: TextAlign.center),
                ),
              );
            }
            return Column(
              children: controller.students.map((s) {
                return Card(
                  color: isDark ? AppColors.cardDark : AppColors.cardLight,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: AppColors.primary, child: Icon(Icons.person, color: Colors.white)),
                    title: Text(s.name.isEmpty ? 'reciter_unknown'.tr : s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'teacher_link_student_quick_stats'.trParams({
                        'sessions': '${s.totalSessionsSynced}',
                        'streak': '${s.currentStreakDays}',
                      }),
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Get.toNamed(AppRoutes.STUDENT_DETAIL, arguments: {'studentUid': s.uid, 'studentName': s.name}),
                  ),
                );
              }).toList(),
            );
          }),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: controller.deactivate,
            icon: const Icon(Icons.logout),
            label: Text('teacher_link_deactivate_action'.tr),
          ),
        ],
      ),
    );
  }
}
