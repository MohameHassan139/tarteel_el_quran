import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quran_library/quran_library.dart' hide AudioService;
import '../../core/audio_service.dart';
import '../../core/storage_service.dart';
import '../../models.dart';
import 'hifz_controller.dart';
import '../../core/app_colors.dart';

class HifzScreen extends GetView<HifzController> {
  const HifzScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = Get.find<StorageService>();
    final isDark = storage.isDarkMode();
    final audio = Get.find<AudioService>();

    return Obx(() {
      if (controller.isHifzActive.value) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('مساحة الحفظ والتركيز'),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => controller.stopHifz(),
            ),
          ),
          body: Obx(() {
            if (controller.isLoading.value) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              );
            }

            final currentVerse = controller.currentRecitingVerse.value;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Verse indicators
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        currentVerse != null
                            ? 'الآية ${currentVerse.verseKey}'
                            : 'جاري تهيئة مساحة الحفظ...',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Large Clean text workspace
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (currentVerse != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: () {
                                  final parts = currentVerse.verseKey.split(':');
                                  final surahNum = int.tryParse(parts[0]) ?? 1;
                                  final ayahNum = int.tryParse(parts.length > 1 ? parts[1] : '1') ?? 1;
                                  return GetSingleAyah(
                                    surahNumber: surahNum,
                                    ayahNumber: ayahNum,
                                    isDark: true,
                                    fontSize: 34,
                                    isBold: false,
                                  );
                                }(),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                currentVerse.translationText,
                                style: TextStyle(
                                  fontSize: 17,
                                  color: Colors.grey[400],
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ] else
                              const Text(
                                'جاري التحميل والتزامن...',
                                style: TextStyle(color: Colors.grey, fontSize: 16),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Looping status indicators
                  Card(
                    color: AppColors.cardDark,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('تكرار الآية الحالية', style: TextStyle(color: Colors.grey)),
                              Obx(() {
                                final count = audio.verseRepeat.value;
                                return Text(
                                  '$count / ${controller.verseRepetitions.value}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                );
                              }),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('تكرار النطاق الكامل', style: TextStyle(color: Colors.grey)),
                              Obx(() {
                                final count = audio.rangeRepeat.value;
                                return Text(
                                  '$count / ${controller.rangeRepetitions.value}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                );
                              }),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Stop button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[800],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    icon: const Icon(Icons.stop, color: Colors.white),
                    label: const Text('الخروج من مساحة الحفظ', style: TextStyle(color: Colors.white, fontSize: 16)),
                    onPressed: () => controller.stopHifz(),
                  ),
                ],
              ),
            );
          }),
        );
      }

      if (controller.chapters.isEmpty) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('حفظ القرآن الكريم'),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'لا توجد سور مخزنة مؤقتاً.\n\nيرجى فتح شاشة "المصحف الشريف" أولاً أثناء الاتصال بالإنترنت لتحميل تفاصيل السور.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }

      return Scaffold(
        appBar: AppBar(
          title: const Text('حفظ القرآن الكريم', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'اختر السورة ونطاق الآيات',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              
              // Surah Dropdown selector
              DropdownButtonFormField<Chapter>(
                value: controller.selectedChapter.value,
                dropdownColor: isDark ? AppColors.cardDark : Colors.white,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? AppColors.secondaryDark : Colors.grey[200],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                items: controller.chapters.map((chapter) {
                  return DropdownMenuItem(
                    value: chapter,
                    child: Text('سورة ${chapter.nameSimple} (${chapter.nameArabic})'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    controller.selectedChapter.value = val;
                    controller.updateEndAyahField(val);
                  }
                },
              ),
              const SizedBox(height: 16),
              
              // Range Inputs
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('بداية الآية', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: controller.startAyahController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                             filled: true,
                             fillColor: isDark ? AppColors.secondaryDark : Colors.grey[200],
                             border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                           ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('نهاية الآية', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: controller.endAyahController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isDark ? AppColors.secondaryDark : Colors.grey[200],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'خيارات التكرار والتحفيظ',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              
              // Repetitions selectors
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.secondaryDark : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: controller.verseRepetitions.value,
                          dropdownColor: isDark ? AppColors.cardDark : Colors.white,
                          items: List.generate(10, (i) => i + 1).map((e) {
                            return DropdownMenuItem(value: e, child: Text('تكرار الآية: $e مرات'));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              controller.verseRepetitions.value = val;
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.secondaryDark : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: controller.rangeRepetitions.value,
                          isExpanded: true,
                          dropdownColor: isDark ? AppColors.cardDark : Colors.white,
                          items: List.generate(10, (i) => i + 1).map((e) {
                            return DropdownMenuItem(
                              value: e,
                              child: Text(
                                'تكرار النطاق: $e مرات',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              controller.rangeRepetitions.value = val;
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'القارئ المختار للتلاوة',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: controller.selectedReciterId.value,
                dropdownColor: isDark ? AppColors.cardDark : Colors.white,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? AppColors.secondaryDark : Colors.grey[200],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15),
                items: const [
                  DropdownMenuItem(value: 7, child: Text('مشاري العفاسي')),
                  DropdownMenuItem(value: 6, child: Text('محمود الحصري')),
                  DropdownMenuItem(value: 2, child: Text('عبد الباسط عبد الصمد')),
                  DropdownMenuItem(value: 9, child: Text('محمد صديق المنشاوي')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    controller.updateReciter(val);
                  }
                },
              ),
              if (controller.selectedReciterId.value == 6) ...[
                const SizedBox(height: 16),
                  const Text(
                  'رواية/أسلوب التلاوة',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: controller.selectedStyle.value,
                  dropdownColor: isDark ? AppColors.cardDark : Colors.white,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDark ? AppColors.secondaryDark : Colors.grey[200],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15),
                  items: const [
                    DropdownMenuItem(value: 'murattal', child: Text('مرتّل')),
                    DropdownMenuItem(value: 'mujawwad', child: Text('معلّم')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      controller.updateStyle(val);
                    }
                  },
                ),
              ],
              const SizedBox(height: 32),
              
              // Start Hifz Workspace button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                icon: const Icon(Icons.play_arrow, color: Colors.white),
                label: const Text('ابدأ حلقة الحفظ والتركيز', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                onPressed: () => controller.startHifz(),
              ),
            ],
          ),
        ),
      );
    });
  }
}
