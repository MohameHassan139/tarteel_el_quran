import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'storage_service.dart';
import '../main.dart';

class DownloadService {
  final StorageService _storageService;

  // Stream controller to broadcast download progress
  // Key: "reciterId_chapterId", Value: double progress (0.0 to 1.0)
  final _progressController = StreamController<Map<String, double>>.broadcast();
  final Map<String, double> _activeProgress = {};

  DownloadService(this._storageService);

  Stream<Map<String, double>> get progressStream => _progressController.stream;

  double? getProgress(int reciterId, int chapterId) {
    return _activeProgress['${reciterId}_$chapterId'];
  }

  /// Download continuous Surah audio.
  Future<void> downloadChapter(int reciterId, int chapterId, String url) async {
    final taskKey = '${reciterId}_$chapterId';
    if (_activeProgress.containsKey(taskKey)) return; // Already downloading

    _activeProgress[taskKey] = 0.0;
    _progressController.add(Map.from(_activeProgress));

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
          _activeProgress[taskKey] = progress;
          _progressController.add(Map.from(_activeProgress));
        }

        // Flush and close file safely
        await sink.flush();
        await sink.close();
        client.close();

        // Save path to local database
        await _storageService.setDownloadedAudioPath(reciterId, chapterId, file.path);

        _activeProgress.remove(taskKey);
        _progressController.add(Map.from(_activeProgress));

        // Start background download of Tafsirs (non-blocking)
        unawaited(() async {
          try {
            final api = Locator.api;
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
      _activeProgress.remove(taskKey);
      _progressController.add(Map.from(_activeProgress));
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
      // Force UI updates by triggering progress streams with a completed delete event
      _progressController.add(Map.from(_activeProgress));
    }
  }
}
