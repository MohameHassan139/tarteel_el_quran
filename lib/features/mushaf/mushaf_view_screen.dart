import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quran_library/quran_library.dart';
import 'mushaf_view_controller.dart';
import '../../core/app_colors.dart';

class MushafViewScreen extends GetView<MushafViewController> {
  const MushafViewScreen({super.key});

  /// Build the Verse model on the fly for the tafseer sheet.
  void _showTafseerSheet(BuildContext context, AyahModel ayah) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    TafsirCtrl.instance.initTafsir().then((_) {
      ShowTafsirExtension(null).showTafsirOnTap(
        context: context,
        ayahNum: ayah.ayahNumber,
        pageIndex: ayah.page - 1,
        ayahUQNum: ayah.ayahUQNumber,
        ayahNumber: ayah.ayahNumber,
        isDark: isDark,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = controller.storage.getAppLanguage() == 'ar';

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: Stack(
        children: [
          // ── Mushaf Page View ──────────────────────────────────────────
          Obx(() {
            if (controller.isLoading.value) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              );
            }

            // Access activeAyahNumber to trigger real-time highlight updates in Obx
            final _ = controller.activeAyahNumber.value;

            final ctrl = QuranCtrl.instance;
            final sp = ctrl.getPageNumberByAyahAndSurahNumber(1, controller.chapter.id);
            final ep = ctrl.getPageNumberByAyahAndSurahNumber(controller.chapter.versesCount, controller.chapter.id);

            return QuranPagesScreen(
              parentContext: context,
              surahNumber: controller.chapter.id,
              startPage: sp,
              endPage: ep,
              isDark: isDark,
              appLanguageCode: isAr ? 'ar' : 'en',
              useDefaultAppBar: true,
              isShowAudioSlider: false,
              ayahSelectedBackgroundColor: AppColors.primary.withValues(alpha: 0.35),
              ayahSelectedFontColor: isDark ? Colors.white : const Color(0xFF1A0F00),
              onAyahLongPress: (_, ayah) => _showTafseerSheet(context, ayah),
            );
          }),

          // ── Floating Audio Controls ───────────────────────────────────
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Center(child: _buildAudioBar(context, isDark)),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioBar(BuildContext context, bool isDark) {
    final audio = controller.audio;

    return Obx(() {
      final activeChapter = audio.activeChapter.value;
      final isPlaying = audio.isPlaying.value;
      final isThisSurah = activeChapter?.id == controller.chapter.id;
      final isLoaded = isThisSurah;
      final isCurrentlyPlaying = isPlaying && isThisSurah;

      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: MediaQuery.of(context).size.width * 0.94,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.cardDark.withValues(alpha: 0.85)
                    : AppColors.cardLight.withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Thinner progress streamline (1.2px) ──────────────
                  SizedBox(
                    height: 1.2,
                    child: Obx(() {
                      final progress = controller.ayahProgress.value;
                      return LinearProgressIndicator(
                        value: isLoaded ? progress : 0.0,
                        backgroundColor: isLoaded
                            ? AppColors.primary.withValues(alpha: 0.08)
                            : Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isLoaded ? AppColors.primary : Colors.transparent,
                        ),
                        minHeight: 1.2,
                      );
                    }),
                  ),

                  // ── Main Layout ───────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    child: Row(
                      children: [
                        // Left side: Reciter name & info
                        Expanded(
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    controller.getReciterName(),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : AppColors.primary,
                                      fontFamily: 'UthmanicHafs',
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Obx(() {
                                    final ayahNum = controller.activeAyahNumber.value;
                                    return Text(
                                      isLoaded && ayahNum != null
                                          ? 'آية $ayahNum من ${controller.chapter.versesCount}'
                                          : 'تلاوة سورة ${controller.chapter.nameArabic}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.5)
                                            : Colors.black.withValues(alpha: 0.5),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                              if (isCurrentlyPlaying) ...[
                                const SizedBox(width: 6),
                                _EqualizerIcon(),
                              ],
                            ],
                          ),
                        ),

                        // Vertical divider
                        Container(
                          height: 18,
                          width: 1,
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                        const SizedBox(width: 8),

                        // Right side: Audio controls
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Previous Ayah
                            Obx(() {
                              final ayahNum = controller.activeAyahNumber.value;
                              return _BarButton(
                                icon: Icons.skip_previous_rounded,
                                enabled: isLoaded && (ayahNum ?? 1) > 1,
                                onTap: controller.previousAyah,
                              );
                            }),
                            const SizedBox(width: 4),

                            // Play / Pause Button
                            GestureDetector(
                              onTap: () {
                                if (isCurrentlyPlaying) {
                                  audio.pause();
                                } else if (isLoaded) {
                                  audio.resume();
                                } else {
                                  controller.startPlaySurah();
                                }
                              },
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: const [
                                      AppColors.primary,
                                      AppColors.accent,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.25),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isCurrentlyPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),

                            // Stop Button (Resets completely)
                            _BarButton(
                              icon: Icons.stop_rounded,
                              enabled: isLoaded,
                              onTap: controller.stopPlaySurah,
                            ),
                            const SizedBox(width: 4),

                            // Repeat Ayah Toggle
                            Obx(() {
                              final repeat = controller.isRepeatAyah.value;
                              return _BarButton(
                                icon: Icons.repeat_one_rounded,
                                enabled: true,
                                active: repeat,
                                onTap: controller.toggleRepeat,
                              );
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _BarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final bool active;

  const _BarButton({
    required this.icon,
    required this.onTap,
    this.enabled = true,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active
        ? AppColors.primary
        : enabled
            ? AppColors.primary.withValues(alpha: 0.85)
            : AppColors.primary.withValues(alpha: 0.25);

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withValues(alpha: 0.22)
              : AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: active
              ? Border.all(
                  color: AppColors.primary.withValues(alpha: 0.6),
                  width: 1,
                )
              : null,
        ),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }
}

class _EqualizerIcon extends StatefulWidget {
  @override
  State<_EqualizerIcon> createState() => _EqualizerIconState();
}

class _EqualizerIconState extends State<_EqualizerIcon> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<Animation<double>> _bars;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _bars = List.generate(3, (i) {
      final begin = 0.3 + (i * 0.2);
      return Tween<double>(begin: begin, end: 1.0).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(i * 0.2, 0.6 + i * 0.2, curve: Curves.easeInOut),
        ),
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(3, (i) {
            return Container(
              width: 2.2,
              height: 10 * _bars[i].value,
              margin: const EdgeInsets.symmetric(horizontal: 1.2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(1.5),
              ),
            );
          }),
        );
      },
    );
  }
}


