import 'dart:async';
import 'package:get/get.dart';
import '../../core/storage_service.dart';
import '../../core/reminder_service.dart';
import '../../models.dart';

class HomeController extends GetxController {
  // Looked up lazily on each access (not as an eager field initializer) so
  // that if StorageService is ever missing, this degrades to defaults
  // instead of throwing while HomeBinding builds the very first screen the
  // app shows — an uncaught throw there previously had nothing to catch it.
  StorageService? get _storage =>
      Get.isRegistered<StorageService>() ? Get.find<StorageService>() : null;
  final Rx<WardGoal> wardGoal = WardGoal.defaultGoal().obs;
  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    loadGoal();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => loadGoal());
  }

  @override
  void onReady() {
    super.onReady();
    if (Get.isRegistered<ReminderService>()) {
      Get.find<ReminderService>().requestPermissions();
    }
  }

  void loadGoal() {
    final storage = _storage;
    if (storage != null) {
      wardGoal.value = storage.getWardGoal();
    }
  }

  bool isDarkMode() {
    return _storage?.isDarkMode() ?? true;
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}
