import 'dart:async';
import 'package:get/get.dart';
import 'package:quran_library/quran_library.dart' hide AudioService;
import '../../core/audio_service.dart';
import '../../core/api_service.dart';
import '../../core/storage_service.dart';
import '../../models.dart';

class MushafViewController extends GetxController {
  final AudioService audio = Get.find<AudioService>();
  final ApiService _api = Get.find<ApiService>();
  final StorageService storage = Get.find<StorageService>();

  late Chapter chapter;
  
  final RxBool isLoading = true.obs;
  final RxnInt activeAyahNumber = RxnInt();
  final RxBool isRepeatAyah = false.obs;
  final RxDouble ayahProgress = 0.0.obs;

  List<VerseTiming> timings = [];
  String? audioUrl;
  Timer? _stopwatchTimer;
  StreamSubscription? _activeVerseSub;
  StreamSubscription? _selectedAyahSub;

  @override
  void onInit() {
    super.onInit();
    chapter = Get.arguments as Chapter;
    _loadTimings();
    _startStopwatch();
    
    // Listen to active verse changes
    _activeVerseSub = audio.activeVerseKey.listen((key) {
      _onActiveVerseChanged(key);
    });

    // Listen to manual ayah selection/taps to seek audio
    _selectedAyahSub = QuranCtrl.instance.selectedAyahsByUnequeNumber.listen((selectedUqs) {
      if (selectedUqs.isNotEmpty) {
        final uq = selectedUqs.first;
        try {
          final ayahModel = QuranCtrl.instance.getAyahByUq(uq);
          final surahNum = ayahModel.surahNumber ?? chapter.id;
          final ayahNum = ayahModel.ayahNumber;

          if (surahNum == chapter.id && timings.isNotEmpty) {
            final targetKey = '$surahNum:$ayahNum';
            final timing = timings.firstWhere(
              (t) => t.verseKey == targetKey,
              orElse: () => timings.first,
            );
            audio.seekToTiming(timing);
            // Clear manual selection highlight so it doesn't linger over the active player highlight
            QuranCtrl.instance.clearSelection();
          }
        } catch (_) {}
      }
    });
  }

  void _startStopwatch() {
    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      storage.logReadingSeconds(1);
    });
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

  Future<void> _loadTimings() async {
    isLoading.value = true;
    try {
      final reciterId = storage.getEffectiveReciterId();
      final cached = storage.getCachedTimings(reciterId, chapter.id);
      if (cached != null) {
        timings = cached;
        return;
      }
      final audioData = await _api.fetchChapterAudioAndTimings(
        reciterId,
        chapter.id,
      );
      timings = audioData['timings'] as List<VerseTiming>;
      audioUrl = audioData['audio_url'] as String?;
    } catch (_) {
      // Non-critical
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> startPlaySurah() async {
    if (timings.isEmpty) {
      Get.snackbar('الصوت', 'بيانات توقيت التلاوة غير متوفرة.', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    try {
      final reciterId = storage.getEffectiveReciterId();
      final localPath = storage.getDownloadedAudioPath(reciterId, chapter.id);
      if (localPath != null) {
        await audio.playSurah(chapter, localPath, timings);
      } else if (audioUrl != null) {
        await audio.playSurah(chapter, audioUrl, timings);
      } else {
        Get.snackbar('الصوت', 'لا يوجد ملف صوتي. يرجى التحميل أولاً.', snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar('فشل تشغيل الصوت', '$e', snackPosition: SnackPosition.BOTTOM);
    }
  }

  void stopPlaySurah() {
    audio.stop();
    isRepeatAyah.value = false;
    ayahProgress.value = 0.0;
  }

  void previousAyah() {
    if (activeAyahNumber.value != null && activeAyahNumber.value! > 1) {
      final targetAyah = activeAyahNumber.value! - 1;
      if (timings.isNotEmpty) {
        final targetKey = '${chapter.id}:$targetAyah';
        final timing = timings.firstWhere(
          (t) => t.verseKey == targetKey,
          orElse: () => timings.first,
        );
        audio.seekToTiming(timing);
      }
    }
  }

  void toggleRepeat() {
    isRepeatAyah.value = !isRepeatAyah.value;
    audio.setRepeatCurrentAyah(isRepeatAyah.value);
  }

  String getReciterName() {
    final id = storage.getSelectedReciterId();
    const names = {
      7: 'مشاري العفاسي',
      6: 'محمود الحصري',
      2: 'عبد الباسط عبد الصمد',
      9: 'المنشاوي',
      1: 'عبدالله المطرود',
    };
    return names[id] ?? 'قارئ مختار';
  }

  @override
  void onClose() {
    _stopwatchTimer?.cancel();
    _activeVerseSub?.cancel();
    _selectedAyahSub?.cancel();
    QuranCtrl.instance.clearExternalHighlights();
    super.onClose();
  }
}
