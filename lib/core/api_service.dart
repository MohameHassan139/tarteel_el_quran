import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'storage_service.dart';
import '../models.dart';

// --- API Exceptions ---

abstract class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class NetworkException extends ApiException {
  NetworkException(String message) : super(message);
}

class UnauthorizedException extends ApiException {
  UnauthorizedException(String message, [int? statusCode]) : super(message, statusCode);
}

class NotFoundException extends ApiException {
  NotFoundException(String message, [int? statusCode]) : super(message, statusCode);
}

class ServerException extends ApiException {
  ServerException(String message, [int? statusCode]) : super(message, statusCode);
}

class UnknownApiException extends ApiException {
  UnknownApiException(String message, [int? statusCode]) : super(message, statusCode);
}

// --- API Service Implementation ---

class ApiService extends GetxService {
  final StorageService _storageService = Get.find<StorageService>();

  static const String apiBaseUrl = 'https://api.alquran.cloud/v1';

  /// Map internal Reciter IDs to Al Quran Cloud identifiers
  String getReciterIdentifier(int id, {String style = 'murattal'}) {
    // Treat as effective ID if resolved, otherwise resolve base ID
    switch (id) {
      case 7: return 'ar.alafasy';
      case 6: return style == 'mujawwad' ? 'ar.husarymujawwad' : (style == 'teacher' ? 'ar.aymanswoaid' : 'ar.husary');
      case 12: return 'ar.husarymujawwad';
      case 13: return 'ar.aymanswoaid';
      case 2: return style == 'mujawwad' ? 'ar.abdulsamad' : 'ar.abdulbasitmurattal';
      case 1: return 'ar.abdulsamad';
      case 9: return style == 'mujawwad' ? 'ar.minshawimujawwad' : 'ar.minshawi';
      case 8: return 'ar.minshawimujawwad';
      case 10: return 'ar.aymanswoaid';
      case 3: return 'ar.abdurrahmaansudais';
      case 11: return 'ar.abdullahbasfar';
      case 14: return 'ar.hanirifai';
      case 15: return 'ar.hudhaify';
      case 16: return 'ar.ibrahimakhbar';
      case 17: return 'ar.mahermuaiqly';
      case 18: return 'ar.muhammadayyoub';
      case 19: return 'ar.muhammadjibreel';
      case 20: return 'ar.saoodshuraym';
      case 21: return 'ar.parhizgar';
      case 22: return 'ar.shaatree';
      case 23: return 'ar.ahmedajamy';
      default: return 'ar.alafasy';
    }
  }

  /// Perform GET request with error handling
  Future<http.Response> _get(String path) async {
    final uri = Uri.parse('$apiBaseUrl$path');

    try {
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 20));

