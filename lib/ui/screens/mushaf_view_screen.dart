import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:quran_library/quran_library.dart';
import '../../models.dart';
import '../../core/api_service.dart';
import '../../main.dart';

class MushafViewScreen extends StatefulWidget {
  final Chapter chapter;
  const MushafViewScreen({super.key, required this.chapter});

  @override
  State<MushafViewScreen> createState() => _MushafViewScreenState();
}

class _MushafViewScreenState extends State<MushafViewScreen> {
  bool _isLoading = true;

  Timer? _stopwatchTimer;

  List<VerseTiming> _timings = [];
  String? _audioUrl;

  // The currently active ayah number within this surah (for highlighting)
  int? _activeAyahNumber;

  // Repeat mode: repeat current ayah
  bool _isRepeatAyah = false;

  // Progress: we track current ayah position for the thin bar
  double _ayahProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadTimings();
    _startStopwatch();
    Locator.audio.activeVerseKeyNotifier.addListener(_onActiveVerseChanged);
  }

  @override
  void dispose() {
    _stopwatchTimer?.cancel();
    Locator.audio.activeVerseKeyNotifier.removeListener(_onActiveVerseChanged);
    // Clean up any lingering highlight when leaving the screen
    QuranCtrl.instance.clearExternalHighlights();
    super.dispose();
  }

  void _startStopwatch() {
    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      Locator.storage.logReadingSeconds(1);
    });
  }

  void _onActiveVerseChanged() {
    final key = Locator.audio.activeVerseKeyNotifier.value;
    if (!mounted) return;

    if (key == null) {
      if (_activeAyahNumber != null) {
        setState(() {
          _activeAyahNumber = null;
          _ayahProgress = 0.0;
        });
        QuranCtrl.instance.clearExternalHighlights();
      }
      return;
    }

    final parts = key.split(':');
    if (parts.length == 2 && parts[0] == widget.chapter.id.toString()) {
      final ayahNum = int.tryParse(parts[1]);
      if (ayahNum != null && ayahNum != _activeAyahNumber) {
        setState(() {
          _activeAyahNumber = ayahNum;
          // Update thin progress bar based on ayah position
          _ayahProgress = widget.chapter.versesCount > 0
              ? (ayahNum / widget.chapter.versesCount).clamp(0.0, 1.0)
              : 0.0;
        });

        // Resolve the ayah's unique number that QuranCtrl uses for highlighting
        final uq = QuranCtrl.instance
            .getAyahUQBySurahAndAyah(widget.chapter.id, ayahNum);
        if (uq != null) {
          QuranCtrl.instance.setExternalHighlights([uq]);
        }

        // --- AUTO PAGE TURN ---
        try {
          final ayahPage = QuranCtrl.instance.getPageNumberByAyahAndSurahNumber(
            ayahNum,
            widget.chapter.id,
          );
          final currentPage = QuranCtrl.instance.state.currentPageNumber.value;
          if (ayahPage != currentPage && ayahPage > 0) {
            QuranCtrl.instance.jumpToPage(ayahPage - 1);
          }
        } catch (_) {
          // Avoid crashing if page states are not initialized
        }
      }
    }
  }

  Future<void> _loadTimings() async {
    setState(() => _isLoading = true);
    try {
      final reciterId = Locator.storage.getEffectiveReciterId();
      final cached = Locator.storage.getCachedTimings(reciterId, widget.chapter.id);
      if (cached != null) {
        _timings = cached;
        setState(() => _isLoading = false);
        return;
      }
      final audioData = await Locator.api.fetchChapterAudioAndTimings(
        reciterId,
        widget.chapter.id,
      );
      _timings = audioData['timings'] as List<VerseTiming>;
      _audioUrl = audioData['audio_url'] as String?;
    } on ApiException catch (_) {
      // Non-critical — reading still works without audio
    } catch (_) {
      // Non-critical
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startPlaySurah() async {
    if (_timings.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('بيانات توقيت التلاوة غير متوفرة.')),
      );
      return;
    }
    try {
      final reciterId = Locator.storage.getEffectiveReciterId();
      final localPath = Locator.storage.getDownloadedAudioPath(reciterId, widget.chapter.id);
      if (localPath != null) {
        await Locator.audio.playSurah(widget.chapter, localPath, _timings);
      } else if (_audioUrl != null) {
        await Locator.audio.playSurah(widget.chapter, _audioUrl, _timings);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يوجد ملف صوتي. يرجى التحميل أولاً.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تشغيل الصوت: $e')),
      );
    }
  }

  void _stopPlaySurah() {
    Locator.audio.stop();
    setState(() {
      _isRepeatAyah = false;
      _ayahProgress = 0.0;
    });
  }

  /// Go back one ayah
  void _previousAyah() {
    if (_activeAyahNumber != null && _activeAyahNumber! > 1) {
      final targetAyah = _activeAyahNumber! - 1;
      if (_timings.isNotEmpty) {
        // verseKey format is "surahId:ayahNum"
        final targetKey = '${widget.chapter.id}:$targetAyah';
        final timing = _timings.firstWhere(
          (t) => t.verseKey == targetKey,
          orElse: () => _timings.first,
        );
        Locator.audio.seekToTiming(timing);
      }
    }
  }

  /// Toggle repeat for current ayah
  void _toggleRepeat() {
    setState(() => _isRepeatAyah = !_isRepeatAyah);
    Locator.audio.setRepeatCurrentAyah(_isRepeatAyah);
  }

  /// Helper: reciter display name from reciter ID
  String _getReciterName() {
    final id = Locator.storage.getSelectedReciterId();
    const names = {
      7: 'مشاري العفاسي',
      6: 'محمود الحصري',
      2: 'عبد الباسط عبد الصمد',
      9: 'المنشاوي',
      1: 'عبدالله المطرود',
    };
    return names[id] ?? 'قارئ مختار';
  }

  /// Build the Verse model on the fly for the tafseer sheet.
  /// We use the ayah text from quran_library's AyahModel via the long-press callback.
  void _showTafseerSheet(AyahModel ayah) {
    final surahNum = ayah.surahNumber ?? widget.chapter.id;
    final verseKey = '$surahNum:${ayah.ayahNumber}';
    // Build a lightweight Verse for the sheet using AyahModel's actual fields
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
      builder: (_) => _AyahDetailsSheet(verse: verse, chapter: widget.chapter),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Locator.storage.isDarkMode();
    final isAr = Locator.storage.getAppLanguage() == 'ar';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFFAF8F5),
      body: Stack(
        children: [
          // ── Mushaf Page View ──────────────────────────────────────────
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC19A6B)),
                  ),
                )
              : Builder(
                  builder: (ctx) {
                    // Resolve the actual Mushaf page range for this surah
                    final ctrl = QuranCtrl.instance;
                    final sp = ctrl.getPageNumberByAyahAndSurahNumber(
                        1, widget.chapter.id);
                    final ep = ctrl.getPageNumberByAyahAndSurahNumber(
                        widget.chapter.versesCount, widget.chapter.id);

                    return QuranPagesScreen(
                      parentContext: ctx,
                      surahNumber: widget.chapter.id,
                      startPage: sp,
                      endPage: ep,
                      isDark: isDark,
                      appLanguageCode: isAr ? 'ar' : 'en',
                      useDefaultAppBar: true,
                      isShowAudioSlider: false,
                      // Highlighting is driven directly via
                      // QuranCtrl.instance.setExternalHighlights()
                      // in _onActiveVerseChanged — no static map needed.
                      ayahSelectedBackgroundColor:
                          const Color(0xFFC19A6B).withValues(alpha: 0.35),
                      ayahSelectedFontColor:
                          isDark ? Colors.white : const Color(0xFF1A0F00),
                      onAyahLongPress: (_, ayah) => _showTafseerSheet(ayah),
                    );
                  },
                ),

          // ── Floating Audio Controls ───────────────────────────────────
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Center(child: _buildAudioBar(isDark)),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioBar(bool isDark) {
    return ValueListenableBuilder<bool>(
      valueListenable: Locator.audio.isPlayingNotifier,
      builder: (context, isPlaying, _) {
        return ValueListenableBuilder<Chapter?>(
          valueListenable: Locator.audio.activeChapterNotifier,
          builder: (context, activeChapter, _) {
            final isThisSurah = activeChapter?.id == widget.chapter.id;
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
                          ? const Color(0xFF181510).withValues(alpha: 0.85)
                          : const Color(0xFFFCF7EE).withValues(alpha: 0.90),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFC19A6B).withValues(alpha: 0.25),
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
                          child: LinearProgressIndicator(
                            value: isLoaded ? _ayahProgress : 0.0,
                            backgroundColor: isLoaded
                                ? const Color(0xFFC19A6B).withValues(alpha: 0.08)
                                : Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isLoaded
                                  ? const Color(0xFFC19A6B)
                                  : Colors.transparent,
                            ),
                            minHeight: 1.2,
                          ),
                        ),

                        // ── Main Layout ───────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7, // Thinner vertical padding
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
                                          _getReciterName(),
                                          style: TextStyle(
                                            fontSize: 13, // Thinner text
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : const Color(0xFF8B6914),
                                            fontFamily: 'UthmanicHafs',
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          isLoaded && _activeAyahNumber != null
                                              ? 'آية $_activeAyahNumber من ${widget.chapter.versesCount}'
                                              : 'تلاوة سورة ${widget.chapter.nameArabic}',
                                          style: TextStyle(
                                            fontSize: 10, // Thinner text
                                            color: isDark
                                                ? Colors.white.withValues(alpha: 0.5)
                                                : Colors.black.withValues(alpha: 0.5),
                                          ),
                                        ),
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
                                height: 18, // Thinner divider
                                width: 1,
                                color: const Color(0xFFC19A6B).withValues(alpha: 0.2),
                              ),
                              const SizedBox(width: 8),

                              // Right side: Audio controls
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Previous Ayah
                                  _BarButton(
                                    icon: Icons.skip_previous_rounded,
                                    enabled: isLoaded && (_activeAyahNumber ?? 1) > 1,
                                    onTap: _previousAyah,
                                  ),
                                  const SizedBox(width: 4),

                                  // Play / Pause Button
                                  GestureDetector(
                                    onTap: () {
                                      if (isCurrentlyPlaying) {
                                        Locator.audio.pause();
                                      } else if (isLoaded) {
                                        Locator.audio.resume();
                                      } else {
                                        _startPlaySurah();
                                      }
                                    },
                                    child: Container(
                                      width: 36, // Thinner button
                                      height: 36,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            const Color(0xFFD4AF37),
                                            const Color(0xFFC19A6B),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFC19A6B).withValues(alpha: 0.25),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        isCurrentlyPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 20, // Thinner icon
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),

                                  // Stop Button (Resets completely)
                                  _BarButton(
                                    icon: Icons.stop_rounded,
                                    enabled: isLoaded,
                                    onTap: _stopPlaySurah,
                                  ),
                                  const SizedBox(width: 4),

                                  // Repeat Ayah Toggle
                                  _BarButton(
                                    icon: Icons.repeat_one_rounded,
                                    enabled: true,
                                    active: _isRepeatAyah,
                                    onTap: _toggleRepeat,
                                  ),
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
          },
        );
      },
    );
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
        ? const Color(0xFFC19A6B)
        : enabled
            ? const Color(0xFFC19A6B).withValues(alpha: 0.85)
            : const Color(0xFFC19A6B).withValues(alpha: 0.25);

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFFC19A6B).withValues(alpha: 0.22)
              : const Color(0xFFC19A6B).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: active
              ? Border.all(
                  color: const Color(0xFFC19A6B).withValues(alpha: 0.6),
                  width: 1,
                )
              : null,
        ),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }
}

