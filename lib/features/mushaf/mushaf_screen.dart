import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
    final isDark = storage.isDarkMode();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'المصحف الشريف',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
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
                hintText: 'ابحث عن السورة...',
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                filled: true,
                fillColor: isDark ? AppColors.secondaryDark : Colors.grey[200],
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
                          child: const Text('إعادة المحاولة', style: TextStyle(color: Colors.white)),
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
                  color: isDark ? Colors.grey[900] : Colors.grey[300],
                ),
                itemBuilder: (context, index) {
                  final chapter = controller.filteredChapters[index];
                  final reciterId = storage.getSelectedReciterId();
                  
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
                    title: Row(
                      children: [
                        Text(
                          chapter.nameSimple,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${chapter.versesCount} آيات)',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      chapter.translatedName,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          chapter.nameArabic,
                          style: const TextStyle(
                            fontFamily: 'UthmanicHafs',
                            fontSize: 20,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Download progress / trigger button
                        Obx(() {
                          final isDownloaded = controller.isChapterDownloaded(chapter.id);
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
