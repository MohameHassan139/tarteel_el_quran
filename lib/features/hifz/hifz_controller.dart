import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quran_library/quran_library.dart' hide AudioService;
import '../../core/audio_service.dart';
import '../../core/api_service.dart';
import '../../core/storage_service.dart';
import '../../models.dart';

class HifzController extends GetxController {
  final AudioService _audio = Get.find<AudioService>();
  final ApiService _api = Get.find<ApiService>();
  final StorageService _storage = Get.find<StorageService>();

  final RxList<Chapter> chapters = <Chapter>[].obs;
  final Rxn<Chapter> selectedChapter = Rxn<Chapter>();
  
  final startAyahController = TextEditingController(text: '1');
  final endAyahController = TextEditingController(text: '7');

  final RxInt verseRepetitions = 3.obs;
  final RxInt rangeRepetitions = 2.obs;
  final RxInt selectedReciterId = 7.obs;
  final RxString selectedStyle = 'murattal'.obs;

  final RxBool isHifzActive = false.obs;
  final RxBool isLoading = false.obs;
  final RxList<Verse> hifzVerses = <Verse>[].obs;
  final Rxn<Verse> currentRecitingVerse = Rxn<Verse>();

  StreamSubscription? _activeVerseSub;

  @override
  void onInit() {
    super.onInit();
    selectedReciterId.value = _storage.getSelectedReciterId();
    selectedStyle.value = _storage.getSelectedStyle();
    loadChapters();

    // Listen to changes in the active reciting verse
    _activeVerseSub = _audio.activeVerseKey.listen((activeKey) {
      _onActiveVerseChanged(activeKey);
    });
  }

  void loadChapters() {
    final cached = _storage.getCachedChapters();
    if (cached != null && cached.isNotEmpty) {
      chapters.assignAll(cached);
      selectedChapter.value = cached.first;
      updateEndAyahField(cached.first);
    }
  }

  void updateEndAyahField(Chapter chapter) {
    startAyahController.text = '1';
    endAyahController.text = '${chapter.versesCount}';
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

  Future<void> startHifz() async {
    final chapter = selectedChapter.value;
    if (chapter == null) return;

    final int startAyah = int.tryParse(startAyahController.text) ?? 1;
    final int endAyah = int.tryParse(endAyahController.text) ?? chapter.versesCount;

    if (startAyah < 1 || endAyah > chapter.versesCount || startAyah > endAyah) {
      Get.snackbar('خطأ النطاق', 'نطاق الآيات غير صالح.', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    isLoading.value = true;
    isHifzActive.value = true;

    try {
      // Get local ayahs from quran_library and map to Verse models using local translation
      final localAyahs = QuranCtrl.instance.surahs[chapter.id - 1].ayahs;
      await TafsirCtrl.instance.initTafsir();
      await TafsirCtrl.instance.fetchTranslate();
      final mappedVerses = localAyahs.map((a) {
        final verseKey = '${chapter.id}:${a.ayahNumber}';
        final translation = TafsirCtrl.instance.getTranslationText(chapter.id, a.ayahNumber);
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
      hifzVerses.assignAll(mappedVerses.where((v) => v.verseNumber >= startAyah && v.verseNumber <= endAyah).toList());

      final reciterId = _storage.getEffectiveReciterId();
      final isDownloaded = _storage.isChapterDownloaded(reciterId, chapter.id, chapter.versesCount);

      List<String> audioPathsOrUrls = [];

      if (isDownloaded) {
        final dirPath = _storage.getDownloadedAudioDirectory(reciterId, chapter.id);
        if (dirPath != null && Directory(dirPath).existsSync()) {
          audioPathsOrUrls = List.generate(chapter.versesCount, (i) => '$dirPath/${i+1}.mp3');
        }
      } 
      
      if (audioPathsOrUrls.isEmpty) {
        audioPathsOrUrls = await _api.fetchChapterAudio(reciterId, chapter.id);
      }

      if (audioPathsOrUrls.isEmpty) {
        throw Exception('الروابط غير متوفرة لهذه السورة.');
      }

      final config = HifzLoopConfig(
        startVerseKey: '${chapter.id}:$startAyah',
        endVerseKey: '${chapter.id}:$endAyah',
        verseRepetitions: verseRepetitions.value,
        rangeRepetitions: rangeRepetitions.value,
      );

      await _audio.playHifz(chapter, audioPathsOrUrls, config);
    } catch (e) {
      Get.snackbar('خطأ حلقة الحفظ', 'فشل بدء حلقة الحفظ: ${e.toString()}', snackPosition: SnackPosition.BOTTOM);
      isHifzActive.value = false;
    } finally {
      isLoading.value = false;
    }
  }

  void stopHifz() {
    _audio.stop();
    isHifzActive.value = false;
    currentRecitingVerse.value = null;
    hifzVerses.clear();
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
  }

  Future<void> updateStyle(String style) async {
    selectedStyle.value = style;
    await _storage.setSelectedStyle(style);
  }

  @override
  void onClose() {
    startAyahController.dispose();
    endAyahController.dispose();
    _activeVerseSub?.cancel();
    super.onClose();
  }
}
