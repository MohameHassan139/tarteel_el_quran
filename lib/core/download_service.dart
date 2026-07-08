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

  /// Download continuous Surah audio.
  Future<void> downloadChapter(int reciterId, int chapterId, String url) async {
    final taskKey = '${reciterId}_$chapterId';
    if (activeProgress.containsKey(taskKey)) return; // Already downloading

    activeProgress[taskKey] = 0.0;

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request).timeout(const Duration(seconds: 25));

      final int totalLength = response.contentLength ?? 0;
      if (totalLength <= 0) {
        throw Exception('Unable to determine audio file size.');
      }

      final appDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${appDir.path}/audio_downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final file = File('${downloadsDir.path}/reciter_${reciterId}_chapter_$chapterId.mp3');
      if (await file.exists()) {
        await file.delete();
      }

      final IOSink sink = file.openWrite();
      int downloadedBytes = 0;

      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          downloadedBytes += chunk.length;

          final progress = downloadedBytes / totalLength;
          activeProgress[taskKey] = progress;
        }

        // Flush and close file safely
        await sink.flush();
        await sink.close();
        client.close();

        // Save path to local database
        await _storageService.setDownloadedAudioPath(reciterId, chapterId, file.path);

        activeProgress.remove(taskKey);

        // Start background download of Tafsirs (non-blocking)
        unawaited(() async {
          try {
            final api = Get.find<ApiService>();
            // Cache Tafsir IDs: 16 (Al-Muyassar), 91 (Ibn Kathir), 131 (Saheeh International)
            await api.fetchAndCacheChapterTafsir(chapterId, tafsirId: 16);
            await api.fetchAndCacheChapterTafsir(chapterId, tafsirId: 91);
            await api.fetchAndCacheChapterTafsir(chapterId, tafsirId: 131);
          } catch (_) {
            // Fail silently to avoid breaking anything if network drops mid-way
          }
        }());
      } catch (e) {
        await sink.close();
        client.close();
        if (await file.exists()) {
          await file.delete();
        }
        rethrow;
      }
    } catch (e) {
      activeProgress.remove(taskKey);
      rethrow;
    }
  }

  /// Delete a downloaded audio file from disk and storage metadata.
  Future<void> deleteChapter(int reciterId, int chapterId) async {
    final filePath = _storageService.getDownloadedAudioPath(reciterId, chapterId);
    if (filePath != null) {
      final file = File(filePath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      await _storageService.deleteDownloadedAudioPath(reciterId, chapterId);
      // Force UI updates by removing any active item or triggering a refresh
      activeProgress.refresh();
    }
  }
}
