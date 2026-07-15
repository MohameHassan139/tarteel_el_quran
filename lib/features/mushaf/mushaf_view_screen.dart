import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quran_library/quran_library.dart';
import '../../core/api_service.dart';
import '../../core/storage_service.dart';
import '../../models.dart';
import 'mushaf_view_controller.dart';
import '../../core/app_colors.dart';

class MushafViewScreen extends GetView<MushafViewController> {
  const MushafViewScreen({super.key});

  /// Build the Verse model on the fly for the tafseer sheet.
  void _showTafseerSheet(BuildContext context, AyahModel ayah) {
    final surahNum = ayah.surahNumber ?? controller.chapter.id;
    final verseKey = '$surahNum:${ayah.ayahNumber}';
    final verse = Verse(
      id: ayah.ayahUQNumber,
      verseNumber: ayah.ayahNumber,
      verseKey: verseKey,
      textUthmani: ayah.text,
      translationText: '',
      juzNumber: ayah.juz,
      pageNumber: ayah.page,
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AyahDetailsSheet(verse: verse, chapter: controller.chapter),
    );
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

// ─────────────────────────────────────────────────────────────────
// Ayah Details Bottom Sheet (Tafseer + Info)
// ─────────────────────────────────────────────────────────────────
class _AyahDetailsSheet extends StatefulWidget {
  final Verse verse;
  final Chapter chapter;

  const _AyahDetailsSheet({required this.verse, required this.chapter});

  @override
  State<_AyahDetailsSheet> createState() => _AyahDetailsSheetState();
}

class _AyahDetailsSheetState extends State<_AyahDetailsSheet> {
  final ApiService _api = Get.find<ApiService>();

  String? _tafsirText;
  bool _isLoadingTafsir = true;
  String? _tafsirError;

  static const _tafsirOptions = [
    {'id': 16, 'name': 'التفسير الميسر'},
    {'id': 91, 'name': 'ابن كثير (عربي)'},
    {'id': 131, 'name': "Saheeh Int'l (English)"},
  ];
  int _selectedTafsirId = 16;

  @override
  void initState() {
    super.initState();
    _loadTafsir();
  }

  Future<void> _loadTafsir() async {
    setState(() {
      _isLoadingTafsir = true;
      _tafsirError = null;
      _tafsirText = null;
    });
    try {
      final text = await _api.fetchTafsir(
        widget.verse.verseKey,
        tafsirId: _selectedTafsirId,
      );
      final cleaned = text.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('&nbsp;', ' ').trim();
      if (mounted) setState(() => _tafsirText = cleaned);
    } catch (e) {
      if (mounted) setState(() => _tafsirError = e.toString());
    } finally {
      if (mounted) setState(() => _isLoadingTafsir = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF161616) : Colors.white;
    final handleColor = isDark ? Colors.white24 : Colors.black26;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: handleColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  children: [
                    _buildHeader(isDark),
                    const SizedBox(height: 16),
                    _buildMetaChips(isDark),
                    const SizedBox(height: 16),
                    _buildArabicCard(isDark),
                    const SizedBox(height: 12),
                    if (widget.verse.translationText.isNotEmpty) ...[
                      _buildTranslationCard(isDark),
                      const SizedBox(height: 16),
                    ],
                    _buildTafsirSection(isDark),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'الآية ${widget.verse.verseNumber}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            widget.chapter.nameArabic,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'UthmanicHafs',
              fontSize: 20,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetaChips(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _MetaChip(icon: Icons.menu_book_outlined, label: 'الجزء ${widget.verse.juzNumber}'),
        _MetaChip(icon: Icons.article_outlined, label: 'صفحة ${widget.verse.pageNumber}'),
        _MetaChip(
          icon: Icons.place_outlined,
          label: widget.chapter.revelationPlace == 'makkah' ? 'مكية' : 'مدنية',
        ),
        _MetaChip(
          icon: Icons.format_list_numbered,
          label: 'ترتيب النزول: ${widget.chapter.revelationOrder}',
        ),
      ],
    );
  }

  Widget _buildArabicCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.secondaryDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: widget.verse.textUthmani.isNotEmpty
          ? Text(
              widget.verse.textUthmani,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'UthmanicHafs',
                fontSize: 28,
                height: 1.9,
                color: isDark ? Colors.white : Colors.black87,
              ),
            )
          : GetSingleAyah(
              surahNumber: widget.chapter.id,
              ayahNumber: widget.verse.verseNumber,
              isDark: isDark,
              fontSize: 28,
              isBold: false,
            ),
    );
  }

  Widget _buildTranslationCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.secondaryLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الترجمة',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : Colors.black38,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.verse.translationText,
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: isDark ? Colors.grey[300] : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTafsirSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Dropdown Selector
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'التفسير والترجمة',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            DropdownButton<int>(
              value: _selectedTafsirId,
              dropdownColor: isDark ? AppColors.cardDark : Colors.white,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
              underline: const SizedBox(),
              items: _tafsirOptions.map((opt) {
                return DropdownMenuItem<int>(
                  value: opt['id'] as int,
                  child: Text(opt['name'] as String),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedTafsirId = val);
                  _loadTafsir();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Tafsir Text Display
        _isLoadingTafsir
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              )
            : _tafsirError != null
                ? Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red[900]?.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'خطأ أثناء تحميل التفسير: $_tafsirError\n\nتأكد من اتصالك بالإنترنت في حال كانت السورة غير محملة.',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  )
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cardDark : AppColors.bgLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                    ),
                    child: Text(
                      _tafsirText ?? '',
                      textDirection: _selectedTafsirId == 131 ? TextDirection.ltr : TextDirection.rtl,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                      ),
                    ),
                  ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chipBg = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04);
    final color = isDark ? Colors.grey[400] : Colors.grey[700];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}
