import 'dart:async';
import 'package:get/get.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:quran_library/quran_library.dart' hide AudioService;
import '../../core/audio_service.dart';
import '../../core/api_service.dart';
import '../../core/storage_service.dart';
import '../../core/reminder_service.dart';
import '../../core/teacher_sync_service.dart';
import '../../models.dart';

class MushafViewController extends GetxController {
  final AudioService audio = Get.find<AudioService>();
  final ApiService _api = Get.find<ApiService>();
  final StorageService storage = Get.find<StorageService>();

  late Chapter chapter;
  
  final RxBool isLoading = false.obs;
  final RxnInt activeAyahNumber = RxnInt();
  final RxBool isRepeatAyah = false.obs;
  final RxDouble ayahProgress = 0.0.obs;

  List<String> audioPathsOrUrls = [];
  Timer? _stopwatchTimer;
  StreamSubscription? _activeVerseSub;
  StreamSubscription? _selectedAyahSub;
  Future<void>? _loadAudioFuture;

  @override
  void onInit() {
    super.onInit();
    chapter = Get.arguments as Chapter;
    _loadAudioFuture = _loadAudio();
    _startStopwatch();

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

      _stopwatchTickCount++;
      if (_stopwatchTickCount % 30 == 0) {
        _maybeSyncWardToday();
      }
    });
  }

  void _maybeSyncWardToday() {
    if (!Get.isRegistered<TeacherSyncService>()) return;
    final sync = Get.find<TeacherSyncService>();
    if (!sync.isStudent) return;
    unawaited(sync.syncTodayActivity());
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
      await audio.playSurah(chapter, audioPathsOrUrls);
    } catch (e) {
      Get.snackbar('audio_play_failed'.tr, '$e', snackPosition: SnackPosition.BOTTOM);
    }
  }

  void stopPlaySurah() {
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
        await audio.playSurah(chapter, audioPathsOrUrls, initialIndex: ayahNumber - 1);
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
    // Disable screen wakelock
    WakelockPlus.disable();
    _stopwatchTimer?.cancel();
    _activeVerseSub?.cancel();
    _selectedAyahSub?.cancel();
    QuranCtrl.instance.clearExternalHighlights();

    // Reschedule daily reminders to reflect updated progress
    try {
      final goal = storage.getWardGoal();
      Get.find<ReminderService>().scheduleDailyReminder(goal.reminderHour, goal.reminderMinute);
      _maybeSyncWardToday();
    } catch (_) {}

    super.onClose();
  }
}
