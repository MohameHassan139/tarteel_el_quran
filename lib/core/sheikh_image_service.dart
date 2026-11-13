import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:get/get.dart';
import 'storage_service.dart';

/// Service responsible for managing, downloading, and caching Sheikh portraits locally.
/// Supports offline-first loading so portraits are stored in device local storage.
class SheikhImageService extends GetxService {
  StorageService get _storage => Get.find<StorageService>();

  /// Curated map of well-known reciters to official high-quality portrait URLs.
  /// Uses reliable Wikimedia Commons / Quran CDN / Mp3Quran assets.
  static final Map<String, String> _knownReciterImages = {
    // مشاري راشد العفاسي
    'alafasy': 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d4/Mishary_Rashid_Alafasy_2022.jpg/480px-Mishary_Rashid_Alafasy_2022.jpg',
    'عفاسي': 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d4/Mishary_Rashid_Alafasy_2022.jpg/480px-Mishary_Rashid_Alafasy_2022.jpg',
    // عبد الباسط عبد الصمد
    'abdulbasit': 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/6f/Abdulbasit_Abdusamad.jpg/480px-Abdulbasit_Abdusamad.jpg',
    'عبد الباسط': 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/6f/Abdulbasit_Abdusamad.jpg/480px-Abdulbasit_Abdusamad.jpg',
    // محمد صديق المنشاوي
    'minshawi': 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/23/Mohamed_Siddiq_El-Minshawi.jpg/480px-Mohamed_Siddiq_El-Minshawi.jpg',
    'المنشاوي': 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/23/Mohamed_Siddiq_El-Minshawi.jpg/480px-Mohamed_Siddiq_El-Minshawi.jpg',
    'منشاوي': 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/23/Mohamed_Siddiq_El-Minshawi.jpg/480px-Mohamed_Siddiq_El-Minshawi.jpg',
    // محمود خليل الحصري
    'husary': 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e4/Mahmoud_Khalil_Al-Hussary.jpg/480px-Mahmoud_Khalil_Al-Hussary.jpg',
    'الحصري': 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e4/Mahmoud_Khalil_Al-Hussary.jpg/480px-Mahmoud_Khalil_Al-Hussary.jpg',
    'حصري': 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e4/Mahmoud_Khalil_Al-Hussary.jpg/480px-Mahmoud_Khalil_Al-Hussary.jpg',
    // عبد الرحمن السديس
    'sudais': 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/87/Abdul-Rahman_Al-Sudais_at_USIM.jpg/480px-Abdul-Rahman_Al-Sudais_at_USIM.jpg',
    'السديس': 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/87/Abdul-Rahman_Al-Sudais_at_USIM.jpg/480px-Abdul-Rahman_Al-Sudais_at_USIM.jpg',
    'سديس': 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/87/Abdul-Rahman_Al-Sudais_at_USIM.jpg/480px-Abdul-Rahman_Al-Sudais_at_USIM.jpg',
    // ماهر المعيقلي
    'maher': 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/10/Maher_Al_Muaiqly_2022.jpg/480px-Maher_Al_Muaiqly_2022.jpg',
    'معيقلي': 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/10/Maher_Al_Muaiqly_2022.jpg/480px-Maher_Al_Muaiqly_2022.jpg',
    // سعد الغامدي
    'ghamdi': 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/89/Saad_al_Ghamdi.jpg/480px-Saad_al_Ghamdi.jpg',
    'الغامدي': 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/89/Saad_al_Ghamdi.jpg/480px-Saad_al_Ghamdi.jpg',
    'غامدي': 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/89/Saad_al_Ghamdi.jpg/480px-Saad_al_Ghamdi.jpg',
    // سعود الشريم
    'shuraim': 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/52/Saud_Al-Shuraim.jpg/480px-Saud_Al-Shuraim.jpg',
    'شريم': 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/52/Saud_Al-Shuraim.jpg/480px-Saud_Al-Shuraim.jpg',
    // ياسر الدوسري
    'dosari': 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/af/Yasser_Al-Dosari.jpg/480px-Yasser_Al-Dosari.jpg',
    'الدوسري': 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/af/Yasser_Al-Dosari.jpg/480px-Yasser_Al-Dosari.jpg',
    'دوسري': 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/af/Yasser_Al-Dosari.jpg/480px-Yasser_Al-Dosari.jpg',
    // أحمد بن علي العجمي
    'ajamy': 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/05/Ahmed_ibn_Ali_al-Ajmy.jpg/480px-Ahmed_ibn_Ali_al-Ajmy.jpg',
    'العجمي': 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/05/Ahmed_ibn_Ali_al-Ajmy.jpg/480px-Ahmed_ibn_Ali_al-Ajmy.jpg',
    'عجمي': 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/05/Ahmed_ibn_Ali_al-Ajmy.jpg/480px-Ahmed_ibn_Ali_al-Ajmy.jpg',
    // علي الحذيفي
    'hudhaify': 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3b/Ali_Al-Hudaifi.jpg/480px-Ali_Al-Hudaifi.jpg',
    'الحذيفي': 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3b/Ali_Al-Hudaifi.jpg/480px-Ali_Al-Hudaifi.jpg',
    'حذيفي': 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3b/Ali_Al-Hudaifi.jpg/480px-Ali_Al-Hudaifi.jpg',
    // أبو بكر الشاطري
    'shaatree': 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/7b/Abu_Bakr_al-Shatri.jpg/480px-Abu_Bakr_al-Shatri.jpg',
    'الشاطري': 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/7b/Abu_Bakr_al-Shatri.jpg/480px-Abu_Bakr_al-Shatri.jpg',
    'شاطري': 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/7b/Abu_Bakr_al-Shatri.jpg/480px-Abu_Bakr_al-Shatri.jpg',
    // محمد أيوب
    'ayyoub': 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/47/Muhammad_Ayyub.jpg/480px-Muhammad_Ayyub.jpg',
    'أيوب': 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/47/Muhammad_Ayyub.jpg/480px-Muhammad_Ayyub.jpg',
    // أيمن سويد
    'swaid': 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/77/Ayman_Rushdi_Swayd.jpg/480px-Ayman_Rushdi_Swayd.jpg',
    'سويد': 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/77/Ayman_Rushdi_Swayd.jpg/480px-Ayman_Rushdi_Swayd.jpg',
    // هاني الرفاعي
    'rifai': 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/0e/Hani_ar-Rifai.jpg/480px-Hani_ar-Rifai.jpg',
    'الرفاعي': 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/0e/Hani_ar-Rifai.jpg/480px-Hani_ar-Rifai.jpg',
    // ناصر القطامي
    'qatami': 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d7/Nasser_Al_Qatami.jpg/480px-Nasser_Al_Qatami.jpg',
    'القطامي': 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d7/Nasser_Al_Qatami.jpg/480px-Nasser_Al_Qatami.jpg',
    // فارس عباد
    'abbad': 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/61/Fares_Abbad.jpg/480px-Fares_Abbad.jpg',
    'عباد': 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/61/Fares_Abbad.jpg/480px-Fares_Abbad.jpg',
  };

