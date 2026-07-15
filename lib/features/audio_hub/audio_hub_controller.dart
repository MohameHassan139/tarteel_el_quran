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

class AudioHubController extends GetxController {
  final ApiService _api = Get.find<ApiService>();
  final DownloadService _download = Get.find<DownloadService>();
  final StorageService _storage = Get.find<StorageService>();
  final AudioService _audio = Get.find<AudioService>();

  final RxList<Chapter> chapters = <Chapter>[].obs;
  final RxList<Chapter> filteredChapters = <Chapter>[].obs;
  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;
  final searchController = TextEditingController();

  // Bulk Downloading state
  final RxBool isBulkDownloading = false.obs;
  final RxInt bulkDownloadId = 0.obs;

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
    final query = searchController.text.toLowerCase();
    if (query.isEmpty) {
      filteredChapters.assignAll(chapters);
    } else {
      filteredChapters.assignAll(chapters.where((chapter) {
        return chapter.nameSimple.toLowerCase().contains(query) ||
            chapter.nameArabic.contains(query) ||
            chapter.translatedName.toLowerCase().contains(query);
      }).toList());
    }
  }

  bool isChapterDownloaded(Chapter chapter) {
    final reciterId = _storage.getEffectiveReciterId();
    return _storage.isChapterDownloaded(reciterId, chapter.id, chapter.versesCount);
  }

  Future<void> handleDownload(Chapter chapter) async {
    final reciterId = _storage.getEffectiveReciterId();
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
        await _download.deleteChapter(reciterId, chapter.id);
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
        final audioUrls = await _api.fetchChapterAudio(reciterId, chapter.id);
        if (audioUrls.isEmpty) throw Exception('رابط التحميل غير متوفر.');

        await _download.downloadChapter(reciterId, chapter.id, audioUrls);
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
    final reciterId = _storage.getEffectiveReciterId();

    Get.snackbar(
      'تحميل جماعي',
      'بدء تحميل كافة السور لهذا القارئ في الخلفية...',
      duration: const Duration(seconds: 3),
      snackPosition: SnackPosition.BOTTOM,
    );

    for (int i = 0; i < chapters.length; i++) {
      if (!isBulkDownloading.value) break; // Bulk process cancelled
      final chapter = chapters[i];
      final isDownloaded = _storage.isChapterDownloaded(reciterId, chapter.id, chapter.versesCount);

      if (!isDownloaded) {
        bulkDownloadId.value = chapter.id;

        try {
          final audioUrls = await _api.fetchChapterAudio(reciterId, chapter.id);
          if (audioUrls.isNotEmpty) {
            await _download.downloadChapter(reciterId, chapter.id, audioUrls);
          }
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
      final reciterId = _storage.getEffectiveReciterId();
      isLoading.value = true;

      for (var chapter in chapters) {
        if (_storage.isChapterDownloaded(reciterId, chapter.id, chapter.versesCount)) {
          await _download.deleteChapter(reciterId, chapter.id);
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
      try {
        audioPathsOrUrls = await _api.fetchChapterAudio(reciterId, chapter.id);
      } catch (e) {
        Get.snackbar(
          'فشل تشغيل الصوت',
          'فشل تشغيل الصوت: ${e.toString()}',
          backgroundColor: Colors.red[800],
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
    }

    try {
      await _audio.playSurah(chapter, audioPathsOrUrls);
    } catch (e) {
      Get.snackbar(
        'فشل تشغيل الصوت',
        'فشل تشغيل الصوت: ${e.toString()}',
        backgroundColor: Colors.red[800],
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> updateReciter(int reciterId) async {
    await _storage.setSelectedReciterId(reciterId);
    
    final currentStyle = _storage.getSelectedStyle();
    if (reciterId == 10) {
      await _storage.setSelectedStyle('teacher');
    } else if (reciterId != 6 && currentStyle == 'teacher') {
      await _storage.setSelectedStyle('murattal');
    } else if (reciterId != 6 && reciterId != 2 && reciterId != 9 && currentStyle == 'mujawwad') {
      await _storage.setSelectedStyle('murattal');
    }
    filteredChapters.refresh();
  }

  Future<void> updateStyle(String style) async {
    await _storage.setSelectedStyle(style);
    filteredChapters.refresh();
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
    searchController.dispose();
    super.onClose();
  }
}
