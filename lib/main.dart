import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:quran_library/quran_library.dart' hide AudioService;
import 'package:get/get.dart';
import 'core/storage_service.dart';
import 'core/api_service.dart';
import 'core/download_service.dart';
import 'core/audio_service.dart';
import 'core/reminder_service.dart';
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
        primaryColor: const Color(0xFFC19A6B),
        scaffoldBackgroundColor: const Color(0xFFFAF8F5),
        cardColor: const Color(0xFFF4EFE6),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFC19A6B),
          secondary: Color(0xFFE5DCD0),
          surface: Color(0xFFF4EFE6),
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
        primaryColor: const Color(0xFFC19A6B),
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFC19A6B),
          secondary: Color(0xFF2C2C2C),
          surface: Color(0xFF1E1E1E),
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
