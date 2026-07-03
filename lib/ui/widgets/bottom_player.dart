import 'package:flutter/material.dart';
import '../../models.dart';
import '../../main.dart'; // To get Locator

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
    final audio = Locator.audio;

    return ValueListenableBuilder<Chapter?>(
      valueListenable: audio.activeChapterNotifier,
      builder: (context, chapter, child) {
        if (chapter == null) return const SizedBox.shrink();

        return Card(
          margin: const EdgeInsets.all(12),
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: const Color(0xFF1E1E1E), // Soft dark color
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
                      const Icon(Icons.music_note, color: Color(0xFFC19A6B)), // Soft Gold
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'سورة ${chapter.nameSimple}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            ValueListenableBuilder<String?>(
                              valueListenable: audio.activeVerseKeyNotifier,
                              builder: (context, verseKey, _) {
                                final text = verseKey != null ? 'الآية $verseKey' : 'جاري التحميل...';
                                return Text(
                                  text,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: audio.isPlayingNotifier,
                        builder: (context, isPlaying, _) {
                          return IconButton(
                            icon: Icon(
                              isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                              color: const Color(0xFFC19A6B),
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
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => audio.stop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Simple mini progress bar
                  ValueListenableBuilder<Duration>(
                    valueListenable: audio.positionNotifier,
                    builder: (context, position, _) {
                      return ValueListenableBuilder<Duration>(
                        valueListenable: audio.durationNotifier,
                        builder: (context, duration, _) {
                          final double progress = duration.inMilliseconds > 0
                              ? position.inMilliseconds / duration.inMilliseconds
                              : 0.0;
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress.clamp(0.0, 1.0),
                              backgroundColor: Colors.grey.withOpacity(0.3),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFC19A6B)),
                              minHeight: 3,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showExpandedPlayer(BuildContext context, Chapter chapter) {
    final audio = Locator.audio;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121212),
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
                  color: Colors.grey[800],
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
                  color: Color(0xFFC19A6B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'سورة ${chapter.nameSimple}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              Text(
                chapter.translatedName,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 32),
              // Current Ayah info
              ValueListenableBuilder<String?>(
                valueListenable: audio.activeVerseKeyNotifier,
                builder: (context, verseKey, _) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      verseKey != null ? 'تلاوة الآية: $verseKey' : 'جاري التحميل والتزامن...',
                      style: const TextStyle(
                        color: Color(0xFFC19A6B),
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              // Progress slider
              ValueListenableBuilder<Duration>(
                valueListenable: audio.positionNotifier,
                builder: (context, position, _) {
                  return ValueListenableBuilder<Duration>(
                    valueListenable: audio.durationNotifier,
                    builder: (context, duration, _) {
                      final double maxMs = duration.inMilliseconds.toDouble();
                      final double currentMs = position.inMilliseconds.toDouble().clamp(0, maxMs);

                      return Column(
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFFC19A6B),
                              inactiveTrackColor: Colors.grey[800],
                              thumbColor: const Color(0xFFC19A6B),
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
                                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                                Text(
                                  _formatDuration(duration),
                                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
              // Control buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 32,
                    icon: const Icon(Icons.replay_10, color: Colors.white),
                    onPressed: () {
                      final newPos = audio.positionNotifier.value - const Duration(seconds: 10);
                      audio.seek(newPos < Duration.zero ? Duration.zero : newPos);
                    },
                  ),
                  const SizedBox(width: 16),
                  ValueListenableBuilder<bool>(
                    valueListenable: audio.isPlayingNotifier,
                    builder: (context, isPlaying, _) {
                      return IconButton(
                        iconSize: 72,
                        icon: Icon(
                          isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                          color: const Color(0xFFC19A6B),
                        ),
                        onPressed: () {
                          if (isPlaying) {
                            audio.pause();
                          } else {
                            audio.resume();
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    iconSize: 32,
                    icon: const Icon(Icons.forward_10, color: Colors.white),
                    onPressed: () {
                      final newPos = audio.positionNotifier.value + const Duration(seconds: 10);
                      final maxDur = audio.durationNotifier.value;
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
