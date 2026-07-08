import 'dart:async';
import 'package:get/get.dart';
import '../../core/storage_service.dart';
import '../../models.dart';

class HomeController extends GetxController {
  final StorageService _storage = Get.find<StorageService>();
  final Rx<WardGoal> wardGoal = WardGoal.defaultGoal().obs;
  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    loadGoal();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => loadGoal());
  }

  void loadGoal() {
    wardGoal.value = _storage.getWardGoal();
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
