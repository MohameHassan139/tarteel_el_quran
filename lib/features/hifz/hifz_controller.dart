import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quran_library/quran_library.dart' hide AudioService;
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/audio_service.dart';
import '../../core/api_service.dart';
import '../../core/storage_service.dart';
import '../../core/download_service.dart';
import '../../core/app_colors.dart';
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

  // Hifz history progress list
  final RxList<Map<String, dynamic>> hifzHistoryList = <Map<String, dynamic>>[].obs;

  StreamSubscription? _activeVerseSub;

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
    initQuranData();

    // Listen to changes in the active reciting verse
    _activeVerseSub = _audio.activeVerseKey.listen((activeKey) {
      _onActiveVerseChanged(activeKey);
    });
  }

  Future<void> initQuranData() async {
    try {
      await QuranCtrl.instance.ensureCoreDataLoaded();
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
      final chId = session['chapterId'] as int;
      final ch = chapters.firstWhereOrNull((c) => c.id == chId);
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

  void toggleVerseReveal(int id) {
    if (revealedVerseIds.contains(id)) {
      revealedVerseIds.remove(id);
    } else {
      revealedVerseIds.add(id);
    }
  }

  void _onActiveVerseChanged(String? activeKey) {
    if (activeKey == null || hifzVerses.isEmpty) {
      currentRecitingVerse.value = null;
      return;
    }

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
    final isAr = Get.locale?.languageCode == 'ar';
    final chapterName = isAr ? chapter.nameArabic : chapter.nameSimple;

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

    isLoading.value = true;
    isHifzActive.value = true;
    revealedVerseIds.clear();

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

      // Start play loop (will play when audio finishes buffering)
      await _audio.playHifz(chapter, audioPathsOrUrls, config);
    } catch (e) {
      WakelockPlus.disable();
      Get.snackbar('hifz_workspace_error'.tr, 'hifz_workspace_error_desc'.trParams({'error': '${e.toString()}'}), snackPosition: SnackPosition.BOTTOM);
      isHifzActive.value = false;
      isLoading.value = false;
    }
  }

  void stopHifz() {
    _audio.stop();
    WakelockPlus.disable();
    isHifzActive.value = false;
    currentRecitingVerse.value = null;
    hifzVerses.clear();
  }

  Future<void> finishAndSaveSession(int rating, String notes) async {
    await saveSessionToHistory(rating, notes);
    stopHifz();
  }

  Future<void> saveSessionToHistory(int rating, String notes) async {
    final chapter = selectedChapter.value;
    if (chapter == null) return;
    
    final newEntry = {
      'chapterId': chapter.id,
      'chapterName': chapter.nameArabic,
      'startAyah': startAyah.value,
      'endAyah': endAyah.value,
      'date': DateTime.now().toIso8601String(),
      'rating': rating,
      'notes': notes,
      'reciterName': getReciterName(selectedReciterId.value),
    };
    
    final history = List<Map<String, dynamic>>.from(hifzHistoryList);
    history.insert(0, newEntry); // Add to the top
    hifzHistoryList.assignAll(history);
    await _storage.saveHifzHistory(history);
  }

  Future<void> deleteHistoryItem(int index) async {
    final history = List<Map<String, dynamic>>.from(hifzHistoryList);
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
    WakelockPlus.disable();
    _activeVerseSub?.cancel();
    super.onClose();
  }
}