// ─── Tiny animated equalizer bars ─────────────────────────────────────────
class _EqualizerIcon extends StatefulWidget {
  @override
  State<_EqualizerIcon> createState() => _EqualizerIconState();
}

class _EqualizerIconState extends State<_EqualizerIcon>
    with SingleTickerProviderStateMixin {
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
                color: const Color(0xFFC19A6B),
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
      final text = await Locator.api.fetchTafsir(
        widget.verse.verseKey,
        tafsirId: _selectedTafsirId,
      );
      final cleaned =
          text.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('&nbsp;', ' ').trim();
      if (mounted) setState(() => _tafsirText = cleaned);
    } catch (e) {
      if (mounted) setState(() => _tafsirError = e.toString());
    } finally {
      if (mounted) setState(() => _isLoadingTafsir = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Locator.storage.isDarkMode();
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
            color: const Color(0xFFC19A6B),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'الآية ${widget.verse.verseNumber}',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
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
        color: isDark ? const Color(0xFF2C1F00) : const Color(0xFFFFF8E7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC19A6B).withValues(alpha: 0.35)),
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
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF4F4F4),
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
          const SizedBox(height: 8),
          Text(
            widget.verse.translationText,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.6,
              color: isDark ? Colors.white70 : Colors.black87,
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'التفسير',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0EBE0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedTafsirId,
                  dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  items: _tafsirOptions.map((opt) {
                    return DropdownMenuItem<int>(
                      value: opt['id'] as int,
                      child: Text(opt['name'] as String),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null && val != _selectedTafsirId) {
                      setState(() => _selectedTafsirId = val);
                      _loadTafsir();
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_isLoadingTafsir)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC19A6B)),
              ),
            ),
          )
        else if (_tafsirError != null)
          _buildTafsirError(isDark)
        else
          _buildTafsirText(isDark),
      ],
    );
  }

  Widget _buildTafsirText(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFBF8F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Text(
        _tafsirText ?? '',
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontSize: 15,
          height: 1.9,
          color: isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildTafsirError(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(Icons.cloud_off_outlined, color: Colors.grey[500], size: 36),
          const SizedBox(height: 8),
          Text(
            'تعذّر تحميل التفسير',
            style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _loadTafsir,
            icon: const Icon(Icons.refresh, color: Color(0xFFC19A6B)),
            label: const Text(
              'إعادة المحاولة',
              style: TextStyle(color: Color(0xFFC19A6B)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Shared chip widget
// ─────────────────────────────────────────────────────────────────
class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFC19A6B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFFC19A6B)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFFC19A6B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
