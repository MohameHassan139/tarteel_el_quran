import 'package:get/get.dart';
import 'package:quran_library/quran_library.dart' hide AudioService;
import '../models.dart';
import 'storage_service.dart';

/// Locale-aware helpers for showing surah names / revelation places.
///
/// Stored data (local Hifz history, synced teacher sessions, live activity)
/// historically saved the *Arabic* surah name, so an English-mode user (or a
/// teacher whose app is in English) saw Arabic text. Everything that has a
/// chapter id should resolve its display name through here instead.
class SurahDisplay {
  SurahDisplay._();

  static final Map<int, Chapter> _cache = {};

  static bool get isArabic => (Get.locale?.languageCode ?? 'ar') == 'ar';

  static Chapter? _chapter(int chapterId) {
    if (chapterId < 1 || chapterId > 114) return null;
    final cached = _cache[chapterId];
    if (cached != null) return cached;

    if (Get.isRegistered<StorageService>()) {
      final list = Get.find<StorageService>().getCachedChapters();
      if (list != null && list.isNotEmpty) {
        for (final c in list) {
          _cache[c.id] = c;
        }
        final hit = _cache[chapterId];
        if (hit != null) return hit;
      }
    }

    try {
      final surahs = QuranCtrl.instance.surahsList;
      if (surahs.length >= chapterId) {
        final s = surahs[chapterId - 1];
        final c = Chapter(
          id: s.number,
          nameSimple: s.englishName,
          nameComplex: s.englishName,
          nameArabic: s.name,
          versesCount: s.ayahsNumber,
          revelationPlace: s.revelationType,
          revelationOrder: 0,
          translatedName: s.englishNameTranslation,
        );
        _cache[chapterId] = c;
        return c;
      }
    } catch (_) {}
    return null;
  }

  /// Removes a leading "سورة"/"سُورَةُ" so callers can prefix it themselves
  /// without producing "سورة سُورَةُ الفاتحة".
  static String stripArabicSurahPrefix(String name) {
    final trimmed = name.trim();
    final match = RegExp(r'^\s*سُ?و?رَ?ةُ?\s+').firstMatch(trimmed);
    if (match != null) return trimmed.substring(match.end).trim();
    if (trimmed.startsWith('سورة ')) return trimmed.substring(5).trim();
    return trimmed;
  }

  /// Bare surah name in the current UI language (no "Surah"/"سورة" prefix).
  static String name(int chapterId, {String fallback = ''}) {
    final c = _chapter(chapterId);
    if (c == null) {
      if (fallback.isNotEmpty) return isArabic ? stripArabicSurahPrefix(fallback) : fallback;
      return chapterId > 0 ? '$chapterId' : '';
    }
    return isArabic ? stripArabicSurahPrefix(c.nameArabic) : c.nameSimple;
  }

  /// Prefixed name, e.g. "سورة الفاتحة" / "Surah Al-Faatiha".
  static String title(int chapterId, {String fallback = ''}) =>
      'surah_title_param'.trParams({'name': name(chapterId, fallback: fallback)});

  /// "سورة الفاتحة (1 - 7)" / "Surah Al-Faatiha (1 - 7)".
  static String rangeTitle(int chapterId, int start, int end, {String fallback = ''}) {
    return 'surah_range_param'.trParams({
      'name': name(chapterId, fallback: fallback),
      'start': '$start',
      'end': '$end',
    });
  }

  /// Works for every source we get data from: alquran.cloud ("Meccan"),
  /// quran.com ("makkah") and quran_library's offline list ("مكية").
  static bool isMeccan(String place) {
    final p = place.trim().toLowerCase();
    return p.startsWith('mec') || p.startsWith('mak') || p.contains('مك');
  }

  static String revelationLabel(String place) =>
      isMeccan(place) ? 'revelation_meccan'.tr : 'revelation_medinan'.tr;

  /// Reciter display name from an id, falling back to a stored name.
  static String reciterName(int? reciterId, {String fallback = ''}) {
    if (reciterId != null) {
      final key = 'reciter_$reciterId';
      final translated = key.tr;
      if (translated != key) return translated;
    }
    return fallback.isNotEmpty ? fallback : 'reciter_unknown'.tr;
  }
}
