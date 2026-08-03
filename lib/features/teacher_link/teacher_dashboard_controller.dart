import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../core/app_colors.dart';
import '../../core/connectivity_service.dart';
import '../../core/teacher_sync_service.dart';
import 'teacher_link_models.dart';

class TeacherDashboardController extends GetxController {
  final TeacherSyncService sync = Get.find<TeacherSyncService>();
  final ConnectivityService _connectivity = Get.find<ConnectivityService>();

  final nameController = TextEditingController();
  final RxBool isSaving = false.obs;
  final RxList<StudentSummary> students = <StudentSummary>[].obs;

  StreamSubscription? _studentsSub;

  @override
  void onInit() {
    super.onInit();
    if (sync.isTeacher) {
      _watchStudents();
    }
  }

  void _watchStudents() {
    final uid = sync.teacherUid.value;
    if (uid == null) return;
    _studentsSub?.cancel();
    _studentsSub = sync.watchLinkedStudents(uid).listen((list) {
      students.assignAll(list);
    }, onError: (_) {});
  }

  Future<void> activate() async {
    if (nameController.text.trim().isEmpty) {
      Get.snackbar('teacher_link_error'.tr, 'teacher_link_name_required'.tr, snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (!_connectivity.isOnline.value) {
      Get.snackbar('teacher_link_error'.tr, 'teacher_link_needs_internet'.tr, snackPosition: SnackPosition.BOTTOM);
      return;
    }

    isSaving.value = true;
    try {
      await sync.activateTeacherMode(nameController.text.trim());
      _watchStudents();
    } catch (e) {
      Get.snackbar('teacher_link_error'.tr, e.toString(), snackPosition: SnackPosition.BOTTOM);
    } finally {
      isSaving.value = false;
    }
  }

  void copyShareCode() {
    final code = sync.teacherProfile.value?.shareCode;
    if (code == null) return;
    Clipboard.setData(ClipboardData(text: code));
    Get.snackbar(
      'teacher_link_code_copied'.tr,
      code,
      backgroundColor: AppColors.primary,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> deactivate() async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.getCard(Get.isDarkMode),
        title: Text('teacher_link_deactivate_title'.tr, style: TextStyle(color: Get.isDarkMode ? Colors.white : Colors.black87)),
        content: Text(
          'teacher_link_deactivate_confirm'.tr,
          style: TextStyle(color: Get.isDarkMode ? Colors.grey : Colors.black54),
        ),
        actions: [
          TextButton(child: Text('cancel'.tr, style: const TextStyle(color: Colors.grey)), onPressed: () => Get.back(result: false)),
          TextButton(child: Text('teacher_link_deactivate_action'.tr, style: const TextStyle(color: Colors.red)), onPressed: () => Get.back(result: true)),
        ],
      ),
    );
    if (confirm != true) return;
    if (!_connectivity.isOnline.value) {
      Get.snackbar('teacher_link_error'.tr, 'teacher_link_needs_internet'.tr, snackPosition: SnackPosition.BOTTOM);
      return;
    }

    await _studentsSub?.cancel();
    students.clear();
    await sync.deactivateTeacherMode();
    nameController.clear();
  }

  @override
  void onClose() {
    _studentsSub?.cancel();
    nameController.dispose();
    super.onClose();
  }
}
