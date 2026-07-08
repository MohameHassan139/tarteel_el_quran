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

class AuthException extends ApiException {
  AuthException(String message) : super(message);
}

// --- API Service Implementation ---

class ApiService extends GetxService {
  final StorageService _storageService = Get.find<StorageService>();

  static const String authBaseUrl = 'https://oauth2.quran.foundation';
  static const String apiBaseUrl = 'https://apis.quran.foundation';
  static const String clientId = '263fccef-cea3-40f9-89a0-1b0589342da8';
  static const String clientSecret = '_JEuOmQzVOyaFUy4ZFV6ahd~HB';

  /// Authenticate with client credentials flow and cache token.
  Future<String> _getAccessToken() async {
    // Check cache
    final cachedToken = _storageService.getCachedOAuthToken();
    final cachedExpiry = _storageService.getCachedOAuthTokenExpiry();

    // If token exists and has > 30 seconds before expiring, use it
    if (cachedToken != null && cachedExpiry > DateTime.now().millisecondsSinceEpoch + 30000) {
      return cachedToken;
    }

    try {
      final authUrl = Uri.parse('$authBaseUrl/oauth2/token');
      final basicAuth = 'Basic ${base64Encode(utf8.encode('$clientId:$clientSecret'))}';

      final response = await http.post(
        authUrl,
        headers: {
          'Authorization': basicAuth,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type': 'client_credentials',
          'scope': 'content',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['access_token'] as String;
        final expiresIn = data['expires_in'] as int;

        await _storageService.cacheOAuthToken(token, expiresIn);
        return token;
      } else {
        throw AuthException('OAuth2 Token Exchange Failed: ${response.statusCode} - ${response.body}');
      }
    } on SocketException catch (_) {
      throw NetworkException('Connection to Auth Server failed. Please check your internet connection.');
    } on Exception catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Authentication error: ${e.toString()}');
    }
  }

  /// Perform authenticated GET request with complete error handling.
  Future<http.Response> _getWithAuth(String path, [Map<String, String>? queryParams]) async {
    final String token;
    try {
      token = await _getAccessToken();
    } catch (e) {
      // If auth fails, try to proceed without token or wrap auth errors
      if (e is NetworkException) rethrow;
      throw UnauthorizedException('Authentication failed: ${e.toString()}');
    }

    final uri = Uri.parse('$apiBaseUrl$path').replace(queryParameters: queryParams);

    try {
      final response = await http.get(
        uri,
        headers: {
          'x-auth-token': token,
          'x-client-id': clientId,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 20));

      return _handleResponse(response);
    } on SocketException catch (_) {
      throw NetworkException('Network unavailable. Failed to reach Quran.com servers.');
    } on ApiException {
      rethrow;
    } on Exception catch (e) {
      throw UnknownApiException('An unexpected network error occurred: ${e.toString()}');
    }
  }

  /// Handle response status codes and map to proper ApiException.
  http.Response _handleResponse(http.Response response) {
    final int code = response.statusCode;
    if (code >= 200 && code < 300) {
      return response;
    } else if (code == 401 || code == 403) {
      throw UnauthorizedException('Access denied. Please check client configuration.', code);
    } else if (code == 404) {
      throw NotFoundException('Requested resource not found.', code);
    } else if (code >= 500) {
      throw ServerException('Quran.com servers are currently experiencing issues. Please try again later.', code);
    } else {
      throw UnknownApiException('Request failed with status code $code: ${response.body}', code);
    }
  }

  // --- Core API Features ---

  /// Fetch Chapters (Surah List).
  Future<List<Chapter>> fetchChapters() async {
    try {
      final response = await _getWithAuth('/content/api/v4/chapters');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = data['chapters'] as List;
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
      rethrow; // If no cache, bubble up the api exception
    }
  }

  /// Fetch Verses of a Chapter with Arabic text and English translation.
  Future<List<Verse>> fetchVerses(int chapterId) async {
    try {
      final response = await _getWithAuth(
        '/content/api/v4/verses/by_chapter/$chapterId',
        {
          'fields': 'text_uthmani',
          'translations': '85', // M.A.S. Abdel Haleem translation
          'per_page': '300', // Fetch all verses in one request
        },
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = data['verses'] as List;
      final verses = list.map((e) => Verse.fromJson(e as Map<String, dynamic>)).toList();

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

  /// Fetch audio timing segment details and streaming URL.
  Future<Map<String, dynamic>> fetchChapterAudioAndTimings(int reciterId, int chapterId) async {
    try {
      final response = await _getWithAuth(
        '/content/api/v4/chapter_recitations/$reciterId/$chapterId',
        {'segments': 'true'},
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final audioFile = data['audio_file'] as Map<String, dynamic>;

      final audioUrl = audioFile['audio_url'] as String;
      final rawTimings = audioFile['timestamps'] as List? ?? [];
      final timings = rawTimings.map((e) => VerseTiming.fromJson(e as Map<String, dynamic>)).toList();

      // Cache timings locally
      await _storageService.cacheTimings(reciterId, chapterId, timings);

      return {
        'audio_url': audioUrl,
        'timings': timings,
      };
    } catch (e) {
      // Fallback to cache
      final cachedTimings = _storageService.getCachedTimings(reciterId, chapterId);
      if (cachedTimings != null) {
        return {
          'audio_url': null, // Audio stream URL not available offline unless downloaded
          'timings': cachedTimings,
        };
      }
      rethrow;
    }
  }

  /// Fetch Tafsir of a specific Ayah by key (default = التفسير الميسر Arabic ID 16).
  Future<String> fetchTafsir(String verseKey, {int tafsirId = 16}) async {
    try {
      final response = await _getWithAuth('/content/api/v4/tafsirs/$tafsirId/by_ayah/$verseKey');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tafsirData = data['tafsir'] as Map<String, dynamic>;
      final tafsirText = tafsirData['text'] as String;

      // Cache tafsir locally
      await _storageService.cacheTafsir(tafsirId, verseKey, tafsirText);
      return tafsirText;
    } catch (e) {
      // Fallback to cache
      final cached = _storageService.getCachedTafsir(tafsirId, verseKey);
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  /// Fetch and cache all Tafsir texts for a specific Chapter (Surah) in one request.
  Future<void> fetchAndCacheChapterTafsir(int chapterId, {int tafsirId = 16}) async {
    try {
      final response = await _getWithAuth('/content/api/v4/tafsirs/$tafsirId/by_chapter/$chapterId');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tafsirList = data['tafsirs'] as List? ?? [];
      
      for (final item in tafsirList) {
        final map = item as Map<String, dynamic>;
        final verseKey = map['verse_key'] as String?;
        final text = map['text'] as String?;
        if (verseKey != null && text != null) {
          await _storageService.cacheTafsir(tafsirId, verseKey, text);
        }
      }
    } catch (_) {
      // Fallback or ignore for background downloads
      rethrow;
    }
  }
}
