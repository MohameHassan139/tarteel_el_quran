import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../core/audio_service.dart';
import '../../core/download_service.dart';
import '../../core/storage_service.dart';
import '../../core/connectivity_service.dart';
import '../../core/app_colors.dart';
import 'rare_recitation_model.dart';
import 'rare_recitations_data.dart';

class RareRecitationsController extends GetxController {
  final AudioService _audio = Get.find<AudioService>();
  final DownloadService _download = Get.find<DownloadService>();
  final StorageService _storage = Get.find<StorageService>();
  final ConnectivityService _connectivity = Get.find<ConnectivityService>();

  DownloadService get downloadService => _download;
  AudioService get audioService => _audio;

  final TextEditingController searchController = TextEditingController();
  final RxString selectedReciterFilter = 'الكل'.obs;
  final RxBool onlyDownloaded = false.obs;

  final RxList<RareRecitation> allCurated = <RareRecitation>[].obs;
  final RxList<RareRecitation> filteredRecitations = <RareRecitation>[].obs;

  @override
  void onInit() {
    super.onInit();
    allCurated.assignAll(RareRecitationsData.curatedRecitations);
    filterRecitations();
    searchController.addListener(filterRecitations);
  }

  @override
  void onClose() {
    searchController.removeListener(filterRecitations);
    searchController.dispose();
    super.onClose();
  }

  void setReciterFilter(String reciter) {
    selectedReciterFilter.value = reciter;
    filterRecitations();
  }

  void toggleOnlyDownloaded() {
    onlyDownloaded.value = !onlyDownloaded.value;
    filterRecitations();
  }

  void filterRecitations() {
    final query = searchController.text.trim().toLowerCase();
    final reciter = selectedReciterFilter.value;
    final showOnlyDownloaded = onlyDownloaded.value;

    final results = allCurated.where((item) {
      // Filter by Reciter
      if (reciter != 'الكل' && !item.reciterName.contains(reciter)) {
        return false;
      }

      // Filter by Downloaded status
      if (showOnlyDownloaded && !_storage.isRareRecitationDownloaded(item.id)) {
        return false;
      }

      // Filter by Search Query
      if (query.isNotEmpty) {
        final matchesTitle = item.title.toLowerCase().contains(query);
        final matchesReciter = item.reciterName.toLowerCase().contains(query);
        final matchesLocation = item.location.toLowerCase().contains(query);
        final matchesSurah = item.surahName.toLowerCase().contains(query);
        final matchesTags = item.tags.any((t) => t.toLowerCase().contains(query));

        if (!matchesTitle && !matchesReciter && !matchesLocation && !matchesSurah && !matchesTags) {
          return false;
        }
      }

      return true;
    }).toList();

    filteredRecitations.assignAll(results);
  }

  bool isDownloaded(String id) {
    return _storage.isRareRecitationDownloaded(id);
  }

  bool isPlaying(String id) {
    return _audio.customId.value == id && _audio.isPlaying.value;
  }

  bool isCurrentTrack(String id) {
    return _audio.customId.value == id;
  }

  Future<void> playRecitation(RareRecitation item) async {
    final downloaded = _storage.isRareRecitationDownloaded(item.id);
    final isOnline = _connectivity.isOnline.value;

    if (!downloaded && !isOnline) {
      Get.snackbar(
        'audio_play_error'.tr,
        'audio_offline_not_downloaded'.tr,
        backgroundColor: Colors.orange[900],
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    String audioPathOrUrl = item.audioUrl;
    if (downloaded) {
      final localPath = _storage.getRareRecitationDownloadedPath(item.id);
      if (localPath != null && localPath.isNotEmpty) {
        audioPathOrUrl = localPath;
      }
    }

    try {
      if (isCurrentTrack(item.id)) {
        if (_audio.isPlaying.value) {
          await _audio.pause();
        } else {
          await _audio.resume();
        }
      } else {
        await _audio.playRareRecitation(
          id: item.id,
          title: item.title,
          reciterName: item.reciterName,
          audioPathOrUrl: audioPathOrUrl,
          location: item.location,
        );
      }
    } catch (e) {
      Get.snackbar(
        'audio_play_error'.tr,
        'audio_play_failed'.tr,
        backgroundColor: Colors.red[800],
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> handleDownload(RareRecitation item) async {
    final downloaded = _storage.isRareRecitationDownloaded(item.id);

    if (downloaded) {
      final confirm = await Get.dialog<bool>(
        AlertDialog(
          backgroundColor: AppColors.getCard(Get.isDarkMode),
          title: Text(
            'delete_audio'.tr,
            style: TextStyle(color: Get.isDarkMode ? Colors.white : Colors.black87),
          ),
          content: Text(
            'delete_rare_confirm'.trParams({'title': item.title}),
            style: TextStyle(color: Get.isDarkMode ? Colors.grey : Colors.black54),
          ),
          actions: [
            TextButton(
              child: Text('cancel'.tr, style: const TextStyle(color: Colors.grey)),
              onPressed: () => Get.back(result: false),
            ),
            TextButton(
              child: Text('delete'.tr, style: const TextStyle(color: Colors.red)),
              onPressed: () => Get.back(result: true),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await _download.deleteRareRecitation(item.id);
        filterRecitations();
        Get.snackbar(
          'deleted_success'.tr,
          'audio_deleted'.tr,
          backgroundColor: Colors.grey[800],
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } else {
      if (!_connectivity.isOnline.value) {
        Get.snackbar(
          'no_internet_title'.tr,
          'download_requires_internet'.tr,
          backgroundColor: Colors.orange[900],
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      try {
        Get.snackbar(
          'download_started'.tr,
          item.title,
          duration: const Duration(seconds: 2),
          snackPosition: SnackPosition.BOTTOM,
        );
        await _download.downloadRareRecitation(item.id, item.audioUrl);
        filterRecitations();
        Get.snackbar(
          'download_complete'.tr,
          item.title,
          backgroundColor: AppColors.primary,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      } catch (e) {
        Get.snackbar(
          'download_failed'.tr,
          e.toString(),
          backgroundColor: Colors.red[800],
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }

  void copyShareInfo(RareRecitation item) {
    final text = '✨ تلاوة نادرة وخاشعة:\n${item.title}\n🎙 القارئ: ${item.reciterName}\n📍 المحفل: ${item.location}\n🎧 استمع عبر تطبيق ترتيل القرآن: ${item.audioUrl}';
    Clipboard.setData(ClipboardData(text: text));
    Get.snackbar(
      'link_copied'.tr,
      'recitation_info_copied'.tr,
      backgroundColor: AppColors.primary,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }
}
