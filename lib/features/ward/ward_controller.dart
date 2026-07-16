import 'dart:async';
import 'package:get/get.dart';
import '../../core/storage_service.dart';
import '../../core/reminder_service.dart';
import '../../models.dart';

class WardController extends GetxController {
  final StorageService _storage = Get.find<StorageService>();
  final ReminderService _reminder = Get.find<ReminderService>();

  final Rx<WardGoal> wardGoal = WardGoal.defaultGoal().obs;
  final RxMap<String, int> history = <String, int>{}.obs;
  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    loadData();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      loadGoal();
    });
  }

  void loadData() {
    loadGoal();
    history.assignAll(_storage.getWardHistory());
  }

  void loadGoal() {
    wardGoal.value = _storage.getWardGoal();
  }

  Future<void> updateTargetMinutes(int minutes) async {
    final updated = wardGoal.value.copyWith(targetMinutes: minutes);
    await _storage.saveWardGoal(updated);
    await _reminder.scheduleDailyReminder(updated.reminderHour, updated.reminderMinute);
    wardGoal.value = updated;
  }

  Future<void> setReminderTime(int hour, int minute) async {
    final updated = wardGoal.value.copyWith(
      reminderHour: hour,
      reminderMinute: minute,
    );
    await _storage.saveWardGoal(updated);
    await _reminder.scheduleDailyReminder(hour, minute);
    wardGoal.value = updated;
  }

  bool isDarkMode() {
    return _storage.isDarkMode();
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}
