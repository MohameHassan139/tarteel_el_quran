import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../shared/widgets/bottom_player.dart';
import 'audio_hub_controller.dart';
import '../../core/app_colors.dart';
import 'package:quran_library/quran_library.dart';

class AudioHubScreen extends GetView<AudioHubController> {
  const AudioHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('listening_library_title'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                      final reciters = controller.mp3Reciters;
                      final selectedReciter = controller.selectedReciter.value;
                      final selectedMoshaf = controller.selectedMoshaf.value;
                      final isBulk = controller.isBulkDownloading.value;
                      final progressStr = controller.bulkProgressString;

                      if (reciters.isEmpty ||
                          selectedReciter == null ||
                          selectedMoshaf == null) {
                        return const SizedBox(
                          height: 100,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Line 1: Reciter dropdown
                          Row(
                            children: [
                              Text(
                                'reciter_label'.tr,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButton<int>(
                                  isExpanded: true,
                                  value: selectedReciter.id,
                                  dropdownColor: isDark
                                      ? AppColors.cardDark
                                      : Colors.white,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'system-ui',
                                  ),
                                  items: reciters.map((r) {
                                    return DropdownMenuItem<int>(
                                      value: r.id,
                                      child: Text(
                                        r.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null)
                                      controller.updateReciter(val);
                                  },
                                ),
                              ),
                            ],
                          ),

                          // Line 2: Moshaf dropdown
                          if (selectedReciter.moshafs.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  'narration_label'.tr,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButton<int>(
                                    isExpanded: true,
                                    value:
                                        selectedReciter.moshafs.any(
                                          (m) => m.id == selectedMoshaf.id,
                                        )
                                        ? selectedMoshaf.id
                                        : selectedReciter.moshafs.first.id,
                                    dropdownColor: isDark
                                        ? AppColors.cardDark
                                        : Colors.white,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    items: selectedReciter.moshafs.map((m) {
                                      return DropdownMenuItem<int>(
                                        value: m.id,
                                        child: Text(
                                          m.name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null)
                                        controller.updateMoshaf(val);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
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
                                        label: Text('stop_bulk_download'.trParams({'progress': progressStr})),
                                        onPressed: () => controller.cancelBulkDownload(),
                                      )
                                    : ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                        icon: const Icon(Icons.download, color: Colors.white),
                                        label: Text('download_all'.tr, style: const TextStyle(color: Colors.white)),
                                        onPressed: controller.chapters.isEmpty ? null : () => controller.startBulkDownload(),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red[900]),
                                icon: const Icon(Icons.delete_sweep, color: Colors.white),
                                label: Text('delete_all'.tr, style: const TextStyle(color: Colors.white)),
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
                    hintText: 'search_surah_listen'.tr,
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

                  // If offline AND no downloaded surahs at all — show full error screen
                  if (controller.errorMessage.isNotEmpty &&
                      controller.filteredChapters.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(controller.errorMessage.value,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary),
                              onPressed: () => controller.loadMp3QuranData(),
                              child: Text('retry'.tr,
                                  style: const TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      // Slim offline banner when there's an error but downloaded surahs exist
                      if (controller.errorMessage.isNotEmpty)
                        Container(
                          width: double.infinity,
                          color: Colors.orange[800],
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.wifi_off,
                                  color: Colors.white, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'offline_banner'.tr,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13),
                                ),
                              ),
                              TextButton(
                                onPressed: () => controller.loadMp3QuranData(),
                                child: Text('retry'.tr,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: ListView.separated(

                    itemCount: controller.filteredChapters.length,
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 110), // Room for bottom player
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: isDark ? AppColors.secondaryDark : AppColors.secondaryLight,
                    ),
                    itemBuilder: (context, index) {
                      final chapter = controller.filteredChapters[index];
                      final isAr = Get.locale?.languageCode == 'ar';

                      return Obx(() {
                        final reciter = controller.selectedReciter.value;
                        final moshaf = controller.selectedMoshaf.value;
                        final isDownloaded = controller.isChapterDownloaded(chapter);
                        final isCurrentBulk =
                            controller.isBulkDownloading.value &&
                            controller.bulkDownloadId.value == chapter.id;
                        final isAvailable = controller.isChapterAvailable(chapter);

                        // Read directly from the reactive RxMap so Obx tracks it
                        final double? progress =
                            (reciter != null && moshaf != null)
                            ? controller
                                  .downloadService
                                  .activeProgress['mp3quran_${reciter.id}_${moshaf.id}_${chapter.id}']
                            : null;

                        // Retrieve corresponding surah details from quran_library
                        final quranLibrarySurah = QuranCtrl.instance.surahsList.firstWhereOrNull((s) => s.number == chapter.id);

                        final displayName = isAr
                            ? (quranLibrarySurah?.name ?? chapter.nameArabic)
                            : (quranLibrarySurah?.englishName ?? chapter.nameSimple);

                        final displaySubtitle = isAr
                            ? "${quranLibrarySurah?.revelationType == 'Meccan' ? 'meccan'.tr : 'medinan'.tr} • ${'ayahs_count_param'.trParams({'count': '${quranLibrarySurah?.ayahsNumber ?? chapter.versesCount}'})}"
                            : "${quranLibrarySurah?.englishNameTranslation ?? chapter.translatedName} • ${quranLibrarySurah?.revelationType ?? chapter.revelationPlace} • ${'verses_count_param'.trParams({'count': '${quranLibrarySurah?.ayahsNumber ?? chapter.versesCount}'})}";

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
                          title: Text(
                            displayName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isAvailable ? null : Colors.grey[600],
                            ),
                          ),
                          subtitle: Text(
                            displaySubtitle,
                            style: TextStyle(
                              fontSize: 13,
                              color: isAvailable ? AppColors.primary : Colors.grey[500],
                            ),
                          ),
                          trailing: SizedBox(
                            width: 110,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (!isAvailable)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'unavailable'.tr,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                else ...[
                                  // Play button
                                  IconButton(
                                    icon: const Icon(
                                      Icons.play_circle_fill,
                                      color: AppColors.primary,
                                      size: 30,
                                    ),
                                    onPressed: () => controller.playSurah(chapter),
                                  ),
                                  // Download / progress indicator
                                  if (progress != null || isCurrentBulk)
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        value: progress,
                                        strokeWidth: 3,
                                        valueColor: const AlwaysStoppedAnimation<Color>(
                                          AppColors.primary,
                                        ),
                                      ),
                                    )
                                  else if (!isDownloaded)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.download_for_offline_outlined,
                                        color: Colors.grey,
                                      ),
                                      onPressed: () => controller.handleDownload(chapter),
                                    )
                                  else
                                    const SizedBox(width: 24),
                                ],
                              ],
                            ),
                          ),
                        );
                      });
                    },
                  ), // ListView.separated
                ), // Expanded
              ],
            ); // Column
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
