import 'package:get/get.dart';
import 'rare_recitations_controller.dart';

class RareRecitationsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<RareRecitationsController>(() => RareRecitationsController());
  }
}
