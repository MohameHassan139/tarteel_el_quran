import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:quran_library/quran_library.dart' hide AudioService;
import 'package:get/get.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'core/storage_service.dart';
import 'core/api_service.dart';
import 'core/download_service.dart';
import 'core/audio_service.dart';
import 'core/reminder_service.dart';
import 'core/app_colors.dart';
import 'routes/app_routes.dart';
import 'routes/app_pages.dart';

Future<void> initServices() async {
  await Get.putAsync(() => StorageService().init());
  await Get.putAsync(() => ReminderService().init());
  Get.put(ApiService());
  Get.put(DownloadService());
  Get.put(AudioService());
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.tarteel.quran.audio',
    androidNotificationChannelName: 'Quran Playback',
    androidNotificationOngoing: true,
  );
  SurahState.setAudioServiceActive(true);
  await QuranLibrary.init();
  QuranLibrary.initWordAudio();
  await initServices();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = Get.find<StorageService>();
    final isDarkMode = storage.isDarkMode();
    final appLanguage = storage.getAppLanguage();

    return GetMaterialApp(
      title: 'ترتيل القرآن',
      debugShowCheckedModeBanner: false,

      locale: Locale(appLanguage),
      fallbackLocale: const Locale('ar'),
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      initialRoute: AppRoutes.HOME,
      getPages: AppPages.routes,

      // Light Mode Theme
      theme: ThemeData(
        useMaterial3: false, // Required by quran_library
        brightness: Brightness.light,
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.bgLight,
        cardColor: AppColors.cardLight,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          secondary: AppColors.accent,
          surface: AppColors.cardLight,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.black87,
          iconTheme: IconThemeData(color: Colors.black87),
          centerTitle: true,
          elevation: 0,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black87),
          bodyMedium: TextStyle(color: Colors.black54),
        ),
      ),

      // Dark Mode Theme
      darkTheme: ThemeData(
        useMaterial3: false, // Required by quran_library
        brightness: Brightness.dark,
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.bgDark,
        cardColor: AppColors.cardDark,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.accent,
          surface: AppColors.cardDark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.white),
          centerTitle: true,
          elevation: 0,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
        ),
      ),

      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
    );
  }
}
