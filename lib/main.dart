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
import 'core/reminder_service.dart';
import 'core/push_notification_service.dart';
import 'core/teacher_sync_service.dart';
import 'core/app_colors.dart';
import 'routes/app_routes.dart';
import 'routes/app_pages.dart';

import 'core/localization/app_translations.dart';

Future<void> initServices() async {
  try {
    await Get.putAsync(() => StorageService().init());
  } catch (e) {
    debugPrint('StorageService init error: $e');
  }

  try {
    await Get.putAsync(() => ConnectivityService().init());
  } catch (e) {
    debugPrint('ConnectivityService init error: $e');
  }

  try {
    await Get.putAsync(() => ReminderService().init());
  } catch (e) {
    debugPrint('ReminderService init error: $e');
  }

  try {
    await Get.putAsync(() => PushNotificationService().init());
  } catch (e) {
    debugPrint('PushNotificationService init error: $e');
  }

  // Guarded as a block: AudioService's constructor eagerly resolves
  // StorageService via Get.find (see audio_service.dart), which throws if
  // StorageService failed to register above. Left unguarded, that throw
  // used to escape all the way out of main() before runApp() ever ran —
  // an uncaught error at that point kills the whole app process instead of
  // just disabling a feature, which is exactly what "startup failure" on
  // the compatibility test farm looks like.
  try {
    Get.put(ApiService());
    Get.put(DownloadService());
    if (Get.isRegistered<StorageService>()) {
      Get.put(AudioService());
    } else {
      debugPrint('AudioService skipped: StorageService is not registered.');
    }
  } catch (e) {
    debugPrint('Core services init error: $e');
  }

  try {
    // Purely local: reads a role flag from Hive. No Firebase Auth/Firestore
    // call happens until the user explicitly activates student/teacher mode.
    await Get.putAsync(() => TeacherSyncService().init());
  } catch (e) {
    debugPrint('TeacherSyncService init error: $e');
  }
}

/// Every step below is already individually try/catch-guarded, but that
/// only protects against synchronous/Dart-level failures at each call site.
/// `runZonedGuarded` plus the two handlers below are the backstop: any
/// error that still escapes (e.g. thrown from a callback a plugin schedules
/// on its own, outside the `await` chain we control) is caught here instead
/// of taking down the whole app process. On a device farm that cold-launches
/// the app on many different OEM builds/Android versions, that backstop is
/// the difference between "one feature silently misbehaves" and a reported
/// startup crash.
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
      await QuranLibrary.init();
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
