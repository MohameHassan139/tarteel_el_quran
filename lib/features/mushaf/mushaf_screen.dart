import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quran_library/quran_library.dart';
import '../../routes/app_routes.dart';
import '../../core/download_service.dart';
import '../../core/storage_service.dart';
import 'mushaf_controller.dart';
import '../../core/app_colors.dart';

class MushafScreen extends GetView<MushafController> {
  const MushafScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = Get.find<StorageService>();
    final downloadService = Get.find<DownloadService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isAr = Get.locale?.languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'holy_quran'.tr,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: controller.searchController,
              decoration: InputDecoration(
                hintText: 'search_surah'.tr,
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                filled: true,
                fillColor: isDark ? AppColors.secondaryDark : AppColors.secondaryLight,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                );
              }

              if (controller.errorMessage.isNotEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          controller.errorMessage.value,
                          style: const TextStyle(color: Colors.grey, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () => controller.loadChapters(),
                          child: Text('retry'.tr, style: const TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                itemCount: controller.filteredChapters.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: isDark ? AppColors.secondaryDark : AppColors.secondaryLight,
                ),
                itemBuilder: (context, index) {
                  final chapter = controller.filteredChapters[index];
                  final reciterId = storage.getSelectedReciterId();
                  
                  // Retrieve corresponding surah details from quran_library
                  final quranLibrarySurah = QuranCtrl.instance.surahsList.firstWhereOrNull((s) => s.number == chapter.id);

                  final displayName = isAr
                      ? (quranLibrarySurah?.name ?? chapter.nameArabic)
                      : (quranLibrarySurah?.englishName ?? chapter.nameSimple);

                  final displaySubtitle = isAr
                      ? "${quranLibrarySurah?.revelationType == 'Meccan' ? 'meccan'.tr : 'medinan'.tr} • ${'ayahs_count_param'.trParams({'count': '${quranLibrarySurah?.ayahsNumber ?? chapter.versesCount}'})}"
                      : "${quranLibrarySurah?.englishNameTranslation ?? chapter.translatedName} • ${quranLibrarySurah?.revelationType ?? chapter.revelationPlace} • ${'verses_count_param'.trParams({'count': '${quranLibrarySurah?.ayahsNumber ?? chapter.versesCount}'})}";

                  return ListTile(
                    onTap: () {
                      Get.toNamed(AppRoutes.MUSHAF_VIEW, arguments: chapter);
                    },
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${chapter.id}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      displaySubtitle,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Show Arabic name on the trailing side only if layout language is not Arabic
                        if (!isAr) ...[
                          Flexible(
                            child: Text(
                              quranLibrarySurah?.name ?? chapter.nameArabic,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'UthmanicHafs',
                                fontSize: 20,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        // Download progress / trigger button
                        Obx(() {
                          final isDownloaded = controller.isChapterDownloaded(
                            chapter,
                          );
                          final progress = downloadService.getProgress(reciterId, chapter.id);

                          if (progress != null) {
                            return SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 3,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                              ),
                            );
                          }
                          if (isDownloaded) {
                            return const SizedBox.shrink();
                          }

                          return IconButton(
                            icon: const Icon(
                              Icons.download_for_offline_outlined,
                              color: Colors.grey,
                            ),
                            onPressed: () => controller.handleDownload(chapter),
                          );
                        }),
                      ],
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
