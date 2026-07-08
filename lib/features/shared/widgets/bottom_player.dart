import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/audio_service.dart';
import '../../../models.dart';
import '../../../core/app_colors.dart';

class BottomPlayer extends StatelessWidget {
  const BottomPlayer({super.key});

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final audio = Get.find<AudioService>();

    return Obx(() {
      final chapter = audio.activeChapter.value;
      if (chapter == null) return const SizedBox.shrink();

      return Card(
        margin: const EdgeInsets.all(12),
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Get.isDarkMode ? AppColors.cardDark : AppColors.cardLight, // Soft theme color
        child: InkWell(
          onTap: () => _showExpandedPlayer(context, chapter),
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
                          Text(
                            'سورة ${chapter.nameSimple}',
                            style: TextStyle(
                              color: Get.isDarkMode ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Obx(() {
                            final verseKey = audio.activeVerseKey.value;
                            final text = verseKey != null ? 'الآية $verseKey' : 'جاري التحميل...';
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

  void _showExpandedPlayer(BuildContext context, Chapter chapter) {
    final audio = Get.find<AudioService>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Get.isDarkMode ? AppColors.bgDark : AppColors.bgLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Get.isDarkMode ? Colors.grey[800] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              // Surah and translation detail
              Text(
                chapter.nameArabic,
                style: const TextStyle(
                  fontFamily: 'UthmanicHafs',
                  fontSize: 42,
                  color: AppColors.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'سورة ${chapter.nameSimple}',
                style: TextStyle(
                  color: Get.isDarkMode ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              Text(
                chapter.translatedName,
                style: TextStyle(
                  color: Get.isDarkMode ? Colors.grey[400] : Colors.black54,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 32),
              // Current Ayah info
              Obx(() {
                final verseKey = audio.activeVerseKey.value;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: Get.isDarkMode ? AppColors.cardDark : AppColors.cardLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    verseKey != null ? 'تلاوة الآية: $verseKey' : 'جاري التحميل والتزامن...',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                );
              }),
              const SizedBox(height: 32),
              // Progress slider
              Obx(() {
                final position = audio.position.value;
                final duration = audio.duration.value;
                final double maxMs = duration.inMilliseconds.toDouble();
                final double currentMs = position.inMilliseconds.toDouble().clamp(0, maxMs);

                return Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor: Get.isDarkMode ? Colors.grey[800] : Colors.grey[300],
                        thumbColor: AppColors.primary,
                        trackHeight: 4.0,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                      ),
                      child: Slider(
                        value: maxMs > 0 ? currentMs : 0.0,
                        max: maxMs > 0 ? maxMs : 1.0,
                        onChanged: (val) {
                          audio.seek(Duration(milliseconds: val.toInt()));
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(position),
                            style: TextStyle(color: Get.isDarkMode ? Colors.grey : Colors.black54, fontSize: 13),
                          ),
                          Text(
                            _formatDuration(duration),
                            style: TextStyle(color: Get.isDarkMode ? Colors.grey : Colors.black54, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 24),
              // Control buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 32,
                    icon: Icon(Icons.replay_10, color: Get.isDarkMode ? Colors.white : Colors.black87),
                    onPressed: () {
                      final newPos = audio.position.value - const Duration(seconds: 10);
                      audio.seek(newPos < Duration.zero ? Duration.zero : newPos);
                    },
                  ),
                  const SizedBox(width: 16),
                  Obx(() {
                    final isPlaying = audio.isPlaying.value;
                    return IconButton(
                      iconSize: 72,
                      icon: Icon(
                        isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                        color: AppColors.primary,
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
                  const SizedBox(width: 16),
                  IconButton(
                    iconSize: 32,
                    icon: Icon(Icons.forward_10, color: Get.isDarkMode ? Colors.white : Colors.black87),
                    onPressed: () {
                      final newPos = audio.position.value + const Duration(seconds: 10);
                      final maxDur = audio.duration.value;
                      audio.seek(newPos > maxDur ? maxDur : newPos);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
