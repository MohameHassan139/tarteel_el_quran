import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:quran_library/quran_library.dart' hide AudioService;
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/audio_service.dart';
import '../../core/api_service.dart';
import '../../core/storage_service.dart';
import '../../core/download_service.dart';
import '../../core/app_colors.dart';
import '../../core/teacher_sync_service.dart';
import '../../core/reminder_service.dart';
import '../../core/surah_display.dart';
import '../../models.dart';

class HifzController extends GetxController {
  final AudioService _audio = Get.find<AudioService>();
  final ApiService _api = Get.find<ApiService>();
  final StorageService _storage = Get.find<StorageService>();
  final DownloadService _downloadService = Get.find<DownloadService>();

  // Landing tab state: 0 = New Session, 1 = Progress/History
  final RxInt activeTabIndex = 0.obs;

  final RxList<Chapter> chapters = <Chapter>[].obs;
  final Rxn<Chapter> selectedChapter = Rxn<Chapter>();
  
  // Interactive Ayah pickers
  final RxInt startAyah = 1.obs;
  final RxInt endAyah = 7.obs;

  // Custom loops and delay settings
  final RxInt verseRepetitions = 3.obs;
  final RxInt rangeRepetitions = 2.obs;
  final RxInt delaySeconds = 0.obs;

  // Reciter state
  final RxInt selectedReciterId = 7.obs;
  final RxString selectedStyle = 'murattal'.obs;

  // Surah audio download state
  final RxBool isDownloadingSurah = false.obs;
  final RxDouble downloadProgress = 0.0.obs;

  // Translation selection states
  final RxBool showTranslation = false.obs;
  final RxInt selectedTranslationIndex = 0.obs;
  final RxList<TafsirNameModel> availableTranslations = <TafsirNameModel>[].obs;

  // Memorization Workspace state
  final RxBool isHifzActive = false.obs;
  final RxBool isLoading = false.obs;
  final RxList<Verse> hifzVerses = <Verse>[].obs;
  final Rxn<Verse> currentRecitingVerse = Rxn<Verse>();

  // Student aids (masking & text sizing)
  final RxBool maskText = false.obs;
  final RxSet<int> revealedVerseIds = <int>{}.obs;
  final RxDouble arabicFontSize = 28.0.obs;
  final RxDouble translationFontSize = 16.0.obs;

  // Tajweed coloring for the workspace ayah (persisted per user).
  final RxBool showTajweed = false.obs;

  /// True once the audio engine finished every verse/range repetition. The
  /// last verse stays on screen so the student can save or replay.
  final RxBool sessionCompleted = false.obs;

  // Hifz history progress list
  final RxList<Map<String, dynamic>> hifzHistoryList = <Map<String, dynamic>>[].obs;

  StreamSubscription? _activeVerseSub;
  DateTime? _sessionStartedAt;
  Timer? _liveActivityTimer;
  Timer? _wardStopwatchTimer;
  int _wardTickCount = 0;

  /// quran_library keeps ONE global Tajweed flag (shared with the Mushaf
  /// screen and persisted in GetStorage), and `GetSingleAyah` overwrites it on
  /// every build. We remember the Mushaf's value when the workspace opens and
  /// put it back when it closes, so Hifz never silently changes the Mushaf.
  bool? _savedGlobalTajweed;
  static const String _libTajweedStorageKey = 'isTajweed';

  // Kept so a completed loop can be replayed without refetching URLs.
  List<String> _lastAudioPaths = const [];
  HifzLoopConfig? _lastLoopConfig;
  StreamSubscription? _loopFinishedSub;

  StorageService get storage => _storage;

  @override
  void onInit() {
    super.onInit();
    selectedReciterId.value = _storage.getSelectedReciterId();
    selectedStyle.value = _storage.getSelectedStyle();
    loadChapters();
    loadLastSession();
    loadHistory();
    loadTranslations();
    loadFontSizes();
    showTajweed.value = _storage.getHifzShowTajweed();
    initQuranData();

    // Listen to changes in the active reciting verse
    _activeVerseSub = _audio.activeVerseKey.listen((activeKey) {
      _onActiveVerseChanged(activeKey);
    });
    _loopFinishedSub = _audio.hifzLoopFinished.listen((finished) {
      if (finished && isHifzActive.value) sessionCompleted.value = true;
    });
  }

  Future<void> initQuranData() async {
    try {
      await QuranCtrl.instance.ensureCoreDataLoaded();
      if (chapters.isEmpty) {
        loadChapters();
      }
      update();
    } catch (_) {}
  }

