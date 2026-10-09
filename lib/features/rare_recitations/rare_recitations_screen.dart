import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/app_colors.dart';
import '../shared/widgets/bottom_player.dart';
import 'rare_recitation_model.dart';
import 'rare_recitations_controller.dart';
import 'rare_recitations_data.dart';

class RareRecitationsScreen extends GetView<RareRecitationsController> {
  const RareRecitationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      appBar: AppBar(
        title: Text(
          'rare_recitations_title'.tr,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          Obx(() {
            final isArchive = controller.isArchiveSearchMode.value;
            return IconButton(
              icon: Icon(
                isArchive ? Icons.library_music_rounded : Icons.cloud_sync_rounded,
                color: isArchive ? Colors.amber : null,
              ),
              tooltip: isArchive ? 'curated_library'.tr : 'archive_search_tab'.tr,
              onPressed: () => controller.toggleArchiveMode(!isArchive),
            );
          }),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Top Hero Banner
                _buildHeroBanner(context, isDark),

                // Search Bar & Filter Controls
                _buildSearchAndFilters(context, isDark),

                // Reciters Horizontal Chips (if not in archive mode)
                Obx(() {
                  if (controller.isArchiveSearchMode.value) {
                    return const SizedBox.shrink();
                  }
                  return _buildReciterChips(context, isDark);
                }),

                // Recitations List
                Expanded(
                  child: Obx(() {
                    if (controller.isArchiveSearchMode.value) {
                      return _buildArchiveResultsList(context, isDark);
                    }
                    return _buildCuratedList(context, isDark);
                  }),
                ),

                // Spacing for BottomPlayer
                const SizedBox(height: 70),
              ],
            ),

            // Persistent Floating Bottom Player
            const Align(
              alignment: Alignment.bottomCenter,
              child: BottomPlayer(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1F2937), const Color(0xFF374151)]
              : [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.radio_rounded,
              color: Colors.amber,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'golden_era_reciters'.tr,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'rare_recitations_subtitle'.tr,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[300] : Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller.searchController,
              decoration: InputDecoration(
                hintText: controller.isArchiveSearchMode.value
                    ? 'search_archive_hint'.tr
                    : 'search_rare_hint'.tr,
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    controller.searchController.clear();
                    if (!controller.isArchiveSearchMode.value) {
                      controller.filterRecitations();
                    }
                  },
                ),
                filled: true,
                fillColor: isDark ? AppColors.cardDark : AppColors.cardLight,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (val) {
                if (controller.isArchiveSearchMode.value) {
                  controller.searchArchive(val);
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          // Downloaded filter toggle
          Obx(() {
            final isSelected = controller.onlyDownloaded.value;
            return FilterChip(
              avatar: Icon(
                isSelected ? Icons.check_circle : Icons.download_done_rounded,
                size: 18,
                color: isSelected ? Colors.white : AppColors.primary,
              ),
              label: Text(
                'downloaded_only'.tr,
                style: TextStyle(
                  color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              selected: isSelected,
              selectedColor: AppColors.primary,
              backgroundColor: isDark ? AppColors.cardDark : AppColors.cardLight,
              onSelected: (_) => controller.toggleOnlyDownloaded(),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildReciterChips(BuildContext context, bool isDark) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        scrollDirection: Axis.horizontal,
        itemCount: RareRecitationsData.legendaryReciters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (ctx, idx) {
          final reciter = RareRecitationsData.legendaryReciters[idx];
          return Obx(() {
            final isSelected = controller.selectedReciterFilter.value == reciter;
            return ChoiceChip(
              label: Text(
                reciter,
                style: TextStyle(
                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
              selected: isSelected,
              selectedColor: Colors.amber[800] ?? AppColors.primary,
              backgroundColor: isDark ? AppColors.cardDark : AppColors.cardLight,
              onSelected: (_) => controller.setReciterFilter(reciter),
            );
          });
        },
      ),
    );
  }

  Widget _buildCuratedList(BuildContext context, bool isDark) {
    final list = controller.filteredRecitations;

    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'no_rare_found'.tr,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: list.length,
      itemBuilder: (ctx, idx) {
        final item = list[idx];
        return _buildRecitationCard(context, item, isDark);
      },
    );
  }

  Widget _buildArchiveResultsList(BuildContext context, bool isDark) {
    if (controller.isSearchingArchive.value) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final list = controller.archiveResults;
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.travel_explore_rounded, size: 64, color: Colors.amber[400]),
              const SizedBox(height: 16),
              Text(
                'search_archive_prompt'.tr,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: list.length,
      itemBuilder: (ctx, idx) {
        final item = list[idx];
        return _buildRecitationCard(context, item, isDark);
      },
    );
  }

  Widget _buildRecitationCard(BuildContext context, RareRecitation item, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? AppColors.cardDark : AppColors.cardLight,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => controller.playRecitation(item),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Play/Pause circular icon with indicator
              Obx(() {
                final isPlaying = controller.isPlaying(item.id);
                final isCurrent = controller.isCurrentTrack(item.id);

                return Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? AppColors.primary
                        : (isDark ? AppColors.secondaryDark : AppColors.secondaryLight),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: isCurrent ? Colors.white : AppColors.primary,
                    size: 28,
                  ),
                );
              }),
              const SizedBox(width: 14),

              // Recitation Information
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.reciterName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Location badge
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black26 : Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on, size: 12, color: Colors.amber),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    item.location,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Duration badge
                        Text(
                          item.duration,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Action buttons (Download & Share)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Obx(() {
                    final progress = controller.downloadService.activeProgress['rare_${item.id}'];
                    final isDownloaded = controller.isDownloaded(item.id);

                    if (progress != null) {
                      return SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          value: progress > 0 ? progress : null,
                          strokeWidth: 2.5,
                        ),
                      );
                    }

                    return IconButton(
                      icon: Icon(
                        isDownloaded ? Icons.download_done_rounded : Icons.download_rounded,
                        color: isDownloaded ? Colors.green : Colors.grey[500],
                        size: 22,
                      ),
                      tooltip: isDownloaded ? 'downloaded'.tr : 'download'.tr,
                      onPressed: () => controller.handleDownload(item),
                    );
                  }),
                  IconButton(
                    icon: Icon(Icons.share_rounded, size: 20, color: Colors.grey[500]),
                    tooltip: 'share'.tr,
                    onPressed: () => controller.copyShareInfo(item),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
