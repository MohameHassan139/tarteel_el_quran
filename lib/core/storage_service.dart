import 'dart:convert';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:get/get.dart';
import '../models.dart';
import 'reminder_service.dart';

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
    final targetSeconds = goal.targetMinutes * 60;
    final oldSeconds = goal.activeSecondsToday;
    final newSeconds = oldSeconds + seconds;

    final updated = goal.copyWith(
      activeSecondsToday: newSeconds,
    );
    await saveWardGoal(updated);

    // Reschedule or celebrate on state transitions
    final justStarted = oldSeconds == 0 && newSeconds > 0;
    final justCompleted = oldSeconds < targetSeconds && newSeconds >= targetSeconds;

    if (justStarted || justCompleted) {
      try {
        final reminder = Get.find<ReminderService>();
        if (justCompleted) {
          await reminder.showCelebrationNotification();
        }
        await reminder.rescheduleAllReminders();
      } catch (_) {}
    }
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

  // --- Customizable Reminder Messages Helpers ---

  List<ReminderMessage> getReminderMessages() {
    final rawJson = _wardTrackerBox.get('reminder_messages') as String?;
    if (rawJson == null) {
      final defaults = [
        ReminderMessage(
          id: 'start_1',
          category: 'start',
          textAr: '﴿ وَرَتِّلِ الْقُرْآنَ تَرْتِيلًا ﴾\nحان موعد وردك اليومي، فاجعل لك نصيبًا من كلام الله.',
          textEn: '"And recite the Quran with measured recitation."\nIt is time for your daily Wird, so make for yourself a portion of the Words of Allah.',
        ),
        ReminderMessage(
          id: 'start_2',
          category: 'start',
          textAr: '«خيركم من تعلَّم القرآن وعلَّمه»\nابدأ وردك اليومي، فالخير في صحبة القرآن.',
          textEn: '"The best of you are those who learn the Quran and teach it."\nStart your daily Wird, for goodness lies in the companionship of the Quran.',
        ),
        ReminderMessage(
          id: 'start_3',
          category: 'start',
          textAr: '﴿ أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ ﴾\nاجعل دقائق من يومك مع القرآن، ففيه الطمأنينة.',
          textEn: '"Unquestionably, by the remembrance of Allah hearts are assured."\nSpend a few minutes of your day with the Quran, for in it is tranquility.',
        ),
        ReminderMessage(
          id: 'start_4',
          category: 'start',
          textAr: 'اليوم صفحة جديدة مع كتاب الله...\nابدأ وردك، فما تقرؤه اليوم يكون نورًا لك غدًا.',
          textEn: 'Today is a new page with the Book of Allah...\nStart your Wird, for what you read today will be a light for you tomorrow.',
        ),
        ReminderMessage(
          id: 'incomplete_1',
          category: 'incomplete',
          textAr: 'ما زال وردك ينتظرك...\n﴿ وَقُرْآنَ الْفَجْرِ ۖ إِنَّ قُرْآنَ الْفَجْرِ كَانَ مَشْهُودًا ﴾',
          textEn: 'Your Wird is still waiting for you...\n"And the recitation of dawn; indeed, the recitation of dawn is ever witnessed."',
        ),
        ReminderMessage(
          id: 'incomplete_2',
          category: 'incomplete',
          textAr: 'لم يبقَ إلا القليل...\nأتمَّ وردك، فـ «أحب الأعمال إلى الله أدومها وإن قل».',
          textEn: 'Only a little remains...\nComplete your Wird, for "the most beloved of deeds to Allah are those that are most consistent, even if they are small."',
        ),
        ReminderMessage(
          id: 'incomplete_3',
          category: 'incomplete',
          textAr: 'لا تدع يومك يمضي دون أن تختم وردك،\nفلعل آيةً تقرؤها تكون سببًا في هداية قلبك.',
          textEn: 'Do not let your day pass without completing your Wird,\nfor perhaps a verse you read will be the cause of guiding your heart.',
        ),
        ReminderMessage(
          id: 'incomplete_4',
          category: 'incomplete',
          textAr: 'اقتربت نهاية يومك، وما زال لك موعد مع القرآن...\nأكمل وردك، فإن خير الزاد كلام الله.',
          textEn: 'The end of your day is approaching, and you still have an appointment with the Quran...\nComplete your Wird, for the best provision is the Word of Allah.',
        ),
        ReminderMessage(
          id: 'completed_1',
          category: 'completed',
          textAr: 'بارك الله فيك.\nأتممت وردك اليومي، نسأل الله أن يجعل القرآن ربيع قلبك ونور صدرك.',
          textEn: 'May Allah bless you.\nYou have completed your daily Wird. We ask Allah to make the Quran the spring of your heart and the light of your chest.',
        ),
        ReminderMessage(
          id: 'completed_2',
          category: 'completed',
          textAr: 'هنيئًا لك إتمام وردك.\n﴿ إِنَّ هَٰذَا الْقُرْآنَ يَهْدِي لِلَّتِي هِيَ أَقْوَمُ ﴾\nنسأل الله أن يجعلك من أهل القرآن.',
          textEn: 'Congratulations on completing your Wird.\n"Indeed, this Quran guides to that which is most suitable."\nWe ask Allah to make you among the people of the Quran.',
        ),
        ReminderMessage(
          id: 'completed_3',
          category: 'completed',
          textAr: 'ما أجمل أن يُختتم يومك بكلام الله.\nتقبّل الله منك، وبارك لك في تلاوتك.',
          textEn: 'How beautiful it is to end your day with the Words of Allah.\nMay Allah accept from you and bless your recitation.',
        ),
        ReminderMessage(
          id: 'completed_4',
          category: 'completed',
          textAr: 'اليوم أكرمك الله بإتمام وردك،\nفاثبت على هذه النعمة، فإن «أحب الأعمال إلى الله أدومها وإن قل».',
          textEn: 'Today Allah has graced you with completing your Wird.\nSo remain steadfast upon this blessing, for "the most beloved of deeds to Allah are those that are most consistent, even if they are small."',
        ),
      ];
      saveReminderMessages(defaults);
      return defaults;
    }
    try {
      final decoded = jsonDecode(rawJson) as List;
      return decoded.map((e) => ReminderMessage.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveReminderMessages(List<ReminderMessage> messages) async {
    final rawJson = jsonEncode(messages.map((e) => e.toJson()).toList());
    await _wardTrackerBox.put('reminder_messages', rawJson);
  }
}

