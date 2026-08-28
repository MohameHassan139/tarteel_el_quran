import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
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
    _settingsBox = await _openBoxSafely(settingsBoxName);
    _quranContentBox = await _openBoxSafely(quranContentBoxName);
    _downloadedAudioBox = await _openBoxSafely(downloadedAudioBoxName);
    _wardTrackerBox = await _openBoxSafely(wardTrackerBoxName);
    return this;
  }

  /// Opens a Hive box, self-healing if the box file on disk is corrupted.
  ///
  /// A box can end up corrupted if the process is killed mid-write (OS low
  /// memory killer, forced-stop during a compatibility/monkey test, battery
  /// optimization on some OEMs, etc.). Without this guard, `Hive.openBox`
  /// throws on every subsequent launch, that exception propagates out of
  /// `StorageService.init()`, and — because several other services fetch
  /// this one eagerly via `Get.find<StorageService>()` — the app can never
  /// start again until its data is cleared. Deleting and recreating just the
  /// broken box trades a one-time loss of that box's cached data for an app
  /// that reliably starts.
  Future<Box> _openBoxSafely(String name) async {
    try {
      return await Hive.openBox(name);
    } catch (e) {
      debugPrint('StorageService: box "$name" failed to open ($e) — resetting it.');
      try {
        await Hive.deleteBoxFromDisk(name);
      } catch (deleteError) {
        debugPrint('StorageService: failed to delete corrupted box "$name": $deleteError');
      }
      return await Hive.openBox(name);
    }
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
      if (style == 'mujawwad') return 12;
      if (style == 'teacher') return 13;
      return 6;
    }
    if (reciterId == 2) {
      return style == 'mujawwad' ? 1 : 2;
    }
    if (reciterId == 9) {
      return style == 'mujawwad' ? 8 : 9;
    }
    return reciterId;
  }

  bool isDarkMode() {
    return _settingsBox.get('is_dark_mode', defaultValue: true) as bool;
  }

  Future<void> setDarkMode(bool isDark) async {
    await _settingsBox.put('is_dark_mode', isDark);
  }

  bool getKeepScreenOn() {
    return _settingsBox.get('keep_screen_on', defaultValue: true) as bool;
  }

  Future<void> setKeepScreenOn(bool value) async {
    await _settingsBox.put('keep_screen_on', value);
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

  String? getCachedTafsir(int tafsirId, String verseKey) {
    return _quranContentBox.get('tafsir_${tafsirId}_$verseKey') as String?;
  }

  Future<void> cacheTafsir(int tafsirId, String verseKey, String tafsirText) async {
    await _quranContentBox.put('tafsir_${tafsirId}_$verseKey', tafsirText);
  }

  // --- Downloaded Audio Box Helpers ---

  String? getDownloadedAudioDirectory(int reciterId, int chapterId) {
    return _downloadedAudioBox.get('audio_dir_${reciterId}_$chapterId') as String?;
  }

  Future<void> setDownloadedAudioDirectory(int reciterId, int chapterId, String directoryPath) async {
    await _downloadedAudioBox.put('audio_dir_${reciterId}_$chapterId', directoryPath);
  }

  Future<void> deleteDownloadedAudioDirectory(int reciterId, int chapterId) async {
    await _downloadedAudioBox.delete('audio_dir_${reciterId}_$chapterId');
  }

  bool isChapterDownloaded(int reciterId, int chapterId, int versesCount) {
    final dirPath = getDownloadedAudioDirectory(reciterId, chapterId);
    if (dirPath == null) return false;
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return false;
    
    // Check if the directory has the correct number of mp3 files (verse-by-verse) or exactly 1 file (single full-surah file)
    final files = dir.listSync().where((f) => f.path.endsWith('.mp3')).toList();
    return files.length == versesCount || files.length == 1;
  }

  /// Get downloaded audio file path(s) or empty list if not downloaded.
  /// If it is a single-file download (e.g. from mp3quran.net), it returns a list containing that single file.
  /// If it is verse-by-verse, it returns a list of files matching the surah verses.
  List<String> getChapterAudioPathsOrUrls(int reciterId, int chapterId, int versesCount) {
    final dirPath = getDownloadedAudioDirectory(reciterId, chapterId);
    if (dirPath != null) {
      final dir = Directory(dirPath);
      if (dir.existsSync()) {
        final files = dir.listSync().where((f) => f.path.endsWith('.mp3')).toList();
        if (files.length == 1) {
          return [files.first.path];
        } else if (files.length == versesCount) {
          return List.generate(versesCount, (i) => '$dirPath/${i+1}.mp3');
        }
      }
    }
    return [];
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

  // --- mp3quran.net Cache & Selection Helpers ---

  List<Mp3QuranReciter>? getCachedMp3QuranReciters() {
    final rawJson = _quranContentBox.get('mp3quran_reciters') as String?;
    if (rawJson == null) return null;
    try {
      final decoded = jsonDecode(rawJson) as List;
      return decoded.map((e) => Mp3QuranReciter.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheMp3QuranReciters(List<Mp3QuranReciter> list) async {
    final rawJson = jsonEncode(list.map((e) => e.toJson()).toList());
    await _quranContentBox.put('mp3quran_reciters', rawJson);
  }

  int getSelectedMp3ReciterId() {
    return _settingsBox.get('selected_mp3_reciter_id', defaultValue: 123) as int; // Default to Alafasy (id 123)
  }

  Future<void> setSelectedMp3ReciterId(int id) async {
    await _settingsBox.put('selected_mp3_reciter_id', id);
  }

  int getSelectedMp3MoshafId(int reciterId) {
    return _settingsBox.get('selected_mp3_moshaf_id_$reciterId', defaultValue: 0) as int;
  }

  Future<void> setSelectedMp3MoshafId(int reciterId, int moshafId) async {
    await _settingsBox.put('selected_mp3_moshaf_id_$reciterId', moshafId);
  }

  // --- mp3quran.net Download Helpers ---

  String? getMp3QuranDownloadedAudioDirectory(int reciterId, int moshafId, int chapterId) {
    return _downloadedAudioBox.get('mp3_audio_dir_${reciterId}_${moshafId}_$chapterId') as String?;
  }

  Future<void> setMp3QuranDownloadedAudioDirectory(int reciterId, int moshafId, int chapterId, String directoryPath) async {
    await _downloadedAudioBox.put('mp3_audio_dir_${reciterId}_${moshafId}_$chapterId', directoryPath);
  }

  Future<void> deleteMp3QuranDownloadedAudioDirectory(int reciterId, int moshafId, int chapterId) async {
    await _downloadedAudioBox.delete('mp3_audio_dir_${reciterId}_${moshafId}_$chapterId');
  }

  bool isMp3QuranChapterDownloaded(int reciterId, int moshafId, int chapterId) {
    final dirPath = getMp3QuranDownloadedAudioDirectory(reciterId, moshafId, chapterId);
    if (dirPath == null) return false;
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return false;
    final files = dir.listSync().where((f) => f.path.endsWith('.mp3')).toList();
    return files.length == 1; // Always a single file download
  }

  // --- Quran Memorization (Hifz) Helpers ---

  Map<String, dynamic>? getLastHifzSession() {
    final rawJson = _settingsBox.get('last_hifz_session') as String?;
    if (rawJson == null) return null;
    try {
      return jsonDecode(rawJson) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLastHifzSession(Map<String, dynamic> session) async {
    await _settingsBox.put('last_hifz_session', jsonEncode(session));
  }

  List<Map<String, dynamic>> getHifzHistory() {
    final rawJson = _settingsBox.get('hifz_history') as String?;
    if (rawJson == null) return [];
    try {
      final decoded = jsonDecode(rawJson) as List;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveHifzHistory(List<Map<String, dynamic>> history) async {
    await _settingsBox.put('hifz_history', jsonEncode(history));
  }

  // --- Teacher/Student linking (local-only bookkeeping; cloud data lives in Firestore) ---

  /// '' | 'student' | 'teacher' | 'both'. Reading/writing this never touches the network.
  String getTeacherLinkRole() {
    return _settingsBox.get('teacher_link_role', defaultValue: '') as String;
  }

  Future<void> setTeacherLinkRole(String role) async {
    await _settingsBox.put('teacher_link_role', role);
  }

  /// IDs of local Hifz history entries already mirrored to Firestore, so a
  /// session is never uploaded twice.
  Set<String> getSyncedHifzSessionIds() {
    final rawJson = _settingsBox.get('teacher_link_synced_session_ids') as String?;
    if (rawJson == null) return {};
    try {
      final decoded = jsonDecode(rawJson) as List;
      return decoded.map((e) => e as String).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> addSyncedHifzSessionId(String sessionId) async {
    final ids = getSyncedHifzSessionIds()..add(sessionId);
    await _settingsBox.put('teacher_link_synced_session_ids', jsonEncode(ids.toList()));
  }

  bool isWardBackfillDone() {
    return _settingsBox.get('teacher_link_ward_backfill_done', defaultValue: false) as bool;
  }

  Future<void> setWardBackfillDone(bool done) async {
    await _settingsBox.put('teacher_link_ward_backfill_done', done);
  }

  /// Local cache of the student's own profile, so it displays instantly and
  /// survives offline even though the source of truth is Firestore.
  Map<String, dynamic>? getStudentProfileCache() {
    final rawJson = _settingsBox.get('teacher_link_student_profile') as String?;
    if (rawJson == null) return null;
    try {
      return jsonDecode(rawJson) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> setStudentProfileCache(Map<String, dynamic> profile) async {
    await _settingsBox.put('teacher_link_student_profile', jsonEncode(profile));
  }

  /// Local cache of linked teachers (id + display name), used to populate the
  /// "share this session with" picker without a network round trip.
  List<Map<String, dynamic>> getLinkedTeachersCache() {
    final rawJson = _settingsBox.get('teacher_link_linked_teachers') as String?;
    if (rawJson == null) return [];
    try {
      final decoded = jsonDecode(rawJson) as List;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> setLinkedTeachersCache(List<Map<String, dynamic>> teachers) async {
    await _settingsBox.put('teacher_link_linked_teachers', jsonEncode(teachers));
  }

  /// Local cache of this device's own teacher profile (display name + share code).
  Map<String, dynamic>? getTeacherProfileCache() {
    final rawJson = _settingsBox.get('teacher_link_teacher_profile') as String?;
    if (rawJson == null) return null;
    try {
      return jsonDecode(rawJson) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> setTeacherProfileCache(Map<String, dynamic> profile) async {
    await _settingsBox.put('teacher_link_teacher_profile', jsonEncode(profile));
  }

  /// Per-day Audio Hub listening seconds (date -> seconds), same shape as
  /// getWardHistory() but independent of it since Audio Hub listening has no
  /// daily-goal concept — just a running per-day counter.
  Map<String, int> getAudioDailySeconds() {
    final rawJson = _settingsBox.get('audio_listening_daily') as String?;
    if (rawJson == null) return {};
    try {
      final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, value as int));
    } catch (_) {
      return {};
    }
  }

  Future<void> logAudioListeningSeconds(int seconds) async {
    final today = _todayDateString();
    final map = getAudioDailySeconds();
    map[today] = (map[today] ?? 0) + seconds;
    await _settingsBox.put('audio_listening_daily', jsonEncode(map));
  }

  String _todayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> clearTeacherLinkLocalData() async {
    await _settingsBox.delete('teacher_link_role');
    await _settingsBox.delete('teacher_link_synced_session_ids');
    await _settingsBox.delete('teacher_link_ward_backfill_done');
    await _settingsBox.delete('teacher_link_student_profile');
    await _settingsBox.delete('teacher_link_linked_teachers');
    await _settingsBox.delete('teacher_link_teacher_profile');
  }
}

