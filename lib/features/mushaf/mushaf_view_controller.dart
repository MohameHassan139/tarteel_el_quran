import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:quran_library/quran_library.dart' hide AudioService;
import '../../core/audio_service.dart';
import '../../core/api_service.dart';
import '../../core/storage_service.dart';
import '../../core/reminder_service.dart';
import '../../core/teacher_sync_service.dart';
import '../../models.dart';

class MushafViewController extends GetxController with WidgetsBindingObserver {
  final AudioService audio = Get.find<AudioService>();
  final ApiService _api = Get.find<ApiService>();
  final StorageService storage = Get.find<StorageService>();

  late final Rx<Chapter> rxChapter;
  Chapter get chapter => rxChapter.value;
  set chapter(Chapter c) => rxChapter.value = c;
  
  final RxBool isLoading = false.obs;
  final RxnInt activeAyahNumber = RxnInt();
  final RxBool isRepeatAyah = false.obs;
  final RxDouble ayahProgress = 0.0.obs;

  // Controls visibility & 3-second auto-hide
  final RxBool isAudioBarVisible = false.obs;
  Timer? _audioBarAutoHideTimer;
  DateTime? _lastScreenPressTime;

  // Student reading tracking
  int _readingElapsedSeconds = 0;
  int? currentPageNumber;

  List<String> audioPathsOrUrls = [];
  Timer? _stopwatchTimer;
  StreamSubscription? _activeVerseSub;
  StreamSubscription? _selectedAyahSub;
  Future<void>? _loadAudioFuture;

  @override
  void onInit() {
    super.onInit();
    final initialChapter = Get.arguments as Chapter;
    rxChapter = initialChapter.obs;
    WidgetsBinding.instance.addObserver(this);

    if (audio.isPlaying.value && audio.activeChapter.value?.id == initialChapter.id && storage.getMushafPlayNext()) {
      audio.onChapterFinished = playNextSurah;
    }

    // Give Holy Mushaf maximum height possible by hiding controls initially
    isAudioBarVisible.value = false;
    if (QuranCtrl.instance.isShowControl.value) {
      QuranCtrl.instance.isShowControl.value = false;
      QuranCtrl.instance.update(['isShowControl']);
    }

    _loadAudioFuture = _loadAudio();
    _startStopwatch();

    // Immediately start storing progress in Firebase for students when opening any page
    currentPageNumber = QuranCtrl.instance.getPageNumberByAyahAndSurahNumber(1, chapter.id);
    _pushMushafActivityToFirebase();

    // Keep screen on if setting is enabled
    if (storage.getKeepScreenOn()) {
      WakelockPlus.enable();
    }
    
    // Listen to active verse changes
    _activeVerseSub = audio.activeVerseKey.listen((key) {
      _onActiveVerseChanged(key);
    });

    // quran_library toggles ayah selection on every long-press (which we use
    // solely to open the tafsir sheet, see MushafViewScreen._showTafseerSheet).
    // Clear that selection right away so it doesn't leave a lingering highlight
    // — long-press must only show tafsir and must NEVER move audio playback.
    _selectedAyahSub = QuranCtrl.instance.selectedAyahsByUnequeNumber.listen((selectedUqs) {
      if (selectedUqs.isNotEmpty) {
        QuranCtrl.instance.clearSelection();
      }
    });
  }

  int _stopwatchTickCount = 0;

