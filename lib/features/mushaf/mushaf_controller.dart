import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quran_library/quran_library.dart' hide AudioService;
import '../../core/api_service.dart';
import '../../core/download_service.dart';
import '../../core/storage_service.dart';
import '../../models.dart';
import '../../core/app_colors.dart';

class MushafController extends GetxController {
  final ApiService _api = Get.find<ApiService>();
  final DownloadService _download = Get.find<DownloadService>();
  final StorageService _storage = Get.find<StorageService>();

  final RxList<Chapter> chapters = <Chapter>[].obs;
  final RxList<Chapter> filteredChapters = <Chapter>[].obs;
  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;
  final searchController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    loadChapters();
    searchController.addListener(filterChapters);
  }

  Future<void> loadChapters() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      // Ensure local quran_library core data is fully loaded
      await QuranCtrl.instance.ensureCoreDataLoaded();
      
      final list = await _api.fetchChapters();
      chapters.assignAll(list);
      filteredChapters.assignAll(list);
    } on ApiException catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = 'فشل الاتصال بالخادم وتحميل السور: ${e.toString()}';
    } finally {
      isLoading.value = false;
    }
  }

  void filterChapters() {
    final query = searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      filteredChapters.assignAll(chapters);
    } else {
      filteredChapters.assignAll(chapters.where((chapter) {
        // Retrieve matching surah in quran_library
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

        // Fallback search using API chapter fields
        return chapter.nameSimple.toLowerCase().contains(query) ||
            chapter.nameArabic.contains(query) ||
            chapter.translatedName.toLowerCase().contains(query) ||
            chapter.id.toString() == query;
      }).toList());
    }
  }

  String _normalizeArabic(String text) {
    // Remove Arabic diacritics (tashkeel)
    final diacritics = RegExp(r'[\u064B-\u0652\u0670]');
    String cleaned = text.replaceAll(diacritics, '');
    
    // Normalize specific characters
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

  bool isChapterDownloaded(Chapter chapter) {
    final reciterId = _storage.getSelectedReciterId();
    return _storage.isChapterDownloaded(reciterId, chapter.id, chapter.versesCount);
  }

  Future<void> handleDownload(Chapter chapter) async {
    final reciterId = _storage.getSelectedReciterId();
    final isDownloaded = isChapterDownloaded(chapter);

    if (isDownloaded) {
      final confirm = await Get.dialog<bool>(
        AlertDialog(
          backgroundColor: AppColors.getCard(Get.isDarkMode),
          title: Text('حذف الصوت', style: TextStyle(color: Get.isDarkMode ? Colors.white : Colors.black87)),
          content: Text(
            'هل أنت متأكد من حذف الملف الصوتي الخاص بسورة ${chapter.nameSimple} من الهاتف؟',
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
        await _download.deleteChapter(reciterId, chapter.id);
        filteredChapters.refresh(); // Trigger updates
        Get.snackbar(
          'حذف الصوت',
          'تم حذف الملف الصوتي لسورة ${chapter.nameSimple}',
          backgroundColor: Colors.grey[800],
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } else {
      Get.snackbar(
        'تحميل التلاوة',
        'جاري بدء تحميل سورة ${chapter.nameSimple}...',
        duration: const Duration(seconds: 2),
        snackPosition: SnackPosition.BOTTOM,
      );

      try {
        final audioUrls = await _api.fetchChapterAudio(reciterId, chapter.id);
        if (audioUrls.isEmpty) {
          throw Exception('عذراً، لم نتمكن من الحصول على رابط التحميل.');
        }

        await _download.downloadChapter(reciterId, chapter.id, audioUrls);
        filteredChapters.refresh();
        Get.snackbar(
          'نجاح التحميل',
          'تم تحميل سورة ${chapter.nameSimple} بنجاح!',
          backgroundColor: AppColors.primary,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
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

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }
}
