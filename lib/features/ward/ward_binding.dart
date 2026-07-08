import 'package:get/get.dart';
import 'ward_controller.dart';

class WardBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<WardController>(() => WardController());
  }
}
