import 'dart:convert';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:get/get.dart';
import '../models.dart';

class StorageService extends GetxService {
  static const String settingsBoxName = 'settings_box';
  static const String quranContentBoxName = 'quran_content_box';
  static const String downloadedAudioBoxName = 'downloaded_audio_box';
  static const String wardTrackerBoxName = 'ward_tracker_box';

  late Box _settingsBox;
  late Box _quranContentBox;
  late Box _downloadedAudioBox;
  late Box _wardTrackerBox;

  Future<StorageService> init() async {
    await Hive.initFlutter();
    _settingsBox = await Hive.openBox(settingsBoxName);
    _quranContentBox = await Hive.openBox(quranContentBoxName);
    _downloadedAudioBox = await Hive.openBox(downloadedAudioBoxName);
    _wardTrackerBox = await Hive.openBox(wardTrackerBoxName);
    return this;
  }

  // --- Settings Box Helpers ---

  int getSelectedReciterId() {
    return _settingsBox.get('selected_reciter_id', defaultValue: 7) as int;
  }

  Future<void> setSelectedReciterId(int id) async {
    await _settingsBox.put('selected_reciter_id', id);
  }

  String getSelectedStyle() {
    return _settingsBox.get('selected_style', defaultValue: 'murattal') as String;
  }

  Future<void> setSelectedStyle(String style) async {
    await _settingsBox.put('selected_style', style);
  }

  int getEffectiveReciterId() {
    final reciterId = getSelectedReciterId();
    final style = getSelectedStyle();
    if (reciterId == 6) {
      return style == 'mujawwad' ? 12 : 6; // Muallim for Al-Husary
    }
    if (reciterId == 2) {
      return style == 'mujawwad' ? 1 : 2; // Mujawwad for AbdulBaset
    }
    if (reciterId == 9) {
      return style == 'mujawwad' ? 8 : 9; // Mujawwad for Al-Minshawi
    }
    return reciterId; // Mishari is always 7
  }

  bool isDarkMode() {
    return _settingsBox.get('is_dark_mode', defaultValue: true) as bool;
  }

  Future<void> setDarkMode(bool isDark) async {
    await _settingsBox.put('is_dark_mode', isDark);
  }

  String getAppLanguage() {
    return _settingsBox.get('app_language', defaultValue: 'ar') as String;
  }

  Future<void> setAppLanguage(String lang) async {
    await _settingsBox.put('app_language', lang);
  }

  double getArabicFontSize() {
    return _settingsBox.get('arabic_font_size', defaultValue: 28.0) as double;
  }

  Future<void> setArabicFontSize(double size) async {
    await _settingsBox.put('arabic_font_size', size);
  }

  double getTranslationFontSize() {
    return _settingsBox.get('translation_font_size', defaultValue: 16.0) as double;
  }

  Future<void> setTranslationFontSize(double size) async {
    await _settingsBox.put('translation_font_size', size);
  }

  String? getCachedOAuthToken() {
    return _settingsBox.get('oauth_token') as String?;
  }

  int getCachedOAuthTokenExpiry() {
    return _settingsBox.get('oauth_token_expiry', defaultValue: 0) as int;
  }

  Future<void> cacheOAuthToken(String token, int expiresInSeconds) async {
    final expiryTime = DateTime.now().millisecondsSinceEpoch + (expiresInSeconds * 1000);
    await _settingsBox.put('oauth_token', token);
    await _settingsBox.put('oauth_token_expiry', expiryTime);
  }

  // --- Quran Content Box Helpers ---