  void loadChapters() {
    final cached = _storage.getCachedChapters();
    if (cached != null && cached.isNotEmpty) {
      chapters.assignAll(cached);
      selectedChapter.value = cached.first;
      startAyah.value = 1;
      endAyah.value = cached.first.versesCount;
      return;
    }
    if (QuranCtrl.instance.surahsList.isNotEmpty) {
      final offlineList = QuranCtrl.instance.surahsList.map((s) => Chapter(
        id: s.number,
        nameSimple: s.englishName,
        nameComplex: s.englishName,
        nameArabic: s.name,
        versesCount: s.ayahsNumber,
        revelationPlace: s.revelationType,
        revelationOrder: 0,
        translatedName: s.englishNameTranslation,
      )).toList();
      chapters.assignAll(offlineList);
      selectedChapter.value = offlineList.first;
      startAyah.value = 1;
      endAyah.value = offlineList.first.versesCount;
      unawaited(_storage.cacheChapters(offlineList));
    }
  }

  void loadTranslations() async {
    try {
      await TafsirCtrl.instance.initTafsir();
      final items = TafsirCtrl.instance.tafsirAndTranslationsItems;
      availableTranslations.assignAll(items);
      
      final session = _storage.getLastHifzSession();
      if (session != null && session.containsKey('translationIndex')) {
        selectedTranslationIndex.value = session['translationIndex'] as int;
      } else {
        selectedTranslationIndex.value = TafsirCtrl.instance.translationsStartIndex;
      }
    } catch (_) {}
  }

  void loadFontSizes() {
    arabicFontSize.value = _storage.getArabicFontSize();
    translationFontSize.value = _storage.getTranslationFontSize();
  }

  Future<void> updateArabicFontSize(double size) async {
    arabicFontSize.value = size;
    await _storage.setArabicFontSize(size);
  }

  Future<void> updateTranslationFontSize(double size) async {
    translationFontSize.value = size;
    await _storage.setTranslationFontSize(size);
  }

  void loadHistory() {
    final history = _storage.getHifzHistory();
    hifzHistoryList.assignAll(history);
  }

  void saveSessionState() {
    final chapter = selectedChapter.value;
    if (chapter == null) return;
    final session = {
      'chapterId': chapter.id,
      'startAyah': startAyah.value,
      'endAyah': endAyah.value,
      'verseRepetitions': verseRepetitions.value,
      'rangeRepetitions': rangeRepetitions.value,
      'delaySeconds': delaySeconds.value,
      'reciterId': selectedReciterId.value,
      'style': selectedStyle.value,
      'showTranslation': showTranslation.value,
      'translationIndex': selectedTranslationIndex.value,
    };
    _storage.saveLastHifzSession(session);
  }

  void loadLastSession() {
    final session = _storage.getLastHifzSession();
    if (session != null) {
      final chId = session['chapterId'] as int?;
      final ch = chId == null ? null : chapters.firstWhereOrNull((c) => c.id == chId);
      if (ch != null) {
        selectedChapter.value = ch;
        startAyah.value = session['startAyah'] as int? ?? 1;
        endAyah.value = session['endAyah'] as int? ?? ch.versesCount;
      }
      verseRepetitions.value = session['verseRepetitions'] as int? ?? 3;
      rangeRepetitions.value = session['rangeRepetitions'] as int? ?? 2;
      delaySeconds.value = session['delaySeconds'] as int? ?? 0;
      selectedReciterId.value = session['reciterId'] as int? ?? 7;
      selectedStyle.value = session['style'] as String? ?? 'murattal';
      showTranslation.value = session['showTranslation'] as bool? ?? false;
      selectedTranslationIndex.value = session['translationIndex'] as int? ?? 0;
    }
  }

  void onSurahChanged(Chapter? val) {
    if (val != null) {
      selectedChapter.value = val;
      startAyah.value = 1;
      endAyah.value = val.versesCount;
    }
  }

  void incrementStartAyah() {
    if (startAyah.value < endAyah.value) {
      startAyah.value++;
    }
  }

  void decrementStartAyah() {
    if (startAyah.value > 1) {
      startAyah.value--;
    }
  }

  void incrementEndAyah() {
    final chapter = selectedChapter.value;
    if (chapter != null && endAyah.value < chapter.versesCount) {
      endAyah.value++;
    }
  }

