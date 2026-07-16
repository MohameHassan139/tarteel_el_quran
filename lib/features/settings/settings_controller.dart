import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/storage_service.dart';
import '../../core/reminder_service.dart';
import '../../core/app_colors.dart';

class SettingsController extends GetxController {
  final StorageService _storage = Get.find<StorageService>();
  final ReminderService _reminder = Get.find<ReminderService>();

  final RxInt selectedReciterId = 7.obs;
  final RxString selectedStyle = 'murattal'.obs;
  final RxBool isDarkMode = true.obs;
  final RxString appLanguage = 'ar'.obs;
  final RxBool keepScreenOn = true.obs;

  @override
  void onInit() {
    super.onInit();
    loadSettings();
  }

  void loadSettings() {
    selectedReciterId.value = _storage.getSelectedReciterId();
    selectedStyle.value = _storage.getSelectedStyle();
    isDarkMode.value = _storage.isDarkMode();
    appLanguage.value = _storage.getAppLanguage();
    keepScreenOn.value = _storage.getKeepScreenOn();
  }

  Future<void> updateReciter(int id) async {
    await _storage.setSelectedReciterId(id);
    selectedReciterId.value = id;
    
    final currentStyle = selectedStyle.value;
    if (id == 10) {
      await _storage.setSelectedStyle('teacher');
      selectedStyle.value = 'teacher';
    } else if (id != 6 && currentStyle == 'teacher') {
      await _storage.setSelectedStyle('murattal');
      selectedStyle.value = 'murattal';
    } else if (id != 6 && id != 2 && id != 9 && currentStyle == 'mujawwad') {
      await _storage.setSelectedStyle('murattal');
      selectedStyle.value = 'murattal';
    }
    Get.snackbar(
      'القارئ المفضل',
      'تم تحديث القارئ المفضل بنجاح',
      backgroundColor: AppColors.primary,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> updateStyle(String style) async {
    await _storage.setSelectedStyle(style);
    selectedStyle.value = style;

    String styleAr = '';
    if (style == 'murattal') styleAr = 'مرتّل';
    if (style == 'mujawwad') styleAr = 'مجوّد';
    if (style == 'teacher') styleAr = 'معلّم (تعليمي)';

    Get.snackbar(
      'نمط التلاوة',
      'تم اختيار رواية/نمط التلاوة: $styleAr',
      backgroundColor: AppColors.primary,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> toggleTheme(bool value) async {
    await _storage.setDarkMode(value);
    isDarkMode.value = value;
    Get.changeThemeMode(value ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> updateLanguage(String value) async {
    await _storage.setAppLanguage(value);
    appLanguage.value = value;
    Get.updateLocale(Locale(value));
  }

  Future<void> toggleKeepScreenOn(bool value) async {
    await _storage.setKeepScreenOn(value);
    keepScreenOn.value = value;
  }

  Future<void> triggerTestNotification() async {
    await _reminder.triggerInstantTestNotification();
    Get.snackbar(
      'إشعار تجريبي',
      'تم إرسال تنبيه تجريبي! تحقق من لوحة الإشعارات.',
      backgroundColor: AppColors.primary,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}