  /// Normalizes reciter name to create a safe cache key
  String _normalizeKey(String name) {
    return name
        .replaceAll(RegExp(r'[\u064B-\u0652\u0670\u0640]'), '')
        .replaceAll(RegExp(r'[آأإٱ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'[^\w\u0621-\u064A]+'), '_')
        .toLowerCase()
        .trim();
  }

  /// Attempts to find a known portrait URL for a given reciter name
  String? getKnownImageUrl(String reciterName) {
    final clean = reciterName.toLowerCase();
    for (final entry in _knownReciterImages.entries) {
      if (clean.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return null;
  }

  /// Returns the local cached image File if it already exists in local storage
  Future<File?> getLocalCachedImage(String reciterName) async {
    try {
      final key = _normalizeKey(reciterName);
      final savedPath = _storage.getCachedReciterImage(key);
      if (savedPath != null) {
        final file = File(savedPath);
        if (await file.exists()) {
          return file;
        }
      }

      // Check default directory
      final docsDir = await getApplicationDocumentsDirectory();
      final targetFile = File('${docsDir.path}/sheikh_images/$key.jpg');
      if (await targetFile.exists()) {
        await _storage.setCachedReciterImage(key, targetFile.path);
        return targetFile;
      }
    } catch (e) {
      debugPrint('Error getting cached sheikh image: $e');
    }
    return null;
  }

  /// Downloads and caches the sheikh portrait into local storage.
  /// Returns the local File on success, or null on failure.
  Future<File?> cacheSheikhImage(String reciterName, [String? explicitUrl]) async {
    try {
      final key = _normalizeKey(reciterName);
      final url = explicitUrl ?? getKnownImageUrl(reciterName);
      if (url == null) return null;

      final docsDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${docsDir.path}/sheikh_images');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final file = File('${dir.path}/$key.jpg');

      // If already downloaded, return it directly
      if (await file.exists()) {
        await _storage.setCachedReciterImage(key, file.path);
        return file;
      }

      // Download from network
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        await file.writeAsBytes(response.bodyBytes);
        await _storage.setCachedReciterImage(key, file.path);
        return file;
      }
    } catch (e) {
      debugPrint('Failed to cache sheikh image for $reciterName: $e');
    }
    return null;
  }

  /// Save a user-chosen image file as the portrait for a reciter in local storage
  Future<File?> saveCustomSheikhImage(String reciterName, File sourceFile) async {
    try {
      final key = _normalizeKey(reciterName);
      final docsDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${docsDir.path}/sheikh_images');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final destFile = File('${dir.path}/$key.jpg');
      await sourceFile.copy(destFile.path);
      await _storage.setCachedReciterImage(key, destFile.path);
      return destFile;
    } catch (e) {
      debugPrint('Failed to save custom sheikh image: $e');
      return null;
    }
  }
}
