import 'package:get/get.dart';
import '../../../core/surah_display.dart';

/// Human text for a student's `liveActivity` map, rendered in the VIEWER's
/// language (the stored `label` is only a fallback for older app versions).
String liveActivityFeatureLabel(Map<String, dynamic> activity) {
  switch (activity['feature'] as String? ?? '') {
    case 'hifz':
      return 'teacher_link_feature_hifz'.tr;
    case 'audio':
      return 'teacher_link_feature_audio'.tr;
    default:
      return 'teacher_link_feature_mushaf'.tr;
  }
}

String liveActivitySubject(Map<String, dynamic> activity) {
  final chapterId = activity['chapterId'] as int?;
  final pageNumber = activity['pageNumber'] as int?;
  final label = activity['label'] as String? ?? '';
  final isAr = Get.locale?.languageCode == 'ar';

  if (chapterId == null) {
    if (pageNumber != null) {
      return isAr ? 'صفحة $pageNumber' : 'Page $pageNumber';
    }
    return label;
  }
  final start = activity['startAyah'] as int?;
  final end = activity['endAyah'] as int?;
  final surahName = SurahDisplay.name(chapterId, fallback: label);
  if (start != null && end != null) {
    return '$surahName ($start-$end)';
  }
  if (pageNumber != null) {
    return isAr ? '$surahName (صفحة $pageNumber)' : '$surahName (Page $pageNumber)';
  }
  return surahName;
}

String liveActivityElapsed(Map<String, dynamic> activity) {
  final elapsedSeconds = activity['elapsedSeconds'] as int? ?? 0;
  final minutes = elapsedSeconds ~/ 60;
  final seconds = elapsedSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
