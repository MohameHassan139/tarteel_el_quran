import 'package:flutter/material.dart';
import 'package:quran_library/quran_library.dart';
import '../../models.dart';
import '../../core/audio_service.dart';
import '../../main.dart'; // To get Locator

class HifzScreen extends StatefulWidget {
  const HifzScreen({super.key});

  @override
  State<HifzScreen> createState() => _HifzScreenState();
}

class _HifzScreenState extends State<HifzScreen> {
  List<Chapter> _chapters = [];
  Chapter? _selectedChapter;
  final TextEditingController _startAyahController = TextEditingController(text: '1');
  final TextEditingController _endAyahController = TextEditingController(text: '7');
  
  int _verseRepetitions = 3;
  int _rangeRepetitions = 2;
  int _selectedReciterId = 7;
  String _selectedStyle = 'murattal';

  bool _isHifzActive = false;
  bool _isLoading = false;
  List<Verse> _hifzVerses = [];
  Verse? _currentRecitingVerse;

  @override
  void initState() {
    super.initState();
    _selectedReciterId = Locator.storage.getSelectedReciterId();
    _selectedStyle = Locator.storage.getSelectedStyle();
    _loadChapters();
    
    // Listen to changes in the active reciting verse
    Locator.audio.activeVerseKeyNotifier.addListener(_onActiveVerseChanged);
  }

  @override
  void dispose() {
    _startAyahController.dispose();
    _endAyahController.dispose();
    Locator.audio.activeVerseKeyNotifier.removeListener(_onActiveVerseChanged);
    super.dispose();
  }

  void _loadChapters() {
    final cached = Locator.storage.getCachedChapters();
    if (cached != null && cached.isNotEmpty) {
      setState(() {
        _chapters = cached;
        _selectedChapter = cached.first;
        _updateEndAyahField(cached.first);
      });
    }
  }

  void _updateEndAyahField(Chapter chapter) {
    _startAyahController.text = '1';
    _endAyahController.text = '${chapter.versesCount}';
  }

  void _onActiveVerseChanged() {
    final activeKey = Locator.audio.activeVerseKeyNotifier.value;
    if (activeKey == null || _hifzVerses.isEmpty || !mounted) {
      setState(() {
        _currentRecitingVerse = null;
      });
      return;
    }

    try {
      final verse = _hifzVerses.firstWhere((v) => v.verseKey == activeKey);
      setState(() {
        _currentRecitingVerse = verse;
      });
    } catch (_) {
      // Verse is not in our active Hifz list
    }
  }

