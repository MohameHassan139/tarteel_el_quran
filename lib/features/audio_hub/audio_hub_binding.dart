import 'package:get/get.dart';
import 'audio_hub_controller.dart';

class AudioHubBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AudioHubController>(() => AudioHubController());
  }
}