  void decrementEndAyah() {
    if (endAyah.value > startAyah.value) {
      endAyah.value--;
    }
  }

  /// Manual entry for the start ayah, with validation. Returns null on
  /// success, or a translation key describing why the value was rejected.
  String? setStartAyah(int value) {
    final chapter = selectedChapter.value;
    if (chapter == null) return 'invalid_range_desc';
    if (value < 1 || value > chapter.versesCount) return 'hifz_ayah_out_of_range';
    if (value > endAyah.value) return 'hifz_start_after_end';
    startAyah.value = value;
    return null;
  }

  /// Manual entry for the end ayah, with validation. Returns null on
  /// success, or a translation key describing why the value was rejected.
  String? setEndAyah(int value) {
    final chapter = selectedChapter.value;
    if (chapter == null) return 'invalid_range_desc';
    if (value < 1 || value > chapter.versesCount) return 'hifz_ayah_out_of_range';
    if (value < startAyah.value) return 'hifz_end_before_start';
    endAyah.value = value;
    return null;
  }

  void toggleVerseReveal(int id) {
    if (revealedVerseIds.contains(id)) {
      revealedVerseIds.remove(id);
    } else {
      revealedVerseIds.add(id);
    }
  }

  void _onActiveVerseChanged(String? activeKey) {
    if (activeKey == null) {
      // The engine clears the key whenever it stops (loop finished, or a new
      // loop being set up). While the workspace is open keep the last verse
      // on screen instead of falling back to the "initializing" placeholder;
      // completion itself is signalled by `hifzLoopFinished`.
      if (!isHifzActive.value || hifzVerses.isEmpty) {
        currentRecitingVerse.value = null;
      }
      return;
    }
    if (hifzVerses.isEmpty) return;
    sessionCompleted.value = false;

    try {
      final verse = hifzVerses.firstWhere((v) => v.verseKey == activeKey);
      currentRecitingVerse.value = verse;
    } catch (_) {
      // Verse is not in our active Hifz list
    }
  }

  bool isSurahDownloaded() {
    final chapter = selectedChapter.value;
    if (chapter == null) return false;
    final reciterId = _storage.getEffectiveReciterId();
    return _storage.isChapterDownloaded(reciterId, chapter.id, chapter.versesCount);
  }