  List<Chapter>? getCachedChapters() {
    final rawJson = _quranContentBox.get('chapters_list') as String?;
    if (rawJson == null) return null;
    try {
      final decoded = jsonDecode(rawJson) as List;
      return decoded.map((e) => Chapter.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheChapters(List<Chapter> chapters) async {
    final rawJson = jsonEncode(chapters.map((e) => e.toJson()).toList());
    await _quranContentBox.put('chapters_list', rawJson);
  }

  List<Verse>? getCachedVerses(int chapterId) {
    final rawJson = _quranContentBox.get('verses_chapter_$chapterId') as String?;
    if (rawJson == null) return null;
    try {
      final decoded = jsonDecode(rawJson) as List;
      return decoded.map((e) => Verse.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheVerses(int chapterId, List<Verse> verses) async {
    final rawJson = jsonEncode(verses.map((e) => e.toJson()).toList());
    await _quranContentBox.put('verses_chapter_$chapterId', rawJson);
  }

  List<VerseTiming>? getCachedTimings(int reciterId, int chapterId) {
    final rawJson = _quranContentBox.get('timings_${reciterId}_$chapterId') as String?;
    if (rawJson == null) return null;
    try {
      final decoded = jsonDecode(rawJson) as List;
      return decoded.map((e) => VerseTiming.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheTimings(int reciterId, int chapterId, List<VerseTiming> timings) async {
    final rawJson = jsonEncode(timings.map((e) => e.toJson()).toList());
    await _quranContentBox.put('timings_${reciterId}_$chapterId', rawJson);
  }

  String? getCachedTafsir(int tafsirId, String verseKey) {
    return _quranContentBox.get('tafsir_${tafsirId}_$verseKey') as String?;
  }

  Future<void> cacheTafsir(int tafsirId, String verseKey, String tafsirText) async {
    await _quranContentBox.put('tafsir_${tafsirId}_$verseKey', tafsirText);
  }

  // --- Downloaded Audio Box Helpers ---

  String? getDownloadedAudioPath(int reciterId, int chapterId) {
    return _downloadedAudioBox.get('audio_${reciterId}_$chapterId') as String?;
  }

  Future<void> setDownloadedAudioPath(int reciterId, int chapterId, String filePath) async {
    await _downloadedAudioBox.put('audio_${reciterId}_$chapterId', filePath);
  }

  Future<void> deleteDownloadedAudioPath(int reciterId, int chapterId) async {
    await _downloadedAudioBox.delete('audio_${reciterId}_$chapterId');
  }

  bool isChapterDownloaded(int reciterId, int chapterId) {
    final path = getDownloadedAudioPath(reciterId, chapterId);
    if (path == null) return false;
    return File(path).existsSync();
  }

  // --- Ward Tracker Box Helpers ---

  WardGoal getWardGoal() {
    final rawJson = _wardTrackerBox.get('ward_goal') as String?;
    if (rawJson == null) {
      return WardGoal.defaultGoal();
    }
    try {
      final goal = WardGoal.fromJson(jsonDecode(rawJson) as Map<String, dynamic>);
      // Reset daily stopwatch if date changed
      final todayStr = WardGoal.defaultGoal().lastLoggedDate;
      if (goal.lastLoggedDate != todayStr) {
        // Save previous day progress to history before resetting
        _saveToHistory(goal.lastLoggedDate, goal.activeSecondsToday);
        final newGoal = goal.copyWith(
          activeSecondsToday: 0,
          lastLoggedDate: todayStr,
        );
        saveWardGoal(newGoal);
        return newGoal;
      }
      return goal;
    } catch (_) {
      return WardGoal.defaultGoal();
    }
  }

  Future<void> saveWardGoal(WardGoal goal) async {
    final rawJson = jsonEncode(goal.toJson());
    await _wardTrackerBox.put('ward_goal', rawJson);
  }

  void _saveToHistory(String dateStr, int seconds) {
    final history = getWardHistory();
    history[dateStr] = seconds;
    _wardTrackerBox.put('ward_history', jsonEncode(history));
  }

  Map<String, int> getWardHistory() {
    final rawJson = _wardTrackerBox.get('ward_history') as String?;
    if (rawJson == null) return {};
    try {
      final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, value as int));
    } catch (_) {
      return {};
    }
  }

  Future<void> logReadingSeconds(int seconds) async {
    final goal = getWardGoal();
    final updated = goal.copyWith(
      activeSecondsToday: goal.activeSecondsToday + seconds,
    );
    await saveWardGoal(updated);
  }
}
