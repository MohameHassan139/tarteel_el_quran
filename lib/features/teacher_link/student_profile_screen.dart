import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/app_colors.dart';
import '../shared/widgets/offline_banner.dart';
import 'student_profile_controller.dart';

class StudentProfileScreen extends GetView<StudentProfileController> {
  const StudentProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('teacher_link_student_card_title'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
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
            Text('teacher_link_student_form_intro'.tr, style: TextStyle(color: Colors.grey[500], fontSize: 13, height: 1.5)),
            const SizedBox(height: 20),
            Card(
              color: isDark ? AppColors.cardDark : AppColors.cardLight,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _field(controller.nameController, 'teacher_link_field_name'.tr, Icons.person_outline),
                    const SizedBox(height: 12),
                    _field(controller.phoneController, 'teacher_link_field_phone'.tr, Icons.phone_outlined, keyboardType: TextInputType.phone),
                    const SizedBox(height: 12),
                    _field(controller.whatsappController, 'teacher_link_field_whatsapp'.tr, Icons.chat_outlined, keyboardType: TextInputType.phone),
                    const SizedBox(height: 16),
                    Obx(() => SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: controller.isSaving.value ? null : controller.saveProfile,
                            child: controller.isSaving.value
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                                : Text(
                                    controller.sync.isStudent ? 'teacher_link_update_profile'.tr : 'teacher_link_activate'.tr,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        )),
                  ],
                ),
              ),
            ),
            Obx(() {
              if (!controller.sync.isStudent) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('teacher_link_linked_teachers_title'.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      TextButton.icon(
                        onPressed: () => _showLinkTeacherDialog(context),
                        icon: const Icon(Icons.add_link, size: 18),
                        label: Text('teacher_link_link_action'.tr),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Obx(() {
                    if (controller.sync.linkedTeachers.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text('teacher_link_no_linked_teachers'.tr, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                      );
                    }
                    return Column(
                      children: controller.sync.linkedTeachers.map((t) {
                        return Card(
                          color: isDark ? AppColors.cardDark : AppColors.cardLight,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const CircleAvatar(backgroundColor: AppColors.primary, child: Icon(Icons.person, color: Colors.white, size: 18)),
                            title: Text(t.teacherDisplayName.isEmpty ? 'reciter_unknown'.tr : t.teacherDisplayName),
                            trailing: IconButton(
                              icon: const Icon(Icons.link_off, color: Colors.red),
                              onPressed: () => controller.unlinkTeacher(t.teacherUid, t.teacherDisplayName),
                            ),
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
                    onPressed: controller.deleteCloudData,
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: Text('teacher_link_delete_data_action'.tr),
                  ),
                ],
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

  Widget _field(TextEditingController c, String label, IconData icon, {TextInputType? keyboardType}) {
    return TextField(
      controller: c,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showLinkTeacherDialog(BuildContext context) {
    final codeController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.getCard(isDark),
          title: Text('teacher_link_link_dialog_title'.tr, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
          content: TextField(
            controller: codeController,
            textCapitalization: TextCapitalization.characters,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: 'teacher_link_code_hint'.tr,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(child: Text('cancel'.tr, style: const TextStyle(color: Colors.grey)), onPressed: () => Navigator.pop(dialogContext)),
            TextButton(
              child: Text('ok'.tr, style: const TextStyle(color: AppColors.primary)),
              onPressed: () {
                Navigator.pop(dialogContext);
                controller.linkTeacherByCode(codeController.text);
              },
            ),
          ],
        );
      },
    );
  }
}