  Future<void> downloadSurah() async {
    final chapter = selectedChapter.value;
    if (chapter == null) return;
    
    final reciterId = _storage.getEffectiveReciterId();
    final chapterName = SurahDisplay.name(chapter.id, fallback: chapter.nameSimple);

    if (_storage.isChapterDownloaded(reciterId, chapter.id, chapter.versesCount)) {
      Get.dialog(
        AlertDialog(
          backgroundColor: Get.isDarkMode ? AppColors.cardDark : Colors.white,
          title: Text('delete_downloaded_surah'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text('delete_downloaded_surah_confirm'.trParams({'surah': chapterName})),
          actions: [
            TextButton(
              child: Text('cancel'.tr),
              onPressed: () => Get.back(),
            ),
            TextButton(
              child: Text('delete'.tr, style: const TextStyle(color: Colors.red)),
              onPressed: () async {
                await _downloadService.deleteChapter(reciterId, chapter.id);
                Get.back();
                update();
              },
            ),
          ],
        )
      );
      return;
    }
    
    isDownloadingSurah.value = true;
    downloadProgress.value = 0.0;
    
    try {
      final urls = await _api.fetchChapterAudio(reciterId, chapter.id);
      if (urls.isEmpty) {
        throw Exception('audio_links_offline'.tr);
      }
      
      final taskKey = '${reciterId}_${chapter.id}';
      final sub = _downloadService.progressStream.listen((progressMap) {
        if (progressMap.containsKey(taskKey)) {
          downloadProgress.value = progressMap[taskKey] ?? 0.0;
        }
      });
      
      await _downloadService.downloadChapter(reciterId, chapter.id, urls);
      sub.cancel();
      update();
      Get.snackbar('download_surah'.tr, 'download_surah_success'.trParams({'surah': chapterName}), snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('download_failed'.tr, '${e.toString()}', snackPosition: SnackPosition.BOTTOM);
    } finally {
      isDownloadingSurah.value = false;
      downloadProgress.value = 0.0;
    }
  }

  Future<void> startHifz() async {
    final chapter = selectedChapter.value;
    if (chapter == null) return;

    final int start = startAyah.value;
    final int end = endAyah.value;

    if (start < 1 || end > chapter.versesCount || start > end) {
      Get.snackbar('invalid_range'.tr, 'invalid_range_desc'.tr, snackPosition: SnackPosition.BOTTOM);
      return;
    }

    _rememberGlobalTajweed();
    isLoading.value = true;
    isHifzActive.value = true;
    sessionCompleted.value = false;
    revealedVerseIds.clear();
    _sessionStartedAt = DateTime.now();

    try {
      saveSessionState();
      WakelockPlus.enable();

      // Load translations if enabled
      if (showTranslation.value) {
        await TafsirCtrl.instance.handleRadioValueChanged(selectedTranslationIndex.value);
        await TafsirCtrl.instance.fetchTranslate();
      }

      // Map local ayahs from quran_library
      final localAyahs = QuranCtrl.instance.surahs[chapter.id - 1].ayahs;
      final mappedVerses = localAyahs.map((a) {
        final verseKey = '${chapter.id}:${a.ayahNumber}';
        final translation = showTranslation.value
            ? cleanTafsirText(TafsirCtrl.instance.getTranslationText(chapter.id, a.ayahNumber))
            : '';
        return Verse(
          id: a.ayahUQNumber,
          verseNumber: a.ayahNumber,
          verseKey: verseKey,
          textUthmani: a.text,
          translationText: translation,
          juzNumber: a.juz,
          pageNumber: a.page,
        );
      }).toList();

      final filtered = mappedVerses.where((v) => v.verseNumber >= start && v.verseNumber <= end).toList();
      hifzVerses.assignAll(filtered);

      // Pre-set the reciting verse to the first verse so it displays immediately in the Workspace UI
      if (hifzVerses.isNotEmpty) {
        currentRecitingVerse.value = hifzVerses.first;
      }

      // Set loader to false immediately so the Workspace UI and the first verse text render on screen
      isLoading.value = false;

      final reciterId = _storage.getEffectiveReciterId();
      final isDownloaded = _storage.isChapterDownloaded(reciterId, chapter.id, chapter.versesCount);

      List<String> audioPathsOrUrls = [];
      if (isDownloaded) {
        audioPathsOrUrls = _storage.getChapterAudioPathsOrUrls(reciterId, chapter.id, chapter.versesCount);
      } 
      if (audioPathsOrUrls.isEmpty) {
        audioPathsOrUrls = await _api.fetchChapterAudio(reciterId, chapter.id);
      }

      if (audioPathsOrUrls.isEmpty) {
        throw Exception('audio_links_offline'.tr);
      }

      final config = HifzLoopConfig(
        startVerseKey: '${chapter.id}:$start',
        endVerseKey: '${chapter.id}:$end',
        verseRepetitions: verseRepetitions.value,
        rangeRepetitions: rangeRepetitions.value,
        delaySeconds: delaySeconds.value,
      );

      _lastAudioPaths = audioPathsOrUrls;
      _lastLoopConfig = config;

      // Start play loop (will play when audio finishes buffering)
      await _playLoop(chapter, audioPathsOrUrls, config);
      _startLiveActivityTimer(chapter, start, end);
      _startWardStopwatch();
    } catch (e) {
      WakelockPlus.disable();
      _restoreGlobalTajweed();
      Get.snackbar('hifz_workspace_error'.tr, 'hifz_workspace_error_desc'.trParams({'error': '${e.toString()}'}), snackPosition: SnackPosition.BOTTOM);
      isHifzActive.value = false;
      isLoading.value = false;
    }
  }

  Future<void> _playLoop(Chapter chapter, List<String> paths, HifzLoopConfig config) {
    return _audio.playHifz(chapter, paths, config);
  }

  /// Replays the same range after every repetition finished.
  Future<void> replayCompletedLoop() async {
    final chapter = selectedChapter.value;
    final config = _lastLoopConfig;
    if (chapter == null || config == null || _lastAudioPaths.isEmpty) return;
    sessionCompleted.value = false;
    try {
      await _playLoop(chapter, _lastAudioPaths, config);
    } catch (e) {
      Get.snackbar('hifz_workspace_error'.tr, 'hifz_workspace_error_desc'.trParams({'error': '$e'}), snackPosition: SnackPosition.BOTTOM);
    }
  }

  // ---------------------------------------------------------------------------
  // Tajweed
  // ---------------------------------------------------------------------------

  /// Tajweed colors only exist in quran_library's default QPC/QCF4 font.
  bool get isTajweedSupported {
    try {
      return QuranCtrl.instance.isQpcV4Enabled;
    } catch (_) {
      return false;
    }
  }

  Future<void> toggleTajweed(bool value) async {
    showTajweed.value = value;
    await _storage.setHifzShowTajweed(value);
  }

  void _rememberGlobalTajweed() {
    if (_savedGlobalTajweed != null) return;
    try {
      _savedGlobalTajweed = QuranCtrl.instance.state.isTajweedEnabled.value;
    } catch (_) {}
  }

  void _restoreGlobalTajweed() {
    final saved = _savedGlobalTajweed;
    if (saved == null) return;
    _savedGlobalTajweed = null;
    try {
      QuranCtrl.instance.state.isTajweedEnabled.value = saved;
      GetStorage().write(_libTajweedStorageKey, saved);
    } catch (_) {}
  }

  /// Pushes automatic, no-button-needed live progress (current range +
  /// elapsed time) while a Hifz session is active. Purely additive — it does
  /// not change what counts as a "completed" session (see saveSessionToHistory,
  /// only reachable via the explicit finish+rate flow).
  void _startLiveActivityTimer(Chapter chapter, int start, int end) {
    _liveActivityTimer?.cancel();
    if (!Get.isRegistered<TeacherSyncService>()) return;
    final sync = Get.find<TeacherSyncService>();
    if (!sync.isStudent) return;

    final label = '${chapter.nameSimple} ($start-$end)';
    void push() {
      final elapsed = _sessionStartedAt != null ? DateTime.now().difference(_sessionStartedAt!).inSeconds : 0;
      unawaited(sync.setLiveActivity(
        feature: 'hifz',
        label: label,
        elapsedSeconds: elapsed,
        chapterId: chapter.id,
        startAyah: start,
        endAyah: end,
      ));
    }

    push(); // Immediate first push so the teacher doesn't wait for the first tick.
    _liveActivityTimer = Timer.periodic(const Duration(seconds: 15), (_) => push());
  }

  /// Counts Hifz practice time toward the daily ward goal, same as Mushaf
  /// reading time — the goal now reflects activity across every feature.
  void _startWardStopwatch() {
    _wardStopwatchTimer?.cancel();
    _wardTickCount = 0;
    _wardStopwatchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (Get.isRegistered<ReminderService>()) {
        unawaited(Get.find<ReminderService>().logWardProgress(1));
      }
      unawaited(_storage.logHifzPracticeSeconds(1));
      _wardTickCount++;
      if (_wardTickCount % 30 == 0) _syncTodayIfStudent();
    });
  }

