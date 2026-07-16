import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/api_service.dart';
import '../../core/download_service.dart';
import '../../core/storage_service.dart';
import '../../core/audio_service.dart';
import '../../models.dart';
import '../../core/app_colors.dart';
import 'package:quran_library/quran_library.dart' hide AudioService;

class AudioHubController extends GetxController {
  final ApiService _api = Get.find<ApiService>();
  final DownloadService _download = Get.find<DownloadService>();
  final StorageService _storage = Get.find<StorageService>();
  final AudioService _audio = Get.find<AudioService>();

  /// Exposed so the screen can directly observe activeProgress (RxMap)
  DownloadService get downloadService => _download;

  final RxList<Chapter> chapters = <Chapter>[].obs;
  final RxList<Chapter> filteredChapters = <Chapter>[].obs;
  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;
  final searchController = TextEditingController();

  final RxList<Mp3QuranReciter> mp3Reciters = <Mp3QuranReciter>[].obs;
  final Rxn<Mp3QuranReciter> selectedReciter = Rxn<Mp3QuranReciter>();
  final Rxn<Mp3QuranMoshaf> selectedMoshaf = Rxn<Mp3QuranMoshaf>();

  // Bulk Downloading state
  final RxBool isBulkDownloading = false.obs;
  final RxInt bulkDownloadId = 0.obs;

  @override
  void onInit() {
    super.onInit();
    searchController.addListener(filterChapters);
    _initSequenced();
  }

  /// Load chapters first, then reciters, so filterChapters always
  /// runs on a populated chapters list.
  Future<void> _initSequenced() async {
    await loadChapters();
    await loadMp3QuranData();
  }

  Future<void> loadChapters() async {
    try {
      await QuranCtrl.instance.ensureCoreDataLoaded();
      
      var list = await _api.fetchChapters();
      
      // Fallback: if API list is empty, generate from quran_library
      if (list.isEmpty) {
        list = QuranCtrl.instance.surahsList.map((s) => Chapter(
          id: s.number,
          nameSimple: s.englishName,
          nameComplex: s.englishName,
          nameArabic: s.name,
          versesCount: s.ayahsNumber,
          revelationPlace: s.revelationType,
          revelationOrder: 0,
          translatedName: s.englishNameTranslation,
        )).toList();
      }
      
      chapters.assignAll(list);
      filterChapters();
    } catch (_) {
      if (chapters.isEmpty) {
        final list = QuranCtrl.instance.surahsList.map((s) => Chapter(
          id: s.number,
          nameSimple: s.englishName,
          nameComplex: s.englishName,
          nameArabic: s.name,
          versesCount: s.ayahsNumber,
          revelationPlace: s.revelationType,
          revelationOrder: 0,
          translatedName: s.englishNameTranslation,
        )).toList();
        chapters.assignAll(list);
        filterChapters();
      }
    }
  }

  Future<void> loadMp3QuranData() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final lang = _storage.getAppLanguage();
      final list = await _api.fetchMp3QuranReciters(language: lang);
      mp3Reciters.assignAll(list);

