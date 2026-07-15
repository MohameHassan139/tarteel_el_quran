import 'dart:async';
import 'dart:io';
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

  List<String> audioPathsOrUrls = [];
  Timer? _stopwatchTimer;
  StreamSubscription? _activeVerseSub;
  StreamSubscription? _selectedAyahSub;

  @override
  void onInit() {
    super.onInit();
    chapter = Get.arguments as Chapter;
    _loadAudio();
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

          if (surahNum == chapter.id && audioPathsOrUrls.isNotEmpty) {
            final targetKey = '$surahNum:$ayahNum';
            audio.seekToVerse(targetKey);
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

  Future<void> _loadAudio() async {
    isLoading.value = true;
    try {
      final reciterId = storage.getEffectiveReciterId();
      final isDownloaded = storage.isChapterDownloaded(reciterId, chapter.id, chapter.versesCount);
      
      if (isDownloaded) {
        final dirPath = storage.getDownloadedAudioDirectory(reciterId, chapter.id);
        if (dirPath != null && Directory(dirPath).existsSync()) {
          audioPathsOrUrls = List.generate(chapter.versesCount, (i) => '$dirPath/${i+1}.mp3');
          return;
        }
      }
      
      audioPathsOrUrls = await _api.fetchChapterAudio(reciterId, chapter.id);
    } catch (_) {
      // Non-critical
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> startPlaySurah() async {
    if (audioPathsOrUrls.isEmpty) {
      Get.snackbar('الصوت', 'الروابط غير متوفرة. يرجى التأكد من الاتصال بالإنترنت.', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    try {
      await audio.playSurah(chapter, audioPathsOrUrls);
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
