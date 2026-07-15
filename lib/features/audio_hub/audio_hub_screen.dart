import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/storage_service.dart';
import '../../core/download_service.dart';
import '../shared/widgets/bottom_player.dart';
import 'audio_hub_controller.dart';
import '../../core/app_colors.dart';

class AudioHubScreen extends GetView<AudioHubController> {
  const AudioHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = Get.find<StorageService>();
    final downloadService = Get.find<DownloadService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('مكتبة الاستماع والتحميل', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Reciter Info & Bulk Actions
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  color: isDark ? AppColors.cardDark : AppColors.cardLight,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Obx(() {
                      final baseReciterId = storage.getSelectedReciterId();
                      final isBulk = controller.isBulkDownloading.value;
                      final progressStr = controller.bulkProgressString;

                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'القارئ والأسلوب:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  DropdownButton<int>(
                                    value: baseReciterId,
                                    dropdownColor: isDark ? AppColors.cardDark : Colors.white,
                                    style: TextStyle(
                                      color: isDark ? Colors.white : Colors.black87,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'system-ui',
                                    ),
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
                                  if (baseReciterId != 7) ...[
                                    const SizedBox(width: 8),
                                    DropdownButton<String>(
                                      value: storage.getSelectedStyle(),
                                      dropdownColor: isDark ? AppColors.cardDark : Colors.white,
                                      style: TextStyle(
                                        color: isDark ? Colors.white : Colors.black87,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      items: baseReciterId == 6
                                          ? const [
                                              DropdownMenuItem(value: 'murattal', child: Text('مرتّل')),
                                              DropdownMenuItem(value: 'mujawwad', child: Text('معلّم')),
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
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: isBulk
                                    ? ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[850]),
                                        icon: const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        ),
                                        label: Text('إيقاف ($progressStr)'),
                                        onPressed: () => controller.cancelBulkDownload(),
                                      )
                                    : ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                        icon: const Icon(Icons.download, color: Colors.white),
                                        label: const Text('تحميل الكل', style: TextStyle(color: Colors.white)),
                                        onPressed: controller.chapters.isEmpty ? null : () => controller.startBulkDownload(),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red[900]),
                                icon: const Icon(Icons.delete_sweep, color: Colors.white),
                                label: const Text('حذف الكل', style: TextStyle(color: Colors.white)),
                                onPressed: controller.chapters.isEmpty || isBulk ? null : () => controller.deleteAllAudio(),
                              ),
                            ],
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),

              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: controller.searchController,
                  decoration: InputDecoration(
                    hintText: 'ابحث عن السورة للاستماع إليها...',
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
                            Text(controller.errorMessage.value, style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
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
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 110), // Room for bottom player
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: isDark ? AppColors.secondaryDark : AppColors.secondaryLight,
                    ),
                    itemBuilder: (context, index) {
                      final chapter = controller.filteredChapters[index];
                      final reciterId = storage.getEffectiveReciterId();
                      
                      return Obx(() {
                        final isDownloaded = controller.isChapterDownloaded(chapter.id);
                        final isCurrentBulk = controller.isBulkDownloading.value && controller.bulkDownloadId.value == chapter.id;

                        return ListTile(
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
                                ),
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(chapter.nameSimple, style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Text(
                                '(${chapter.versesCount} آيات)',
                                style: TextStyle(color: Colors.grey[500], fontSize: 12),
                              ),
                            ],
                          ),
                          subtitle: Text(chapter.nameArabic, style: const TextStyle(fontFamily: 'UthmanicHafs', fontSize: 16, color: AppColors.primary)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Listen Play button
                              IconButton(
                                icon: const Icon(Icons.play_circle_fill, color: AppColors.primary, size: 30),
                                onPressed: () => controller.playSurah(chapter),
                              ),
                              const SizedBox(width: 8),
                              // Individual Download Action
                              Obx(() {
                                final progress = downloadService.getProgress(reciterId, chapter.id);

                                if (progress != null || isCurrentBulk) {
                                  return SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      value: progress,
                                      strokeWidth: 3,
                                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
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
                      });
                    },
                  );
                }),
              ),
            ],
          ),

          // Persistent bottom player overlay
          const Align(
            alignment: Alignment.bottomCenter,
            child: BottomPlayer(),
          ),
        ],
      ),
    );
  }
}
