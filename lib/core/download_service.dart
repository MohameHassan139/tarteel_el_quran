import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:get/get.dart';
import 'storage_service.dart';
import 'api_service.dart';

class DownloadService extends GetxService {
  final StorageService _storageService = Get.find<StorageService>();

  // Reactive map to broadcast download progress
  // Key: "reciterId_chapterId", Value: double progress (0.0 to 1.0)
  final RxMap<String, double> activeProgress = <String, double>{}.obs;

  Stream<Map<String, double>> get progressStream => activeProgress.stream;

  double? getProgress(int reciterId, int chapterId) {
    return activeProgress['${reciterId}_$chapterId'];
  }

  /// Download multiple Ayah audio files for a Surah.
  Future<void> downloadChapter(int reciterId, int chapterId, List<String> urls) async {
    final taskKey = '${reciterId}_$chapterId';
    if (activeProgress.containsKey(taskKey)) return; // Already downloading

    activeProgress[taskKey] = 0.0;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${appDir.path}/audio_downloads/${reciterId}_$chapterId');
      
      if (await downloadsDir.exists()) {
        await downloadsDir.delete(recursive: true);
      }
      await downloadsDir.create(recursive: true);

      final client = http.Client();
      final totalFiles = urls.length;

      try {
        for (int i = 0; i < urls.length; i++) {
          final url = urls[i];
          final request = http.Request('GET', Uri.parse(url));
          final response = await client.send(request).timeout(const Duration(seconds: 15));

          final file = File('${downloadsDir.path}/${i + 1}.mp3');
          final IOSink sink = file.openWrite();
          
          await response.stream.pipe(sink);
          await sink.flush();
          await sink.close();

          activeProgress[taskKey] = (i + 1) / totalFiles;
        }

        client.close();

        // Save path to local database
        await _storageService.setDownloadedAudioDirectory(reciterId, chapterId, downloadsDir.path);

        activeProgress.remove(taskKey);

        // Start background download of Tafsirs (non-blocking)
        unawaited(() async {
          try {
            final api = Get.find<ApiService>();
            // Cache Tafsir identifiers
            await api.fetchAndCacheChapterTafsir(chapterId, identifier: 'ar.muyassar');
            await api.fetchAndCacheChapterTafsir(chapterId, identifier: 'ar.jalalayn');
          } catch (_) {
            // Fail silently to avoid breaking anything if network drops mid-way
          }
        }());
      } catch (e) {
        client.close();
        if (await downloadsDir.exists()) {
          await downloadsDir.delete(recursive: true);
        }
        rethrow;
      }
    } catch (e) {
      activeProgress.remove(taskKey);
      rethrow;
    }
  }

  /// Delete a downloaded audio directory from disk and storage metadata.
  Future<void> deleteChapter(int reciterId, int chapterId) async {
    final dirPath = _storageService.getDownloadedAudioDirectory(reciterId, chapterId);
    if (dirPath != null) {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        try {
          await dir.delete(recursive: true);
        } catch (_) {}
      }
      await _storageService.deleteDownloadedAudioDirectory(reciterId, chapterId);
      // Force UI updates by removing any active item or triggering a refresh
      activeProgress.refresh();
    }
  }
}
