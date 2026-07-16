import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quran_library/quran_library.dart' hide AudioService;
import '../../models.dart';
import 'hifz_controller.dart';
import '../../core/app_colors.dart';

class HifzScreen extends GetView<HifzController> {
  const HifzScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Obx(() {
      // 1. If Hifz Workspace is active, show the active memorization workspace
      if (controller.isHifzActive.value) {
        return _buildWorkspace(context, isDark);
      }

      // 2. Otherwise, show the landing dashboard (New Session & Progress Dashboard)
      return Scaffold(
        backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
        appBar: AppBar(
          title: const Text('حفظ القرآن الكريم', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => controller.activeTabIndex.value = 0,
                        child: Obx(() {
                          final isActive = controller.activeTabIndex.value == 0;
                          return Container(
                            decoration: BoxDecoration(
                              color: isActive ? AppColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(25),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.play_circle_outline_rounded,
                                  color: isActive ? Colors.white : Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'جلسة جديدة',
                                  style: TextStyle(
                                    color: isActive ? Colors.white : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => controller.activeTabIndex.value = 1,
                        child: Obx(() {
                          final isActive = controller.activeTabIndex.value == 1;
                          return Container(
                            decoration: BoxDecoration(
                              color: isActive ? AppColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(25),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.bar_chart_rounded,
                                  color: isActive ? Colors.white : Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'لوحة الإحصائيات',
                                  style: TextStyle(
                                    color: isActive ? Colors.white : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: Obx(() {
          if (controller.chapters.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            );
          }
          if (controller.activeTabIndex.value == 0) {
            return _buildNewSessionTab(context, isDark);
          } else {
            return _buildProgressTab(context, isDark);
          }
        }),
      );
    });
  }

  // --- Landing Tab 1: New Session Setup ---
  Widget _buildNewSessionTab(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Resume Last Session Card
          Obx(() {
            final lastSession = controller.storage.getLastHifzSession();
            if (lastSession == null) return const SizedBox();
            
            final chId = lastSession['chapterId'] as int? ?? 1;
            final chapter = controller.chapters.firstWhereOrNull((c) => c.id == chId);
            final chName = chapter != null ? chapter.nameArabic : 'البقرة';
            
            return GestureDetector(
              onTap: () {
                controller.loadLastSession();
                controller.startHifz();
              },
              child: Card(
                color: AppColors.primary.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppColors.primary.withOpacity(0.2)),
                ),
                margin: const EdgeInsets.only(bottom: 20),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.primary,
                        child: const Icon(Icons.refresh_rounded, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'متابعة الحفظ الأخير',
                              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'سورة $chName (الآيات ${lastSession['startAyah']} - ${lastSession['endAyah']})',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            );
          }),

          const Text(
            'السورة ونطاق الآيات',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          const SizedBox(height: 12),

          // Surah selection card
          Obx(() {
            final chapter = controller.selectedChapter.value;
            if (chapter == null) return const SizedBox();
            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.15)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _showSurahSearchSheet(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AppColors.primary.withOpacity(0.1),
                                radius: 24,
                                child: Text(
                                  '${chapter.id}',
                                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'سورة ${chapter.nameArabic}',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'UthmanicHafs'),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${chapter.nameSimple} • ${chapter.revelationPlace == 'Meccan' ? 'مكية' : 'مدنية'} • ${chapter.versesCount} آية',
                                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Obx(() {
                        if (controller.isDownloadingSurah.value) {
                          final pct = (controller.downloadProgress.value * 100).toInt();
                          return SizedBox(
                            width: 36,
                            height: 36,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: controller.downloadProgress.value > 0 ? controller.downloadProgress.value : null,
                                  strokeWidth: 3.0,
                                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                                ),
                                Text(
                                  '$pct%',
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        }

                        final isDownloaded = controller.isSurahDownloaded();
                        return IconButton(
                          icon: Icon(
                            isDownloaded ? Icons.cloud_done_rounded : Icons.cloud_download_rounded,
                            color: isDownloaded ? Colors.green : Colors.grey,
                            size: 26,
                          ),
                          onPressed: () => controller.downloadSurah(),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),

          // Visual Ayah Range Picker
          Obx(() => _buildAyahRangePicker(context, isDark)),
          const SizedBox(height: 24),

          const Text(
            'خيارات التكرار والتحفيظ',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          const SizedBox(height: 12),

          // Repetitions and delay block
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Obx(() {
              return Column(
                children: [
                  // Verse Repetitions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('تكرار كل آية', style: TextStyle(fontWeight: FontWeight.w500)),
                      DropdownButton<int>(
                        value: controller.verseRepetitions.value,
                        dropdownColor: isDark ? AppColors.cardDark : Colors.white,
                        items: List.generate(20, (i) => i + 1).map((e) {
                          return DropdownMenuItem(value: e, child: Text('$e مرات'));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) controller.verseRepetitions.value = val;
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  // Range Repetitions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('تكرار النطاق كاملاً', style: TextStyle(fontWeight: FontWeight.w500)),
                      DropdownButton<int>(
                        value: controller.rangeRepetitions.value,
                        dropdownColor: isDark ? AppColors.cardDark : Colors.white,
                        items: List.generate(10, (i) => i + 1).map((e) {
                          return DropdownMenuItem(value: e, child: Text('$e مرات'));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) controller.rangeRepetitions.value = val;
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  // Delay seconds
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('صمت بين الآيات (للتكرار)', style: TextStyle(fontWeight: FontWeight.w500)),
                          Text('مهلة للتلاوة والاستذكار بنفسك', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        ],
                      ),
                      DropdownButton<int>(
                        value: controller.delaySeconds.value,
                        dropdownColor: isDark ? AppColors.cardDark : Colors.white,
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('بدون صمت')),
                          DropdownMenuItem(value: 1, child: Text('ثانية واحدة')),
                          DropdownMenuItem(value: 2, child: Text('ثانيتين')),
                          DropdownMenuItem(value: 3, child: Text('٣ ثوانٍ')),
                          DropdownMenuItem(value: 5, child: Text('٥ ثوانٍ')),
                          DropdownMenuItem(value: 8, child: Text('٨ ثوانٍ')),
                          DropdownMenuItem(value: 10, child: Text('١٠ ثوانٍ')),
                          DropdownMenuItem(value: 15, child: Text('١٥ ثانية')),
                        ],
                        onChanged: (val) {
                          if (val != null) controller.delaySeconds.value = val;
                        },
                      ),
                    ],
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 24),

          const Text(
            'إعدادات التلاوة والترجمة',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          const SizedBox(height: 12),

          // Reciter & translation block
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Obx(() {
              return Column(
                children: [
                  // Reciter dropdown
                  DropdownButtonFormField<int>(
                    value: controller.selectedReciterId.value,
                    dropdownColor: isDark ? AppColors.cardDark : Colors.white,
                    decoration: const InputDecoration(
                      labelText: 'القارئ المختار للتلاوة',
                      border: InputBorder.none,
                    ),
                    items: const [
                      DropdownMenuItem(value: 7, child: Text('مشاري العفاسي')),
                      DropdownMenuItem(value: 6, child: Text('محمود الحصري')),
                      DropdownMenuItem(value: 2, child: Text('عبد الباسط عبد الصمد')),
                      DropdownMenuItem(value: 9, child: Text('محمد صديق المنشاوي')),
                      DropdownMenuItem(value: 10, child: Text('أيمن سويد (معلّم)')),
                      DropdownMenuItem(value: 3, child: Text('عبد الرحمن السديس')),
                      DropdownMenuItem(value: 17, child: Text('ماهر المعيقلي')),
                      DropdownMenuItem(value: 15, child: Text('علي الحذيفي')),
                      DropdownMenuItem(value: 20, child: Text('سعود الشريم')),
                      DropdownMenuItem(value: 22, child: Text('أبو بكر الشاطري')),
                      DropdownMenuItem(value: 23, child: Text('أحمد العجمي')),
                      DropdownMenuItem(value: 11, child: Text('عبد الله بصفر')),
                      DropdownMenuItem(value: 14, child: Text('هاني الرفاعي')),
                      DropdownMenuItem(value: 16, child: Text('إبراهيم الأخضر')),
                      DropdownMenuItem(value: 18, child: Text('محمد أيوب')),
                      DropdownMenuItem(value: 19, child: Text('محمد جبريل')),
                      DropdownMenuItem(value: 21, child: Text('شهريار پرهيزگار')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        controller.updateReciter(val);
                      }
                    },
                  ),
                  if (controller.selectedReciterId.value == 6 || controller.selectedReciterId.value == 2 || controller.selectedReciterId.value == 9) ...[
                    const Divider(height: 24),
                    DropdownButtonFormField<String>(
                      value: controller.selectedStyle.value == 'teacher' && controller.selectedReciterId.value != 6 
                          ? 'murattal' 
                          : controller.selectedStyle.value,
                      dropdownColor: isDark ? AppColors.cardDark : Colors.white,
                      decoration: const InputDecoration(
                        labelText: 'رواية/أسلوب التلاوة',
                        border: InputBorder.none,
                      ),
                      items: controller.selectedReciterId.value == 6
                          ? const [
                              DropdownMenuItem(value: 'murattal', child: Text('مرتّل')),
                              DropdownMenuItem(value: 'mujawwad', child: Text('مجوّد')),
                              DropdownMenuItem(value: 'teacher', child: Text('معلّم')),
                            ]
                          : const [
                              DropdownMenuItem(value: 'murattal', child: Text('مرتّل')),
                              DropdownMenuItem(value: 'mujawwad', child: Text('مجوّد')),
                            ],
                      onChanged: (val) {
                        if (val != null) {
                          controller.updateStyle(val);
                        }
                      },
                    ),
                  ],
                  const Divider(height: 24),
                  // Translation Switch
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('عرض الترجمة المرافقة', style: TextStyle(fontWeight: FontWeight.w500)),
                      Switch(
                        value: controller.showTranslation.value,
                        activeColor: AppColors.primary,
                        onChanged: (val) {
                          controller.showTranslation.value = val;
                        },
                      ),
                    ],
                  ),
                  if (controller.showTranslation.value) ...[
                    const Divider(height: 24),
                    DropdownButtonFormField<int>(
                      value: controller.selectedTranslationIndex.value,
                      dropdownColor: isDark ? AppColors.cardDark : Colors.white,
                      decoration: const InputDecoration(
                        labelText: 'اختر لغة الترجمة / التفسير',
                        border: InputBorder.none,
                      ),
                      items: controller.availableTranslations.map((item) {
                        final idx = controller.availableTranslations.indexOf(item);
                        return DropdownMenuItem(
                          value: idx,
                          child: Text(item.name),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          controller.selectedTranslationIndex.value = val;
                        }
                      },
                    ),
                  ],
                ],
              );
            }),
          ),
          const SizedBox(height: 32),

          // Start Session Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 4,
            ),
            icon: const Icon(Icons.play_arrow_rounded, size: 28),
            label: const Text(
              'ابدأ مساحة الحفظ والتركيز',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            onPressed: () => controller.startHifz(),
          ),
        ],
      ),
    );
  }

  // --- Visual range picker card ---
  Widget _buildAyahRangePicker(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Start Ayah picker
              Expanded(
                child: Column(
                  children: [
                    const Text('بداية الآية', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: AppColors.primary),
                          onPressed: () => controller.decrementStartAyah(),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.secondaryDark : AppColors.secondaryLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${controller.startAyah.value}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                          onPressed: () => controller.incrementStartAyah(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // End Ayah picker
              Expanded(
                child: Column(
                  children: [
                    const Text('نهاية الآية', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: AppColors.primary),
                          onPressed: () => controller.decrementEndAyah(),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.secondaryDark : AppColors.secondaryLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${controller.endAyah.value}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                          onPressed: () => controller.incrementEndAyah(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          Obx(() {
            final startText = controller.getStartAyahText();
            final endText = controller.getEndAyahText();
            if (startText.isEmpty && endText.isEmpty) return const SizedBox();
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(height: 24),
                if (startText.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'البداية: الآية ${controller.startAyah.value}',
                          style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          startText,
                          style: const TextStyle(fontSize: 15, fontFamily: 'UthmanicHafs', height: 1.6),
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                        ),
                      ),
                    ],
                  ),
                ],
                if (endText.isNotEmpty && controller.startAyah.value != controller.endAyah.value) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'النهاية: الآية ${controller.endAyah.value}',
                          style: const TextStyle(fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          endText,
                          style: const TextStyle(fontSize: 15, fontFamily: 'UthmanicHafs', height: 1.6),
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }

  // --- Landing Tab 2: Progress & History dashboard ---
  Widget _buildProgressTab(BuildContext context, bool isDark) {
    final totalSessions = controller.hifzHistoryList.length;
    final completedSurahs = controller.hifzHistoryList.map((e) => e['chapterId']).toSet().length;
    final lastActiveDate = controller.hifzHistoryList.isNotEmpty
        ? _formatDate(controller.hifzHistoryList.first['date'] as String)
        : 'لا يوجد';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  'جلسات الحفظ',
                  '$totalSessions',
                  Icons.history_toggle_off_rounded,
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  context,
                  'السور المحفوظة',
                  '$completedSurahs',
                  Icons.library_books_rounded,
                  AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatCard(
            context,
            'آخر جلسة حفظ',
            lastActiveDate,
            Icons.calendar_today_rounded,
            Colors.teal,
            horizontal: true,
          ),
          const SizedBox(height: 24),
          const Text(
            'سجل التقدم والتوثيق',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          if (controller.hifzHistoryList.isEmpty)
            Card(
              color: isDark ? AppColors.cardDark : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                child: Column(
                  children: [
                    Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[500]),
                    const SizedBox(height: 16),
                    const Text(
                      'لا توجد جلسات حفظ مسجلة بعد',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ابدأ جلسة حفظ جديدة وقم بحفظ تقدمك لتظهر إحصائياتك هنا.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: controller.hifzHistoryList.length,
              itemBuilder: (context, index) {
                final entry = controller.hifzHistoryList[index];
                final rating = entry['rating'] as int? ?? 5;
                final dateStr = _formatDate(entry['date'] as String);
                return Card(
                  color: isDark ? AppColors.cardDark : Colors.white,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(
                      'سورة ${entry['chapterName']} (الآيات ${entry['startAyah']} - ${entry['endAyah']})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('التاريخ: $dateStr • القارئ: ${entry['reciterName']}'),
                        if (entry['notes'] != null && (entry['notes'] as String).isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('ملاحظة: ${entry['notes']}', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: List.generate(5, (starIdx) {
                            return Icon(
                              starIdx < rating ? Icons.star_rounded : Icons.star_border_rounded,
                              color: AppColors.accent,
                              size: 16,
                            );
                          }),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () {
                        controller.deleteHistoryItem(index);
                      },
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color, {
    bool horizontal = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: isDark ? AppColors.cardDark : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      return '${dateTime.year}/${dateTime.month}/${dateTime.day}';
    } catch (_) {
      return isoString;
    }
  }

  // --- Active Memorization Workspace ---
  Widget _buildWorkspace(BuildContext context, bool isDark) {
    final audio = controller.audioService;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      appBar: AppBar(
        title: const Text('مساحة الحفظ والتركيز', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => controller.stopHifz(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent, size: 28),
            onPressed: () => _showFinishDialog(context),
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
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

        return Column(
          children: [
            // Silence Countdown Bar (Visual aid when repeating or waiting)
            if (audio.isWaitingDelay.value)
              Container(
                color: AppColors.accent.withOpacity(0.9),
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.record_voice_over_rounded, color: Color(0xFF1A0F00)),
                    const SizedBox(width: 12),
                    Text(
                      'صمت للتلاوة... كرر الآية الآن (المتبقي: ${audio.delayCountdown.value} ثانية)',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A0F00), fontSize: 14),
                    ),
                  ],
                ),
              ),

            // Centered active ayah card (single active verse view)
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: () {
                    final verse = currentVerse;
                    if (verse == null) {
                      return const Center(
                        child: Text(
                          'جاري تهيئة مساحة الحفظ...',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      );
                    }
                    final parts = verse.verseKey.split(':');
                    final surahNum = int.tryParse(parts[0]) ?? 1;
                    final ayahNum = int.tryParse(parts.length > 1 ? parts[1] : '1') ?? 1;
                    final isMasked = controller.maskText.value && !controller.revealedVerseIds.contains(verse.id);

                    return Card(
                      color: isDark ? AppColors.cardDark : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(
                          color: AppColors.primary.withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    'الآية $ayahNum',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (controller.maskText.value)
                                  IconButton(
                                    icon: Icon(
                                      isMasked ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () => controller.toggleVerseReveal(verse.id),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            InkWell(
                              onTap: () {
                                if (controller.maskText.value) {
                                  controller.toggleVerseReveal(verse.id);
                                }
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: ImageFiltered(
                                  imageFilter: isMasked
                                      ? ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0)
                                      : ImageFilter.blur(sigmaX: 0.0, sigmaY: 0.0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                    alignment: Alignment.center,
                                    child: Directionality(
                                      textDirection: TextDirection.rtl,
                                      child: GetSingleAyah(
                                        surahNumber: surahNum,
                                        ayahNumber: ayahNum,
                                        isDark: isDark,
                                        fontSize: controller.arabicFontSize.value,
                                        isBold: false,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (controller.showTranslation.value && verse.translationText.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              const Divider(),
                              const SizedBox(height: 20),
                              Text(
                                verse.translationText,
                                style: TextStyle(
                                  fontSize: controller.translationFontSize.value,
                                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }(),
                ),
              ),
            ),

            // bottom control bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4)),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Verse repeats indicator
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.repeat_one_rounded, size: 18, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              'الآية: ${audio.verseRepeat.value} / ${controller.verseRepetitions.value}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 20, color: Colors.grey[300]),
                      // Range loops indicator
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.repeat_rounded, size: 18, color: AppColors.accent),
                            const SizedBox(width: 8),
                            Text(
                              'النطاق: ${audio.rangeRepeat.value} / ${controller.rangeRepetitions.value}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Size Settings trigger
                      IconButton(
                        icon: const Icon(Icons.format_size_rounded),
                        onPressed: () => _showTextSizeSheet(context),
                      ),
                      // Skip Prev Ayah
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded, size: 32),
                        onPressed: audio.canGoPrevHifz ? () => audio.playPrevHifz() : null,
                      ),
                      // Play/Pause circular control
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.primary,
                        child: IconButton(
                          icon: Icon(
                            audio.isPlaying.value ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                          onPressed: audio.isPlaying.value ? () => audio.pause() : () => audio.resume(),
                        ),
                      ),
                      // Skip Next Ayah
                      IconButton(
                        icon: const Icon(Icons.skip_previous_rounded, size: 32),
                        onPressed: audio.canGoNextHifz ? () => audio.playNextHifz() : null,
                      ),
                      // Masking/Blur Switch
                      IconButton(
                        icon: Icon(
                          controller.maskText.value ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: controller.maskText.value ? AppColors.accent : Colors.grey,
                        ),
                        onPressed: () {
                          controller.maskText.value = !controller.maskText.value;
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  // --- Bottom Sheets & Dialogs Helpers ---

  // 1. Searchable Surah Sheet
  void _showSurahSearchSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchController = TextEditingController();
    RxList<Chapter> filteredChapters = RxList<Chapter>(controller.chapters);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: isDark ? AppColors.bgDark : AppColors.bgLight,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Text(
                'اختر السورة الكريمة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: searchController,
                onChanged: (val) {
                  filteredChapters.assignAll(controller.chapters.where((c) =>
                      c.nameArabic.contains(val) ||
                      c.nameSimple.toLowerCase().contains(val.toLowerCase())));
                },
                decoration: InputDecoration(
                  hintText: 'ابحث باسم السورة...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: isDark ? AppColors.cardDark : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Obx(() {
                  if (filteredChapters.isEmpty) {
                    return const Center(child: Text('لا توجد نتائج بحث'));
                  }
                  return ListView.builder(
                    itemCount: filteredChapters.length,
                    itemBuilder: (context, index) {
                      final chapter = filteredChapters[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          child: Text('${chapter.id}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ),
                        title: Text('سورة ${chapter.nameSimple} (${chapter.nameArabic})'),
                        subtitle: Text('عدد الآيات: ${chapter.versesCount} • نزولها: ${chapter.revelationPlace == 'Meccan' ? 'مكي' : 'مدني'}'),
                        onTap: () {
                          controller.onSurahChanged(chapter);
                          Navigator.pop(context);
                        },
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  // 2. Adjust Font Sizes Sheet
  void _showTextSizeSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Obx(() {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'تعديل حجم الخط',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                const SizedBox(height: 24),
                Text('حجم الخط العربي: ${controller.arabicFontSize.value.toInt()}'),
                Slider(
                  min: 20.0,
                  max: 48.0,
                  value: controller.arabicFontSize.value,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    controller.updateArabicFontSize(val);
                  },
                ),
                const SizedBox(height: 16),
                Text('حجم خط الترجمة: ${controller.translationFontSize.value.toInt()}'),
                Slider(
                  min: 12.0,
                  max: 28.0,
                  value: controller.translationFontSize.value,
                  activeColor: AppColors.accent,
                  onChanged: (val) {
                    controller.updateTranslationFontSize(val);
                  },
                ),
              ],
            );
          }),
        );
      },
    );
  }

  // 3. Rate & Save Session Dialog
  void _showFinishDialog(BuildContext context) {
    int selectedRating = 5;
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: isDark ? AppColors.cardDark : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                'حفظ تقدم الحفظ الكريّم',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('كيف تقيّم جودة حفظك وتسميعك في هذه الجلسة؟', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < selectedRating ? Icons.star_rounded : Icons.star_border_rounded,
                            color: AppColors.accent,
                            size: 36,
                          ),
                          onPressed: () {
                            setState(() {
                              selectedRating = index + 1;
                            });
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'ملاحظات وتنبيهات الحفظ (اختياري)',
                        labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: AppColors.primary),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('حفظ وإغلاق', style: TextStyle(color: Colors.white)),
                  onPressed: () {
                    controller.finishAndSaveSession(selectedRating, notesController.text);
                    Navigator.pop(context);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