  void _syncTodayIfStudent() {
    if (!Get.isRegistered<TeacherSyncService>()) return;
    final sync = Get.find<TeacherSyncService>();
    if (sync.isStudent) unawaited(sync.syncTodayActivity());
  }

  void stopHifz() {
    final wasActive = isHifzActive.value;
    WakelockPlus.disable();
    isHifzActive.value = false;
    sessionCompleted.value = false;
    currentRecitingVerse.value = null;
    hifzVerses.clear();
    _lastAudioPaths = const [];
    _lastLoopConfig = null;
    _audio.stop();
    _restoreGlobalTajweed();
    if (wasActive) _syncTodayIfStudent();

    _liveActivityTimer?.cancel();
    _liveActivityTimer = null;
    _wardStopwatchTimer?.cancel();
    _wardStopwatchTimer = null;
    if (Get.isRegistered<TeacherSyncService>()) {
      final sync = Get.find<TeacherSyncService>();
      if (sync.isStudent) unawaited(sync.clearLiveActivity());
    }
  }

  Future<void> finishAndSaveSession(int rating, String notes, {String? shareToTeacherUid}) async {
    await saveSessionToHistory(rating, notes, shareToTeacherUid: shareToTeacherUid);
    stopHifz();
  }

  Future<void> saveSessionToHistory(int rating, String notes, {String? shareToTeacherUid}) async {
    final chapter = selectedChapter.value;
    if (chapter == null) return;

    // Capture how far the student actually got, not just the planned range —
    // must be read before stopHifz() resets the audio engine's Hifz state.
    final reachedAyah = _audio.hifzReachedAyahNumber;
    final reachedEndAyah = (reachedAyah ?? endAyah.value).clamp(startAyah.value, endAyah.value);
    final durationSeconds = _sessionStartedAt != null ? DateTime.now().difference(_sessionStartedAt!).inSeconds : 0;

    final newEntry = {
      'id': '${chapter.id}_${startAyah.value}_${DateTime.now().millisecondsSinceEpoch}',
      'chapterId': chapter.id,
      // Kept for backward compatibility only — screens resolve the display
      // name from chapterId in the viewer's language (see SurahDisplay).
      'chapterName': chapter.nameArabic,
      'startAyah': startAyah.value,
      'endAyah': endAyah.value,
      'reachedEndAyah': reachedEndAyah,
      'durationSeconds': durationSeconds,
      'verseRepetitions': verseRepetitions.value,
      'rangeRepetitions': rangeRepetitions.value,
      'date': DateTime.now().toIso8601String(),
      'rating': rating,
      'notes': notes,
      'reciterId': selectedReciterId.value,
      'reciterName': getReciterName(selectedReciterId.value),
    };

    final history = List<Map<String, dynamic>>.from(hifzHistoryList);
    history.insert(0, newEntry); // Add to the top
    hifzHistoryList.assignAll(history);
    await _storage.saveHifzHistory(history);

    if (Get.isRegistered<TeacherSyncService>()) {
      final sync = Get.find<TeacherSyncService>();
      if (sync.isStudent) {
        unawaited(sync.syncHifzSession(newEntry, shareToTeacherUid: shareToTeacherUid));
      }
    }
  }

