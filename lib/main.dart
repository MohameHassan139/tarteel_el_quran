import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:quran_library/quran_library.dart' hide AudioService;
import 'package:get/get.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'core/storage_service.dart';
import 'core/connectivity_service.dart';
import 'core/api_service.dart';
import 'core/download_service.dart';
import 'core/audio_service.dart';
import 'core/sheikh_image_service.dart';
import 'core/reminder_service.dart';
import 'core/push_notification_service.dart';
import 'core/teacher_sync_service.dart';
import 'core/app_colors.dart';
import 'routes/app_routes.dart';
import 'routes/app_pages.dart';

import 'core/localization/app_translations.dart';

Future<void> initServices() async {
  // 1. Fast local Hive storage: Register instance immediately so Get.find never fails
  final storageService = StorageService();
  Get.put<StorageService>(storageService, permanent: true);
  try {
    await storageService.init().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        debugPrint('StorageService init timed out, using fallback');
        return storageService;
      },
    );
  } catch (e) {
    debugPrint('StorageService init error: $e');
  }

  // 2. Local connectivity state
  final connectivityService = ConnectivityService();
  Get.put<ConnectivityService>(connectivityService, permanent: true);
  try {
    await connectivityService.init().timeout(
      const Duration(seconds: 4),
      onTimeout: () => connectivityService,
    );
  } catch (e) {
    debugPrint('ConnectivityService init error: $e');
  }

  // 3. Reminder & local notifications
  final reminderService = ReminderService();
  Get.put<ReminderService>(reminderService, permanent: true);
  try {
    await reminderService.init().timeout(
      const Duration(seconds: 4),
      onTimeout: () => reminderService,
    );
  } catch (e) {
    debugPrint('ReminderService init error: $e');
  }

  // 4. Push notifications (non-blocking FCM)
  final pushService = PushNotificationService();
  Get.put<PushNotificationService>(pushService, permanent: true);
  try {
    await pushService.init().timeout(
      const Duration(seconds: 4),
      onTimeout: () => pushService,
    );
  } catch (e) {
    debugPrint('PushNotificationService init error: $e');
  }

  // 5. Synchronous core services
  try {
    Get.put(ApiService(), permanent: true);
    Get.put(DownloadService(), permanent: true);
    Get.put(SheikhImageService(), permanent: true);
    Get.put(AudioService(), permanent: true);
  } catch (e) {
    debugPrint('Core services init error: $e');
  }

  // 6. Teacher Sync Service (purely local Hive role read)
  final teacherSyncService = TeacherSyncService();
  Get.put<TeacherSyncService>(teacherSyncService, permanent: true);
  try {
    await teacherSyncService.init().timeout(
      const Duration(seconds: 4),
      onTimeout: () => teacherSyncService,
    );
  } catch (e) {
    debugPrint('TeacherSyncService init error: $e');
  }
}

/// Robust startup ensuring all core services are registered before first frame
/// to prevent race conditions and "service not found" crashes during monkey tests.
void main() {
  runZonedGuarded<void>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError (caught, non-fatal): ${details.exceptionAsString()}');
    };
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      debugPrint('Uncaught platform error (caught, non-fatal): $error');
      return true; // handled — do not let it propagate and crash the app.
    };

    // Loads local Firebase app config only — no network call, no sign-in.
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('Firebase init error: $e');
    }

    try {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.tarteel.quran.audio',
        androidNotificationChannelName: 'Quran Playback',
        androidNotificationOngoing: true,
      );
    } catch (e) {
      debugPrint('JustAudioBackground init error: $e');
    }

    try {
      SurahState.setAudioServiceActive(true);
      await QuranLibrary.init().timeout(
        const Duration(seconds: 3),
        onTimeout: () => debugPrint('QuranLibrary init timed out'),
      );
      QuranLibrary.initWordAudio();
    } catch (e) {
      debugPrint('QuranLibrary init error: $e');
    }

    await initServices();
    runApp(const MyApp());
  }, (error, stack) {
    debugPrint('Uncaught zone error (caught, non-fatal): $error\n$stack');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = Get.isRegistered<StorageService>() ? Get.find<StorageService>() : null;
    final isDarkMode = storage?.isDarkMode() ?? true;
    final appLanguage = storage?.getAppLanguage() ?? 'ar';

    return GetMaterialApp(
      title: 'app_title'.tr,
      debugShowCheckedModeBanner: false,

      translations: AppTranslations(),
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
