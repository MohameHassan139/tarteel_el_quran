import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/audio_service.dart';
import '../../../core/app_colors.dart';
import '../../../core/surah_display.dart';
import '../../../routes/app_routes.dart';

class BottomPlayer extends StatelessWidget {
  const BottomPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    // This widget is anchored on the Home screen unconditionally (see
    // HomeScreen), so it must not assume AudioService registered — it
    // won't have if StorageService failed to come up during startup (see
    // main.dart's initServices). Hiding the player is a safe degradation;
    // throwing here would take down the app's first screen.
    if (!Get.isRegistered<AudioService>()) return const SizedBox.shrink();

    final audio = Get.find<AudioService>();
    final isArLocale = Get.locale?.languageCode == 'ar';

    return Obx(() {
      final chapter = audio.activeChapter.value;
      if (chapter == null) return const SizedBox.shrink();

      return Card(
        margin: const EdgeInsets.all(12),
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Get.isDarkMode ? AppColors.cardDark : AppColors.cardLight, // Soft theme color
        child: InkWell(
          onTap: () => Get.toNamed(AppRoutes.AUDIO_PLAYER),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.music_note, color: AppColors.primary), // Soft Theme color
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Obx(() {
                            final title = audio.customTitle.value ??
                                SurahDisplay.title(chapter.id, fallback: isArLocale ? chapter.nameArabic : chapter.nameSimple);
                            return Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Get.isDarkMode ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            );
                          }),
                          Obx(() {
                            if (audio.customSubtitle.value != null) {
                              return Text(
                                audio.customSubtitle.value!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Get.isDarkMode ? Colors.grey : Colors.black54,
                                  fontSize: 13,
                                ),
                              );
                            }
                            final verseKey = audio.activeVerseKey.value;
                            final text = verseKey != null ? 'ayah_label'.trParams({'key': verseKey}) : 'loading'.tr;
                            return Text(
                              text,
                              style: TextStyle(
                                color: Get.isDarkMode ? Colors.grey : Colors.black54,
                                fontSize: 13,
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    Obx(() {
                      final isPlaying = audio.isPlaying.value;
                      return IconButton(
                        icon: Icon(
                          isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                          color: AppColors.primary,
                          size: 38,
                        ),
                        onPressed: () {
                          if (isPlaying) {
                            audio.pause();
                          } else {
                            audio.resume();
                          }
                        },
                      );
                    }),
                    IconButton(
                      icon: Icon(Icons.close, color: Get.isDarkMode ? Colors.grey : Colors.black54),
                      onPressed: () => audio.stop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Simple mini progress bar
                Obx(() {
                  final position = audio.position.value;
                  final duration = audio.duration.value;
                  final double progress = duration.inMilliseconds > 0
                      ? position.inMilliseconds / duration.inMilliseconds
                      : 0.0;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: Colors.grey.withOpacity(0.3),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      minHeight: 3,
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      );
    });
  }
}