  Future<void> deleteHistoryItem(int index) async {
    final history = List<Map<String, dynamic>>.from(hifzHistoryList);
    if (index < 0 || index >= history.length) return;
    history.removeAt(index);
    hifzHistoryList.assignAll(history);
    await _storage.saveHifzHistory(history);
  }

  Future<void> updateReciter(int id) async {
    selectedReciterId.value = id;
    await _storage.setSelectedReciterId(id);
    
    final currentStyle = _storage.getSelectedStyle();
    if (id == 10) {
      await _storage.setSelectedStyle('teacher');
      selectedStyle.value = 'teacher';
    } else if (id != 6 && currentStyle == 'teacher') {
      await _storage.setSelectedStyle('murattal');
      selectedStyle.value = 'murattal';
    } else if (id != 6 && id != 2 && id != 9 && currentStyle == 'mujawwad') {
      await _storage.setSelectedStyle('murattal');
      selectedStyle.value = 'murattal';
    } else {
      selectedStyle.value = currentStyle;
    }
    update();
  }

  Future<void> updateStyle(String style) async {
    selectedStyle.value = style;
    await _storage.setSelectedStyle(style);
    update();
  }

  String getReciterName(int id) {
    final translationKey = 'reciter_$id';
    final translated = translationKey.tr;
    if (translated == translationKey) {
      return 'reciter_unknown'.tr;
    }
    return translated;
  }

  AudioService get audioService => _audio;

  String cleanTafsirText(String text) {
    if (text.isEmpty) return '';
    var cleaned = text.replaceAll(RegExp(r'<[^>]*>'), '');
    cleaned = cleaned
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned;
  }

  String getStartAyahText() {
    final chapter = selectedChapter.value;
    if (chapter == null) return '';
    final surahIndex = chapter.id - 1;
    if (surahIndex < 0 || surahIndex >= QuranCtrl.instance.surahs.length) return '';
    final ayahs = QuranCtrl.instance.surahs[surahIndex].ayahs;
    final startIdx = startAyah.value - 1;
    if (startIdx >= 0 && startIdx < ayahs.length) {
      return ayahs[startIdx].text;
    }
    return '';
  }

  String getEndAyahText() {
    final chapter = selectedChapter.value;
    if (chapter == null) return '';
    final surahIndex = chapter.id - 1;
    if (surahIndex < 0 || surahIndex >= QuranCtrl.instance.surahs.length) return '';
    final ayahs = QuranCtrl.instance.surahs[surahIndex].ayahs;
    final endIdx = endAyah.value - 1;
    if (endIdx >= 0 && endIdx < ayahs.length) {
      return ayahs[endIdx].text;
    }
    return '';
  }

  @override
  void onClose() {
    // Leaving the route (e.g. system back gesture) must end the session too:
    // otherwise the Hifz loop keeps playing with no screen to control it.
    if (isHifzActive.value) {
      stopHifz();
    }
    _restoreGlobalTajweed();
    WakelockPlus.disable();
    _activeVerseSub?.cancel();
    _loopFinishedSub?.cancel();
    _liveActivityTimer?.cancel();
    _wardStopwatchTimer?.cancel();
    super.onClose();
  }
}
