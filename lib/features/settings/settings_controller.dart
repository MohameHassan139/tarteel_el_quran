import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/storage_service.dart';
import '../../core/reminder_service.dart';
import '../../core/teacher_sync_service.dart';
import '../../core/app_colors.dart';
import '../../routes/app_routes.dart';

class SettingsController extends GetxController {
  final StorageService _storage = Get.find<StorageService>();
  final ReminderService _reminder = Get.find<ReminderService>();

  final RxInt selectedReciterId = 7.obs;
  final RxString selectedStyle = 'murattal'.obs;
  final RxBool isDarkMode = true.obs;
  final RxString appLanguage = 'ar'.obs;
  final RxBool keepScreenOn = true.obs;
  final RxBool audioHubPlayAll = true.obs;
  final RxBool mushafPlayNext = true.obs;

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
    audioHubPlayAll.value = _storage.getAudioHubPlayAll();
    mushafPlayNext.value = _storage.getMushafPlayNext();
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
      'favorite_reciter'.tr,
      'favorite_reciter_updated'.tr,
      backgroundColor: AppColors.primary,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> updateStyle(String style) async {
    await _storage.setSelectedStyle(style);
    selectedStyle.value = style;

    String styleAr = '';
    if (style == 'murattal') styleAr = 'murattal'.tr;
    if (style == 'mujawwad') styleAr = 'mujawwad'.tr;
    if (style == 'teacher') styleAr = 'teacher'.tr;

    Get.snackbar(
      'reciter_style'.tr,
      'recitation_style_selected'.trParams({'style': styleAr}),
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
    
    // Reschedule reminder notifications in the new language
    final goal = _storage.getWardGoal();
    await _reminder.scheduleDailyReminder(goal.reminderHour, goal.reminderMinute);
  }

  Future<void> toggleKeepScreenOn(bool value) async {
    await _storage.setKeepScreenOn(value);
    keepScreenOn.value = value;
  }

  Future<void> toggleAudioHubPlayAll(bool value) async {
    await _storage.setAudioHubPlayAll(value);
    audioHubPlayAll.value = value;
  }

  Future<void> toggleMushafPlayNext(bool value) async {
    await _storage.setMushafPlayNext(value);
    mushafPlayNext.value = value;
  }

  Future<void> confirmAndDeleteAccount(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.getCard(isDark),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text(
              'حذف الحساب',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'هل أنت متأكد من رغبتك في حذف حسابك نهائياً؟',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 12),
            Text(
              'سيتم حذف كافة البيانات السحابية المرتبطة بالحساب (سجلات الحفظ، الورد اليومي، الملاحظات، وجلسات المعلم) نهائياً ولا يمكن استرجاعها.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text('cancel'.tr, style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('حذف نهائياً'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading overlay
    Get.dialog(
      const PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.red),
                  SizedBox(height: 16),
                  Text('جاري حذف الحساب والبيانات السحابية...'),
                ],
              ),
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );

    try {
      if (Get.isRegistered<TeacherSyncService>()) {
        await Get.find<TeacherSyncService>().deleteEntireAccount();
      } else {
        await FirebaseAuth.instance.currentUser?.delete();
        await FirebaseAuth.instance.signOut();
      }

      if (Get.isDialogOpen ?? false) Get.back();

      Get.snackbar(
        'تم حذف الحساب',
        'تم حذف حسابك وكافة البيانات المرتبطة به بنجاح.',
        backgroundColor: Colors.grey[850],
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );

      // Return to start screen
      Get.offAllNamed(AppRoutes.HOME);
    } on FirebaseAuthException catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      if (e.code == 'requires-recent-login') {
        if (context.mounted) {
          _promptReauthAndRetry(context);
        }
      } else {
        Get.snackbar(
          'خطأ',
          e.message ?? e.code,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar(
        'خطأ في حذف الحساب',
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _promptReauthAndRetry(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final retry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getCard(isDark),
        title: const Text('إعادة تسجيل الدخول مطلوبة'),
        content: const Text(
          'لأسباب أمنية، تتطلب عملية الحذف إعادة تسجيل الدخول لتأكيد هويتك. هل تود المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr, style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إعادة الدخول والمتابعة'),
          ),
        ],
      ),
    );

    if (retry == true) {
      try {
        await FirebaseAuth.instance.signInAnonymously();
        if (context.mounted) {
          await confirmAndDeleteAccount(context);
        }
      } catch (e) {
        Get.snackbar(
          'خطأ',
          'تعذر إعادة تسجيل الدخول: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }
}
