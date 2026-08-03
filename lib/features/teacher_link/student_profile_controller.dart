import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/app_colors.dart';
import '../../core/connectivity_service.dart';
import '../../core/storage_service.dart';
import '../../core/teacher_sync_service.dart';

class StudentProfileController extends GetxController {
  final TeacherSyncService sync = Get.find<TeacherSyncService>();
  final StorageService _storage = Get.find<StorageService>();
  final ConnectivityService _connectivity = Get.find<ConnectivityService>();

  final nameController = TextEditingController();
  final ageController = TextEditingController();
  final phoneController = TextEditingController();
  final whatsappController = TextEditingController();
  final fatherPhoneController = TextEditingController();

  final RxBool isSaving = false.obs;

  @override
  void onInit() {
    super.onInit();
    final cached = _storage.getStudentProfileCache();
    if (cached != null) {
      nameController.text = cached['name'] as String? ?? '';
      ageController.text = (cached['age'] as int?)?.toString() ?? '';
      phoneController.text = cached['phone'] as String? ?? '';
      whatsappController.text = cached['whatsapp'] as String? ?? '';
      fatherPhoneController.text = cached['fatherPhone'] as String? ?? '';
    }
  }

  Future<void> saveProfile() async {
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
      await sync.activateStudentProfile(
        name: nameController.text.trim(),
        age: int.tryParse(ageController.text.trim()) ?? 0,
        phone: phoneController.text.trim(),
        whatsapp: whatsappController.text.trim(),
        fatherPhone: fatherPhoneController.text.trim(),
      );
      Get.snackbar(
        'teacher_link_saved_title'.tr,
        'teacher_link_saved_desc'.tr,
        backgroundColor: AppColors.primary,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar('teacher_link_error'.tr, e.toString(), snackPosition: SnackPosition.BOTTOM);
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> linkTeacherByCode(String code) async {
    if (code.trim().isEmpty) return;
    if (!_connectivity.isOnline.value) {
      Get.snackbar('teacher_link_error'.tr, 'teacher_link_needs_internet'.tr, snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final error = await sync.linkTeacherByCode(code);
    if (error == null) {
      Get.snackbar(
        'teacher_link_linked_title'.tr,
        'teacher_link_linked_desc'.tr,
        backgroundColor: AppColors.primary,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } else {
      Get.snackbar('teacher_link_error'.tr, 'teacher_link_error_$error'.tr, snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> unlinkTeacher(String teacherUid, String teacherName) async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.getCard(Get.isDarkMode),
        title: Text('teacher_link_unlink_title'.tr, style: TextStyle(color: Get.isDarkMode ? Colors.white : Colors.black87)),
        content: Text(
          'teacher_link_unlink_confirm'.trParams({'teacher': teacherName}),
          style: TextStyle(color: Get.isDarkMode ? Colors.grey : Colors.black54),
        ),
        actions: [
          TextButton(child: Text('cancel'.tr, style: const TextStyle(color: Colors.grey)), onPressed: () => Get.back(result: false)),
          TextButton(child: Text('teacher_link_unlink_action'.tr, style: const TextStyle(color: Colors.red)), onPressed: () => Get.back(result: true)),
        ],
      ),
    );
    if (confirm != true) return;
    if (!_connectivity.isOnline.value) {
      Get.snackbar('teacher_link_error'.tr, 'teacher_link_needs_internet'.tr, snackPosition: SnackPosition.BOTTOM);
      return;
    }
    await sync.unlinkTeacher(teacherUid);
  }

  Future<void> deleteCloudData() async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.getCard(Get.isDarkMode),
        title: Text('teacher_link_delete_data_title'.tr, style: TextStyle(color: Get.isDarkMode ? Colors.white : Colors.black87)),
        content: Text(
          'teacher_link_delete_data_confirm'.tr,
          style: TextStyle(color: Get.isDarkMode ? Colors.grey : Colors.black54),
        ),
        actions: [
          TextButton(child: Text('cancel'.tr, style: const TextStyle(color: Colors.grey)), onPressed: () => Get.back(result: false)),
          TextButton(child: Text('delete'.tr, style: const TextStyle(color: Colors.red)), onPressed: () => Get.back(result: true)),
        ],
      ),
    );
    if (confirm != true) return;
    if (!_connectivity.isOnline.value) {
      Get.snackbar('teacher_link_error'.tr, 'teacher_link_needs_internet'.tr, snackPosition: SnackPosition.BOTTOM);
      return;
    }

    await sync.deactivateAndDeleteCloudData();
    nameController.clear();
    ageController.clear();
    phoneController.clear();
    whatsappController.clear();
    fatherPhoneController.clear();
    Get.snackbar(
      'teacher_link_delete_data_title'.tr,
      'teacher_link_delete_data_done'.tr,
      backgroundColor: Colors.grey[800],
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  @override
  void onClose() {
    nameController.dispose();
    ageController.dispose();
    phoneController.dispose();
    whatsappController.dispose();
    fatherPhoneController.dispose();
    super.onClose();
  }
}
