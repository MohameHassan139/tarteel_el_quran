import 'dart:convert';
import 'package:http/http.dart' as http;
import 'rare_recitation_model.dart';

class RareRecitationsService {
  final http.Client _client = http.Client();

  /// Search the Internet Archive for rare recordings and concerts.
  Future<List<RareRecitation>> searchArchive(String query) async {
    if (query.trim().isEmpty) return [];

    final cleanQuery = query.trim();
    final searchUrl = Uri.parse(
      'https://archive.org/advancedsearch.php?q=mediatype%3Aaudio+AND+(${Uri.encodeComponent(cleanQuery)})&fl[]=identifier,title,creator,year,description&output=json&rows=15',
    );

    try {
      final response = await _client.get(
        searchUrl,
        headers: {'User-Agent': 'TarteelElQuranApp/1.0'},
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) return [];

      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final docs = (data['response']?['docs'] as List?) ?? [];

      final List<RareRecitation> results = [];

      for (final doc in docs) {
        final id = doc['identifier']?.toString() ?? '';
        final title = doc['title']?.toString() ?? 'تلاوة نادرة';
        final creator = doc['creator']?.toString() ?? 'قارئ من الزمن الجميل';
        final year = doc['year']?.toString();
        final location = year != null ? 'تسجيل إذاعي ($year)' : 'تسجيل إذاعي تاريخي';

        // Direct streamable URL or metadata file
        final audioUrl = 'https://archive.org/download/$id/$id.mp3';

        results.add(
          RareRecitation(
            id: 'archive_$id',
            title: title,
            reciterName: creator,
            location: location,
            surahName: title,
            duration: 'تسجيل كامل',
            audioUrl: audioUrl,
            era: year ?? 'الأرشيف التاريخي',
            tags: ['أرشيف مفتوح', 'إذاعي'],
          ),
        );
      }

      return results;
    } catch (_) {
      return [];
    }
  }

  void dispose() {
    _client.close();
  }
}
