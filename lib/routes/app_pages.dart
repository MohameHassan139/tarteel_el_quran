import 'package:get/get.dart';
import 'app_routes.dart';
import '../features/home/home_binding.dart';
import '../features/home/home_screen.dart';
import '../features/mushaf/mushaf_binding.dart';
import '../features/mushaf/mushaf_screen.dart';
import '../features/mushaf/mushaf_view_screen.dart';
import '../features/hifz/hifz_binding.dart';
import '../features/hifz/hifz_screen.dart';
import '../features/ward/ward_binding.dart';
import '../features/ward/ward_screen.dart';
import '../features/settings/settings_binding.dart';
import '../features/settings/settings_screen.dart';
import '../features/audio_hub/audio_hub_binding.dart';
import '../features/audio_hub/audio_hub_screen.dart';

abstract class AppPages {
  static final routes = [
    GetPage(
      name: AppRoutes.HOME,
      page: () => const HomeScreen(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: AppRoutes.MUSHAF,
      page: () => const MushafScreen(),
      binding: MushafBinding(),
    ),
    GetPage(
      name: AppRoutes.MUSHAF_VIEW,
      page: () => const MushafViewScreen(),
      binding: MushafViewBinding(),
    ),
    GetPage(
      name: AppRoutes.HIFZ,
      page: () => const HifzScreen(),
      binding: HifzBinding(),
    ),
    GetPage(
      name: AppRoutes.WARD,
      page: () => const WardScreen(),
      binding: WardBinding(),
    ),
    GetPage(
      name: AppRoutes.SETTINGS,
      page: () => const SettingsScreen(),
      binding: SettingsBinding(),
    ),
    GetPage(
      name: AppRoutes.AUDIO_HUB,
      page: () => const AudioHubScreen(),
      binding: AudioHubBinding(),
    ),
  ];
}
