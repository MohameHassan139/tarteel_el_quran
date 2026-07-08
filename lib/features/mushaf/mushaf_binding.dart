import 'package:get/get.dart';
import 'mushaf_controller.dart';
import 'mushaf_view_controller.dart';

class MushafBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MushafController>(() => MushafController());
  }
}

class MushafViewBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MushafViewController>(() => MushafViewController());
  }
}