      return _handleResponse(response);
    } on SocketException catch (_) {
      throw NetworkException('Network unavailable. Failed to reach Al Quran Cloud servers.');
    } on ApiException {
      rethrow;
    } on Exception catch (e) {
      throw UnknownApiException('An unexpected network error occurred: ${e.toString()}');
    }
  }

  /// Handle response status codes
  http.Response _handleResponse(http.Response response) {
    final int code = response.statusCode;
    if (code >= 200 && code < 300) {
      return response;
    } else if (code == 401 || code == 403) {
      throw UnauthorizedException('Access denied.', code);
    } else if (code == 404) {
      throw NotFoundException('Requested resource not found.', code);
    } else if (code >= 500) {
      throw ServerException('Al Quran Cloud servers are currently experiencing issues.', code);
    } else {
      throw UnknownApiException('Request failed with status code $code: ${response.body}', code);
    }
  }

  // --- Core API Features ---

  /// Fetch Chapters (Surah List).
  Future<List<Chapter>> fetchChapters() async {
    try {
      final response = await _get('/surah');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = data['data'] as List;
      final chapters = list.map((e) => Chapter.fromJson(e as Map<String, dynamic>)).toList();

      // Cache chapters locally
      await _storageService.cacheChapters(chapters);
      return chapters;
    } catch (e) {
      // Fallback to cache
      final cached = _storageService.getCachedChapters();
      if (cached != null) {
        return cached;
      }
      rethrow; 
    }
  }

  /// Fetch Verses of a Chapter with Arabic text and English translation.
  Future<List<Verse>> fetchVerses(int chapterId) async {
    try {
      // Fetch both Uthmani and English translation in one request
      final response = await _get('/surah/$chapterId/editions/quran-uthmani,en.asad');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final editions = data['data'] as List;
      
      if (editions.isEmpty) return [];

      final uthmaniAyahs = editions[0]['ayahs'] as List;
      final translationAyahs = editions.length > 1 ? editions[1]['ayahs'] as List : [];

      final List<Verse> verses = [];
      for (int i = 0; i < uthmaniAyahs.length; i++) {
        final Map<String, dynamic> merged = Map.from(uthmaniAyahs[i]);
        if (i < translationAyahs.length) {
          merged['translationText'] = translationAyahs[i]['text'];
        }
        merged['surah_number'] = chapterId;
        verses.add(Verse.fromJson(merged));
      }

      // Cache verses locally
      await _storageService.cacheVerses(chapterId, verses);
      return verses;
    } catch (e) {
      // Fallback to cache
      final cached = _storageService.getCachedVerses(chapterId);
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  /// Fetch all reciters from mp3quran.net API
  Future<List<Mp3QuranReciter>> fetchMp3QuranReciters({required String language}) async {
    final uri = Uri.parse('https://mp3quran.net/api/v3/reciters?language=$language');
    try {
      final response = await http.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = data['reciters'] as List? ?? [];
        final reciters = list.map((e) => Mp3QuranReciter.fromJson(e as Map<String, dynamic>)).toList();
        
        // Cache the list locally
        await _storageService.cacheMp3QuranReciters(reciters);
        return reciters;
      } else {
        throw Exception('Failed to fetch reciters: ${response.statusCode}');
      }
    } catch (e) {
      // Fallback to cache if available
      final cached = _storageService.getCachedMp3QuranReciters();
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  /// Fetch audio URLs for a chapter from AlQuran Cloud.
  /// Returns a list of strings representing the audio URL for each ayah.
  Future<List<String>> fetchChapterAudio(int reciterId, int chapterId) async {
    try {
      final style = _storageService.getSelectedStyle();
      final identifier = getReciterIdentifier(reciterId, style: style);
      
      final response = await _get('/surah/$chapterId/$identifier');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final surahData = data['data'] as Map<String, dynamic>;
      final ayahs = surahData['ayahs'] as List;

      final List<String> audioUrls = ayahs.map((a) => a['audio'] as String).toList();
      return audioUrls;
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch Tafsir of a specific Ayah by key (e.g. "1:2").
  Future<String> fetchTafsir(String verseKey, {String identifier = 'ar.muyassar'}) async {
    try {
      final response = await _get('/ayah/$verseKey/$identifier');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tafsirData = data['data'] as Map<String, dynamic>;
      final tafsirText = tafsirData['text'] as String;

      // Tafsir uses internal tafsirId mapping for cache backwards compatibility
      // Let's assume Muyassar is ID 16 for cache compatibility
      await _storageService.cacheTafsir(16, verseKey, tafsirText);
      return tafsirText;
    } catch (e) {
      // Fallback to cache
      final cached = _storageService.getCachedTafsir(16, verseKey);
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  /// Fetch and cache all Tafsir texts for a specific Chapter (Surah) in one request.
  Future<void> fetchAndCacheChapterTafsir(int chapterId, {String identifier = 'ar.muyassar'}) async {
    try {
      final response = await _get('/surah/$chapterId/$identifier');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final surahData = data['data'] as Map<String, dynamic>;
      final ayahs = surahData['ayahs'] as List;
      
      for (final item in ayahs) {
        final map = item as Map<String, dynamic>;
        final verseNum = map['numberInSurah'];
        final text = map['text'] as String?;
        if (text != null) {
          final verseKey = '$chapterId:$verseNum';
          await _storageService.cacheTafsir(16, verseKey, text);
        }
      }
    } catch (_) {
      // Fallback or ignore for background downloads
      rethrow;
    }
  }
}