  void _startStopwatch() {
    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      Get.find<ReminderService>().logWardProgress(1);
      _readingElapsedSeconds++;
      _stopwatchTickCount++;

      // Sync to Firebase periodically (every 15 seconds) while reading without needing audio
      if (_stopwatchTickCount % 15 == 0) {
        _pushMushafActivityToFirebase();
      }
    });
  }

  /// Called whenever the reader turns or navigates to another page
  void onPageChanged(int pageNumber) {
    if (currentPageNumber == pageNumber) return;
    currentPageNumber = pageNumber;
    _pushMushafActivityToFirebase();
  }

  /// Pushes student live activity and daily reading progress to Firebase immediately
  void _pushMushafActivityToFirebase() {
    if (!Get.isRegistered<TeacherSyncService>()) return;
    final sync = Get.find<TeacherSyncService>();
    if (!sync.isStudent) return;

    unawaited(sync.recordMushafPageOpened(
      chapterId: chapter.id,
      chapterName: chapter.nameSimple,
      pageNumber: currentPageNumber ?? 1,
      elapsedSeconds: _readingElapsedSeconds,
    ));
  }

  // ── Screen tap & 3-second auto-hide controls ───────────────────────────

  void handleScreenPress() {
    final now = DateTime.now();
    if (_lastScreenPressTime != null &&
        now.difference(_lastScreenPressTime!) < const Duration(milliseconds: 250)) {
      return;
    }
    _lastScreenPressTime = now;

    if (isAudioBarVisible.value) {
      hideControls();
    } else {
      showControls();
    }
  }

  void showControls() {
    isAudioBarVisible.value = true;
    if (!QuranCtrl.instance.isShowControl.value) {
      QuranCtrl.instance.isShowControl.value = true;
      QuranCtrl.instance.update(['isShowControl']);
    }
    resetAutoHideTimer();
  }

  void hideControls() {
    _audioBarAutoHideTimer?.cancel();
    isAudioBarVisible.value = false;
    if (QuranCtrl.instance.isShowControl.value) {
      QuranCtrl.instance.isShowControl.value = false;
      QuranCtrl.instance.update(['isShowControl']);
    }
  }

  void resetAutoHideTimer() {
    _audioBarAutoHideTimer?.cancel();
    _audioBarAutoHideTimer = Timer(const Duration(seconds: 3), () {
      hideControls();
    });
  }

  void cancelAutoHideTimer() {
    _audioBarAutoHideTimer?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!Get.isRegistered<TeacherSyncService>()) return;
    final sync = Get.find<TeacherSyncService>();
    if (!sync.isStudent) return;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      unawaited(sync.clearLiveActivity());
      unawaited(sync.syncTodayActivity());
    } else if (state == AppLifecycleState.resumed) {
      _pushMushafActivityToFirebase();
    }
  }

  void _onActiveVerseChanged(String? key) {
    if (key == null) {
      if (activeAyahNumber.value != null) {
        activeAyahNumber.value = null;
        ayahProgress.value = 0.0;
        QuranCtrl.instance.clearExternalHighlights();
      }
      return;
    }

    final parts = key.split(':');
    if (parts.length == 2 && parts[0] == chapter.id.toString()) {
      final ayahNum = int.tryParse(parts[1]);
      if (ayahNum != null && ayahNum != activeAyahNumber.value) {
        activeAyahNumber.value = ayahNum;
        ayahProgress.value = chapter.versesCount > 0
            ? (ayahNum / chapter.versesCount).clamp(0.0, 1.0)
            : 0.0;

        // Highlight
        final uq = QuranCtrl.instance.getAyahUQBySurahAndAyah(chapter.id, ayahNum);
        if (uq != null) {
          QuranCtrl.instance.setExternalHighlights([uq]);
        }

        // Auto page turn
        try {
          final ayahPage = QuranCtrl.instance.getPageNumberByAyahAndSurahNumber(
            ayahNum,
            chapter.id,
          );
          final currentPage = QuranCtrl.instance.state.currentPageNumber.value;
          if (ayahPage != currentPage && ayahPage > 0) {
            QuranCtrl.instance.jumpToPage(ayahPage - 1);
          }
        } catch (_) {}
      }
    }
  }

  Future<void> _loadAudio() async {
    isLoading.value = true;
    try {
      final reciterId = storage.getEffectiveReciterId();
      final isDownloaded = storage.isChapterDownloaded(reciterId, chapter.id, chapter.versesCount);
      
      if (isDownloaded) {
        audioPathsOrUrls = storage.getChapterAudioPathsOrUrls(reciterId, chapter.id, chapter.versesCount);
        if (audioPathsOrUrls.isNotEmpty) return;
      }
      
      audioPathsOrUrls = await _api.fetchChapterAudio(reciterId, chapter.id);
    } catch (_) {
      // Non-critical
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> startPlaySurah() async {
    if (audioPathsOrUrls.isEmpty && _loadAudioFuture != null) {
      isLoading.value = true;
      await _loadAudioFuture;
    }

    if (audioPathsOrUrls.isEmpty) {
      Get.snackbar('audio'.tr, 'audio_links_offline'.tr, snackPosition: SnackPosition.BOTTOM);
      return;
    }
    try {
      audio.isAudioHubPlayback.value = false;
      if (storage.getMushafPlayNext()) {
        audio.onChapterFinished = playNextSurah;
      } else {
        audio.onChapterFinished = null;
      }
      await audio.playSurah(chapter, audioPathsOrUrls, clearCompletionCallback: false);
    } catch (e) {
      Get.snackbar('audio_play_failed'.tr, '$e', snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> playNextSurah() async {
    if (!storage.getMushafPlayNext()) return;

    final nextId = (chapter.id % 114) + 1;

    Chapter? nextChapter;
    final cached = storage.getCachedChapters();
    if (cached != null && cached.isNotEmpty) {
      nextChapter = cached.firstWhereOrNull((c) => c.id == nextId);
    }
    if (nextChapter == null && QuranCtrl.instance.surahsList.isNotEmpty) {
      final s = QuranCtrl.instance.surahsList.firstWhereOrNull((s) => s.number == nextId);
      if (s != null) {
        nextChapter = Chapter(
          id: s.number,
          nameSimple: s.englishName,
          nameComplex: s.englishName,
          nameArabic: s.name,
          versesCount: s.ayahsNumber,
          revelationPlace: s.revelationType,
          revelationOrder: 0,
          translatedName: s.englishNameTranslation,
        );
      }
    }
    if (nextChapter == null) return;

    rxChapter.value = nextChapter;
    activeAyahNumber.value = null;
    ayahProgress.value = 0.0;
    isRepeatAyah.value = false;
    audio.setRepeatCurrentAyah(false);
    QuranCtrl.instance.clearExternalHighlights();

    final sp = QuranCtrl.instance.getPageNumberByAyahAndSurahNumber(1, nextChapter.id);
    currentPageNumber = sp;
    try {
      QuranCtrl.instance.jumpToPage(sp - 1);
    } catch (_) {}
    _pushMushafActivityToFirebase();

    isLoading.value = true;
    try {
      final reciterId = storage.getEffectiveReciterId();
      final isDownloaded = storage.isChapterDownloaded(reciterId, nextChapter.id, nextChapter.versesCount);
      if (isDownloaded) {
        audioPathsOrUrls = storage.getChapterAudioPathsOrUrls(reciterId, nextChapter.id, nextChapter.versesCount);
      } else {
        audioPathsOrUrls = [];
      }
      if (audioPathsOrUrls.isEmpty) {
        audioPathsOrUrls = await _api.fetchChapterAudio(reciterId, nextChapter.id);
      }
    } catch (_) {
      audioPathsOrUrls = [];
    } finally {
      isLoading.value = false;
    }

    if (audioPathsOrUrls.isEmpty) {
      Get.snackbar('audio'.tr, 'audio_links_offline'.tr, snackPosition: SnackPosition.BOTTOM);
      return;
    }

    try {
      audio.isAudioHubPlayback.value = false;
      audio.onChapterFinished = playNextSurah;
      await audio.playSurah(
        nextChapter,
        audioPathsOrUrls,
        clearCompletionCallback: false,
        keepSessionAlive: true,
      );
    } catch (e) {
      Get.snackbar('audio_play_failed'.tr, '$e', snackPosition: SnackPosition.BOTTOM);
    }
  }

  void stopPlaySurah() {
    audio.onChapterFinished = null;
    audio.stop();
    isRepeatAyah.value = false;
    ayahProgress.value = 0.0;
  }

  /// Jump to and start playing from a specific ayah number in this chapter.
  Future<void> startFromAyah(int ayahNumber) async {
    if (ayahNumber < 1 || ayahNumber > chapter.versesCount) return;

    if (audioPathsOrUrls.isEmpty && _loadAudioFuture != null) {
      isLoading.value = true;
      await _loadAudioFuture;
    }

    if (audioPathsOrUrls.isEmpty) {
      Get.snackbar('audio'.tr, 'audio_links_offline'.tr, snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final isSameSurahLoaded = audio.activeChapter.value?.id == chapter.id;

    try {
      if (isSameSurahLoaded) {
        await audio.seekToVerse('${chapter.id}:$ayahNumber');
        if (!audio.isPlaying.value) {
          await audio.resume();
        }
      } else {
        audio.isAudioHubPlayback.value = false;
        if (storage.getMushafPlayNext()) {
          audio.onChapterFinished = playNextSurah;
        } else {
          audio.onChapterFinished = null;
        }
        await audio.playSurah(chapter, audioPathsOrUrls, initialIndex: ayahNumber - 1, clearCompletionCallback: false);
      }
    } catch (e) {
      Get.snackbar('audio_play_failed'.tr, '$e', snackPosition: SnackPosition.BOTTOM);
    }
  }

  void previousAyah() {
    if (activeAyahNumber.value != null && activeAyahNumber.value! > 1) {
      final targetAyah = activeAyahNumber.value! - 1;
      if (audioPathsOrUrls.isNotEmpty) {
        final targetKey = '${chapter.id}:$targetAyah';
        audio.seekToVerse(targetKey);
      }
    }
  }

  void toggleRepeat() {
    isRepeatAyah.value = !isRepeatAyah.value;
    audio.setRepeatCurrentAyah(isRepeatAyah.value);
  }

  String getReciterName() {
    final id = storage.getSelectedReciterId();
    final translationKey = 'reciter_$id';
    final translated = translationKey.tr;
    if (translated == translationKey) {
      return 'reciter_unknown'.tr;
    }
    return translated;
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _stopwatchTimer?.cancel();
    _audioBarAutoHideTimer?.cancel();
    _activeVerseSub?.cancel();
    _selectedAyahSub?.cancel();
    QuranCtrl.instance.clearExternalHighlights();

    // Hand off continuous playback callback to AudioService if audio is still playing
    if (audio.isPlaying.value && !audio.isAudioHubPlayback.value && storage.getMushafPlayNext()) {
      audio.onChapterFinished = audio.playNextMushafSurah;
    }

    // Clear live activity in Firebase and sync final activity
    if (Get.isRegistered<TeacherSyncService>()) {
      final sync = Get.find<TeacherSyncService>();
      if (sync.isStudent) {
        unawaited(sync.clearLiveActivity());
        unawaited(sync.syncTodayActivity());
      }
    }

    // Reschedule daily reminders to reflect updated progress
    try {
      final goal = storage.getWardGoal();
      Get.find<ReminderService>().scheduleDailyReminder(goal.reminderHour, goal.reminderMinute);
    } catch (_) {}

    super.onClose();
  }
}