  Future<void> _startHifz() async {
    final chapter = _selectedChapter;
    if (chapter == null) return;

    final int startAyah = int.tryParse(_startAyahController.text) ?? 1;
    final int endAyah = int.tryParse(_endAyahController.text) ?? chapter.versesCount;

    if (startAyah < 1 || endAyah > chapter.versesCount || startAyah > endAyah) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نطاق الآيات غير صالح.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _isHifzActive = true;
    });

    try {
      // Load Surah verses (cached or API)
      final verses = await Locator.api.fetchVerses(chapter.id);
      
      // Filter verses to the selected range
      _hifzVerses = verses.where((v) => v.verseNumber >= startAyah && v.verseNumber <= endAyah).toList();

      final reciterId = Locator.storage.getEffectiveReciterId();
      final isDownloaded = Locator.storage.isChapterDownloaded(reciterId, chapter.id);

      String? audioUrl;
      List<VerseTiming> timings = [];

      if (isDownloaded) {
        final cached = Locator.storage.getCachedTimings(reciterId, chapter.id);
        if (cached != null) {
          timings = cached;
        }
      } else {
        final audioData = await Locator.api.fetchChapterAudioAndTimings(reciterId, chapter.id);
        audioUrl = audioData['audio_url'] as String?;
        timings = audioData['timings'] as List<VerseTiming>? ?? [];
      }

      if (timings.isEmpty) {
        throw Exception('بيانات التوقيت غير متوفرة لهذه السورة.');
      }

      final config = HifzLoopConfig(
        startVerseKey: '${chapter.id}:$startAyah',
        endVerseKey: '${chapter.id}:$endAyah',
        verseRepetitions: _verseRepetitions,
        rangeRepetitions: _rangeRepetitions,
      );

      // Play audio in looping mode
      await Locator.audio.playHifz(chapter, audioUrl, timings, config);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل بدء حلقة الحفظ: ${e.toString()}')),
      );
      setState(() {
        _isHifzActive = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _stopHifz() {
    Locator.audio.stop();
    setState(() {
      _isHifzActive = false;
      _currentRecitingVerse = null;
      _hifzVerses = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Locator.storage.isDarkMode();
    final audio = Locator.audio;

    if (_isHifzActive) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('مساحة الحفظ والتركيز'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _stopHifz,
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC19A6B)),
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Verse indicators
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC19A6B).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _currentRecitingVerse != null
                              ? 'الآية ${_currentRecitingVerse!.verseKey}'
                              : 'جاري تهيئة مساحة الحفظ...',
                          style: const TextStyle(
                            color: Color(0xFFC19A6B),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Large Clean text workspace
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_currentRecitingVerse != null) ...[
                                // Use quran_library GetSingleAyah for authentic Mushaf font
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFC19A6B).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFC19A6B).withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: () {
                                    final parts = _currentRecitingVerse!.verseKey.split(':');
                                    final surahNum = int.tryParse(parts[0]) ?? 1;
                                    final ayahNum = int.tryParse(parts.length > 1 ? parts[1] : '1') ?? 1;
                                    return GetSingleAyah(
                                      surahNumber: surahNum,
                                      ayahNumber: ayahNum,
                                      isDark: true,
                                      fontSize: 34,
                                      isBold: false,
                                    );
                                  }(),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  _currentRecitingVerse!.translationText,
                                  style: TextStyle(
                                    fontSize: 17,
                                    color: Colors.grey[400],
                                    height: 1.4,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ] else
                                const Text(
                                  'جاري التحميل والتزامن...',
                                  style: TextStyle(color: Colors.grey, fontSize: 16),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Looping status indicators
                    Card(
                      color: const Color(0xFF1E1E1E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('تكرار الآية الحالية', style: TextStyle(color: Colors.grey)),
                                ValueListenableBuilder<int>(
                                  valueListenable: audio.verseRepeatNotifier,
                                  builder: (context, count, _) {
                                    return Text(
                                      '$count / $_verseRepetitions',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('تكرار النطاق الكامل', style: TextStyle(color: Colors.grey)),
                                ValueListenableBuilder<int>(
                                  valueListenable: audio.rangeRepeatNotifier,
                                  builder: (context, count, _) {
                                    return Text(
                                      '$count / $_rangeRepetitions',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Stop button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[800],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      icon: const Icon(Icons.stop, color: Colors.white),
                      label: const Text('الخروج من مساحة الحفظ', style: TextStyle(color: Colors.white, fontSize: 16)),
                      onPressed: _stopHifz,
                    ),
                  ],
                ),
              ),
      );
    }

    if (_chapters.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('حفظ القرآن الكريم'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'لا توجد سور مخزنة مؤقتاً.\n\nيرجى فتح شاشة "المصحف الشريف" أولاً أثناء الاتصال بالإنترنت لتحميل تفاصيل السور.',
              style: TextStyle(color: Colors.grey, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('حفظ القرآن الكريم', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'اختر السورة ونطاق الآيات',
              style: TextStyle(color: Color(0xFFC19A6B), fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            
            // Surah Dropdown selector
            DropdownButtonFormField<Chapter>(
              value: _selectedChapter,
              dropdownColor: const Color(0xFF1E1E1E),
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey[200],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              items: _chapters.map((chapter) {
                return DropdownMenuItem(
                  value: chapter,
                  child: Text('سورة ${chapter.nameSimple} (${chapter.nameArabic})'),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedChapter = val;
                    _updateEndAyahField(val);
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            
            // Range Inputs
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('بداية الآية', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _startAyahController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey[200],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('نهاية الآية', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _endAyahController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey[200],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            const Text(
              'خيارات التكرار والتحفيظ',
              style: TextStyle(color: Color(0xFFC19A6B), fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            
            // Repetitions selectors
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _verseRepetitions,
                        dropdownColor: const Color(0xFF1E1E1E),
                        items: List.generate(10, (i) => i + 1).map((e) {
                          return DropdownMenuItem(value: e, child: Text('تكرار الآية: $e مرات'));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _verseRepetitions = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _rangeRepetitions,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1E1E1E),
                        items: List.generate(10, (i) => i + 1).map((e) {
                          return DropdownMenuItem(
                            value: e,
                            child: Text(
                              'تكرار النطاق: $e مرات',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _rangeRepetitions = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'القارئ المختار للتلاوة',
              style: TextStyle(color: Color(0xFFC19A6B), fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _selectedReciterId,
              dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey[200],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15),
              items: const [
                DropdownMenuItem(value: 7, child: Text('مشاري العفاسي')),
                DropdownMenuItem(value: 6, child: Text('محمود الحصري')),
                DropdownMenuItem(value: 2, child: Text('عبد الباسط عبد الصمد')),
                DropdownMenuItem(value: 9, child: Text('محمد صديق المنشاوي')),
              ],
              onChanged: (val) async {
                if (val != null) {
                  setState(() {
                    _selectedReciterId = val;
                  });
                  await Locator.storage.setSelectedReciterId(val);
                  if (val != 6) {
                    await Locator.storage.setSelectedStyle('murattal');
                    setState(() {
                      _selectedStyle = 'murattal';
                    });
                  }
                }
              },
            ),
            if (_selectedReciterId == 6) ...[
              const SizedBox(height: 16),
              const Text(
                'رواية/أسلوب التلاوة',
                style: TextStyle(color: Color(0xFFC19A6B), fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedStyle,
                dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey[200],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15),
                items: const [
                  DropdownMenuItem(value: 'murattal', child: Text('مرتّل')),
                  DropdownMenuItem(value: 'mujawwad', child: Text('معلّم')),
                ],
                onChanged: (val) async {
                  if (val != null) {
                    setState(() {
                      _selectedStyle = val;
                    });
                    await Locator.storage.setSelectedStyle(val);
                  }
                },
              ),
            ],
            const SizedBox(height: 32),
            
            // Start Hifz Workspace button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC19A6B),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              icon: const Icon(Icons.play_arrow, color: Colors.white),
              label: const Text('ابدأ حلقة الحفظ والتركيز', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              onPressed: _startHifz,
            ),
          ],
        ),
      ),
    );
  }
}
