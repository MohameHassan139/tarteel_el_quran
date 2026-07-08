import 'package:get/get.dart';
import 'hifz_controller.dart';

class HifzBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HifzController>(() => HifzController());
  }
}