      if (list.isNotEmpty) {
        final savedReciterId = _storage.getSelectedMp3ReciterId();
        Mp3QuranReciter reciter = list.firstWhere((r) => r.id == savedReciterId, orElse: () => list.first);
        selectedReciter.value = reciter;

        final savedMoshafId = _storage.getSelectedMp3MoshafId(reciter.id);
        Mp3QuranMoshaf? moshaf = reciter.moshafs.firstWhereOrNull((m) => m.id == savedMoshafId) ??
                                 (reciter.moshafs.isNotEmpty ? reciter.moshafs.first : null);
        selectedMoshaf.value = moshaf;
      }
      filterChapters();
    } catch (e) {
      // API and cache both failed — still try to show any downloaded surahs
      filterChapters();
      if (filteredChapters.isEmpty) {
        errorMessage.value = 'لا يوجد اتصال بالإنترنت ولا توجد بيانات محفوظة.';
      }
    } finally {
      isLoading.value = false;
    }
  }

  void filterChapters() {
    final query = searchController.text.toLowerCase().trim();

    final list = chapters.where((chapter) {
      // Find dynamic translation/names in quran_library
      final quranLibrarySurah = QuranCtrl.instance.surahsList.firstWhereOrNull((s) => s.number == chapter.id);
      
      if (quranLibrarySurah != null) {
        final normalizedQuery = _normalizeArabic(query);
        final normalizedArabic = _normalizeArabic(quranLibrarySurah.name);
        final normalizedEnglish = quranLibrarySurah.englishName.toLowerCase();
        final normalizedTranslation = quranLibrarySurah.englishNameTranslation.toLowerCase();
        
        return normalizedArabic.contains(normalizedQuery) ||
            normalizedEnglish.contains(query) ||
            normalizedTranslation.contains(query) ||
            quranLibrarySurah.number.toString() == query;
      }

      return chapter.nameSimple.toLowerCase().contains(query) ||
          chapter.nameArabic.contains(query) ||
          chapter.translatedName.toLowerCase().contains(query) ||
          chapter.id.toString() == query;
    }).toList();

    filteredChapters.assignAll(list);
  }

  String _normalizeArabic(String text) {
    final diacritics = RegExp(r'[\u064B-\u0652\u0670]');
    String cleaned = text.replaceAll(diacritics, '');
    cleaned = cleaned
        .replaceAll('ة', 'ه')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ئ', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned;
  }

  bool isChapterAvailable(Chapter chapter) {
    final reciter = selectedReciter.value;
    final moshaf = selectedMoshaf.value;
    if (reciter == null || moshaf == null) return false;
    
    // Always available if it's already downloaded offline
    if (_storage.isMp3QuranChapterDownloaded(reciter.id, moshaf.id, chapter.id)) {
      return true;
    }
    
    return moshaf.surahList.contains(chapter.id);
  }

  bool get isArabic => _storage.getAppLanguage() == 'ar';

  bool isChapterDownloaded(Chapter chapter) {
    final reciter = selectedReciter.value;
    final moshaf = selectedMoshaf.value;
    if (reciter == null || moshaf == null) return false;
    return _storage.isMp3QuranChapterDownloaded(reciter.id, moshaf.id, chapter.id);
  }

  Future<void> handleDownload(Chapter chapter) async {
    final reciter = selectedReciter.value;
    final moshaf = selectedMoshaf.value;
    if (reciter == null || moshaf == null) return;

    final isDownloaded = isChapterDownloaded(chapter);

    if (isDownloaded) {
      final confirm = await Get.dialog<bool>(
        AlertDialog(
          backgroundColor: AppColors.getCard(Get.isDarkMode),
          title: Text('حذف الصوت', style: TextStyle(color: Get.isDarkMode ? Colors.white : Colors.black87)),
          content: Text(
            'هل أنت متأكد من حذف الملف الصوتي لسورة ${chapter.nameSimple}؟',
            style: TextStyle(color: Get.isDarkMode ? Colors.grey : Colors.black54),
          ),
          actions: [
            TextButton(
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
              onPressed: () => Get.back(result: false),
            ),
            TextButton(
              child: const Text('حذف', style: TextStyle(color: Colors.red)),
              onPressed: () => Get.back(result: true),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await _download.deleteMp3QuranChapter(reciter.id, moshaf.id, chapter.id);
        filteredChapters.refresh();
        Get.snackbar(
          'حذف الصوت',
          'تم حذف الملف الصوتي لسورة ${chapter.nameSimple}',
          backgroundColor: Colors.grey[800],
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } else {
      try {
        final surahCode = chapter.id.toString().padLeft(3, '0');
        final url = '${moshaf.server}$surahCode.mp3';
        await _download.downloadMp3QuranChapter(reciter.id, moshaf.id, chapter.id, url);
        filteredChapters.refresh();
      } catch (e) {
        Get.snackbar(
          'فشل التحميل',
          'فشل التحميل: ${e.toString()}',
          backgroundColor: Colors.red[800],
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }

  Future<void> startBulkDownload() async {
    isBulkDownloading.value = true;
    final reciter = selectedReciter.value;
    final moshaf = selectedMoshaf.value;
    if (reciter == null || moshaf == null) {
      isBulkDownloading.value = false;
      return;
    }

    Get.snackbar(
      'تحميل جماعي',
      'بدء تحميل كافة السور لهذا القارئ في الخلفية...',
      duration: const Duration(seconds: 3),
      snackPosition: SnackPosition.BOTTOM,
    );

    for (int i = 0; i < chapters.length; i++) {
      if (!isBulkDownloading.value) break;
      final chapter = chapters[i];
      if (!moshaf.surahList.contains(chapter.id)) continue;

      final isDownloaded = _storage.isMp3QuranChapterDownloaded(reciter.id, moshaf.id, chapter.id);

      if (!isDownloaded) {
        bulkDownloadId.value = chapter.id;

        try {
          final surahCode = chapter.id.toString().padLeft(3, '0');
          final url = '${moshaf.server}$surahCode.mp3';
          await _download.downloadMp3QuranChapter(reciter.id, moshaf.id, chapter.id, url);
        } catch (e) {
          debugPrint('Bulk download error for chapter ${chapter.id}: $e');
        }
      }
    }

    if (isBulkDownloading.value) {
      isBulkDownloading.value = false;
      bulkDownloadId.value = 0;
      Get.snackbar(
        'تحميل جماعي',
        'اكتمل تحميل جميع سور القارئ المختار! 🎉',
        backgroundColor: AppColors.primary,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void cancelBulkDownload() {
    isBulkDownloading.value = false;
    bulkDownloadId.value = 0;
    Get.snackbar(
      'تحميل جماعي',
      'تم إيقاف عملية التحميل الجماعي.',
      backgroundColor: Colors.orange,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> deleteAllAudio() async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.getCard(Get.isDarkMode),
        title: Text('حذف جميع التلاوات', style: TextStyle(color: Get.isDarkMode ? Colors.white : Colors.black87)),
        content: Text(
          'هل أنت متأكد من حذف كافة الملفات الصوتية المخزنة لهذا القارئ؟',
          style: TextStyle(color: Get.isDarkMode ? Colors.grey : Colors.black54),
        ),
        actions: [
          TextButton(
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            onPressed: () => Get.back(result: false),
          ),
          TextButton(
            child: const Text('حذف الكل', style: TextStyle(color: Colors.red)),
            onPressed: () => Get.back(result: true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final reciter = selectedReciter.value;
      final moshaf = selectedMoshaf.value;
      if (reciter == null || moshaf == null) return;

      isLoading.value = true;

      for (var chapter in chapters) {
        if (_storage.isMp3QuranChapterDownloaded(reciter.id, moshaf.id, chapter.id)) {
          await _download.deleteMp3QuranChapter(reciter.id, moshaf.id, chapter.id);
        }
      }

      isLoading.value = false;
      filteredChapters.refresh();
      Get.snackbar(
        'إفراغ التلاوات',
        'تم إفراغ التلاوات المخزنة بالكامل.',
        backgroundColor: Colors.grey,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> playSurah(Chapter chapter) async {
    final reciter = selectedReciter.value;
    final moshaf = selectedMoshaf.value;
    if (reciter == null || moshaf == null) return;

    final isDownloaded = _storage.isMp3QuranChapterDownloaded(reciter.id, moshaf.id, chapter.id);
    List<String> audioPathsOrUrls = [];

    if (isDownloaded) {
      final dirPath = _storage.getMp3QuranDownloadedAudioDirectory(reciter.id, moshaf.id, chapter.id);
      if (dirPath != null && Directory(dirPath).existsSync()) {
        final files = Directory(dirPath).listSync().where((f) => f.path.endsWith('.mp3')).toList();
        if (files.isNotEmpty) {
          audioPathsOrUrls = [files.first.path];
        }
      }
    }

    if (audioPathsOrUrls.isEmpty) {
      final surahCode = chapter.id.toString().padLeft(3, '0');
      audioPathsOrUrls = ['${moshaf.server}$surahCode.mp3'];
    }

    final quranLibrarySurah = QuranCtrl.instance.surahsList.firstWhereOrNull((s) => s.number == chapter.id);
    final isAr = _storage.getAppLanguage() == 'ar';
    final displayName = isAr
        ? (quranLibrarySurah?.name ?? chapter.nameArabic)
        : (quranLibrarySurah?.englishName ?? chapter.nameSimple);

    final mediaItem = MediaItem(
      id: 'audio_hub_${reciter.id}_${moshaf.id}_${chapter.id}',
      title: displayName,
      artist: reciter.name,
      album: isAr ? 'مكتبة التلاوات' : 'Audio Hub Library',
    );

    try {
      _audio.onChapterFinished = _playNextChapter;
      await _audio.playSurah(
        chapter,
        audioPathsOrUrls,
        clearCompletionCallback: false,
        mediaItems: [mediaItem],
      );
    } catch (e) {
      Get.snackbar(
        'خطأ في تشغيل الصوت',
        'فشل تشغيل سورة ${chapter.nameSimple}. سيتم الانتقال تلقائيًا للسورة التالية...',
        backgroundColor: Colors.orange[900],
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );

      // Auto-skip to next surah if there are other surahs in the list
      if (filteredChapters.length > 1) {
        Future.delayed(const Duration(seconds: 4), () {
          // Only skip if the callback is still active and audio is not playing
          if (_audio.onChapterFinished == _playNextChapter && !_audio.isPlaying.value) {
            _playNextChapter(failedChapterId: chapter.id);
          }
        });
      }
    }
  }

  Future<void> _playNextChapter({int? failedChapterId}) async {
    final current = _audio.activeChapter.value ?? 
                    (failedChapterId != null ? chapters.firstWhereOrNull((c) => c.id == failedChapterId) : null);
    if (current == null || filteredChapters.isEmpty) return;

    // Filter out the available chapters in the current list
    final availableFiltered = filteredChapters.where((c) => isChapterAvailable(c)).toList();
    if (availableFiltered.isEmpty) return;

    int currentIndex = availableFiltered.indexWhere((c) => c.id == current.id);
    if (currentIndex == -1) {
      // Fallback: try finding in all chapters
      final availableAll = chapters.where((c) => isChapterAvailable(c)).toList();
      if (availableAll.isEmpty) return;
      
      currentIndex = availableAll.indexWhere((c) => c.id == current.id);
      if (currentIndex == -1) {
        await playSurah(availableAll.first);
        return;
      }
      
      final nextIndex = (currentIndex + 1) % availableAll.length;
      await playSurah(availableAll[nextIndex]);
      return;
    }

    final nextIndex = (currentIndex + 1) % availableFiltered.length;
    await playSurah(availableFiltered[nextIndex]);
  }

  Future<void> updateReciter(int reciterId) async {
    final reciter = mp3Reciters.firstWhere((r) => r.id == reciterId);
    selectedReciter.value = reciter;
    await _storage.setSelectedMp3ReciterId(reciterId);

    final savedMoshafId = _storage.getSelectedMp3MoshafId(reciterId);
    final moshaf = reciter.moshafs.firstWhereOrNull((m) => m.id == savedMoshafId) ??
                   (reciter.moshafs.isNotEmpty ? reciter.moshafs.first : null);
    selectedMoshaf.value = moshaf;

    filterChapters();
  }

  Future<void> updateMoshaf(int moshafId) async {
    final reciter = selectedReciter.value;
    if (reciter != null) {
      final moshaf = reciter.moshafs.firstWhere((m) => m.id == moshafId);
      selectedMoshaf.value = moshaf;
      await _storage.setSelectedMp3MoshafId(reciter.id, moshafId);
      filterChapters();
    }
  }

  String get bulkProgressString {
    if (bulkDownloadId.value == 0) return '0%';
    final currentCh = chapters.firstWhere((c) => c.id == bulkDownloadId.value, orElse: () => chapters.first);
    final completed = chapters.indexOf(currentCh);
    final percentage = ((completed / chapters.length) * 100).toInt();
    return '$percentage%';
  }

  @override
  void onClose() {
    if (_audio.onChapterFinished == _playNextChapter) {
      _audio.onChapterFinished = null;
    }
    searchController.dispose();
    super.onClose();
  }
}
