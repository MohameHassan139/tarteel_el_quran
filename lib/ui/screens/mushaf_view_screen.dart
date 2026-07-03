import 'dart:async';
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

  double _arabicFontSize = 28.0;

  Timer? _stopwatchTimer;

  List<VerseTiming> _timings = [];
  String? _audioUrl;

  // The currently active ayah number within this surah (for highlighting)
  int? _activeAyahNumber;

  @override
  void initState() {
    super.initState();
    _arabicFontSize = Locator.storage.getArabicFontSize();
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
        setState(() => _activeAyahNumber = null);
        QuranCtrl.instance.clearExternalHighlights();
      }
      return;
    }

    final parts = key.split(':');
    if (parts.length == 2 && parts[0] == widget.chapter.id.toString()) {
      final ayahNum = int.tryParse(parts[1]);
      if (ayahNum != null && ayahNum != _activeAyahNumber) {
        setState(() => _activeAyahNumber = ayahNum);

        // Resolve the ayah's unique number that QuranCtrl uses for highlighting
        final uq = QuranCtrl.instance
            .getAyahUQBySurahAndAyah(widget.chapter.id, ayahNum);
        if (uq != null) {
          QuranCtrl.instance.setExternalHighlights([uq]);
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
            bottom: 24,
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
        final isThisSurah =
            Locator.audio.activeChapterNotifier.value?.id == widget.chapter.id;
        final active = isPlaying && isThisSurah;

        return Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E1A10).withValues(alpha: 0.95)
                : const Color(0xFFFFF8E7).withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: const Color(0xFFC19A6B).withValues(alpha: 0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Surah name
              Text(
                widget.chapter.nameArabic,
                style: const TextStyle(
                  fontFamily: 'UthmanicHafs',
                  fontSize: 18,
                  color: Color(0xFFC19A6B),
                ),
              ),
              const SizedBox(width: 16),

              // Font decrease
              _BarButton(
                icon: Icons.text_decrease,
                onTap: () {
                  setState(() {
                    _arabicFontSize = (_arabicFontSize - 2).clamp(18.0, 52.0);
                  });
                  Locator.storage.setArabicFontSize(_arabicFontSize);
                },
              ),
              const SizedBox(width: 8),

              // Font increase
              _BarButton(
                icon: Icons.text_increase,
                onTap: () {
                  setState(() {
                    _arabicFontSize = (_arabicFontSize + 2).clamp(18.0, 52.0);
                  });
                  Locator.storage.setArabicFontSize(_arabicFontSize);
                },
              ),
              const SizedBox(width: 12),

              // Play / Stop
              GestureDetector(
                onTap: active ? _stopPlaySurah : _startPlaySurah,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC19A6B),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFC19A6B).withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    active ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),

              // Active verse indicator
              if (active && _activeAyahNumber != null) ...[
                const SizedBox(width: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    key: ValueKey(_activeAyahNumber),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC19A6B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.graphic_eq, size: 14, color: Color(0xFFC19A6B)),
                        const SizedBox(width: 4),
                        Text(
                          'آية $_activeAyahNumber',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFC19A6B),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _BarButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFFC19A6B).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFFC19A6B)),
      ),
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
