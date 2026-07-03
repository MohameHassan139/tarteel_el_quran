import 'dart:async';
import 'package:flutter/material.dart';
import '../../models.dart';
import '../../core/api_service.dart';
import '../../main.dart'; // To get Locator
import '../widgets/bottom_player.dart';

class AudioHubScreen extends StatefulWidget {
  const AudioHubScreen({super.key});

  @override
  State<AudioHubScreen> createState() => _AudioHubScreenState();
}

class _AudioHubScreenState extends State<AudioHubScreen> {
  List<Chapter> _chapters = [];
  List<Chapter> _filteredChapters = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final TextEditingController _searchController = TextEditingController();

  // Bulk Downloading state
  bool _isBulkDownloading = false;
  int _bulkDownloadId = 0; // The Surah ID currently downloading in the bulk process

  @override
  void initState() {
    super.initState();
    _loadChapters();
    _searchController.addListener(_filterChapters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadChapters() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final chapters = await Locator.api.fetchChapters();
      setState(() {
        _chapters = chapters;
        _filteredChapters = chapters;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'فشل الاتصال بالخادم وتحميل السور: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _filterChapters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredChapters = _chapters.where((chapter) {
        return chapter.nameSimple.toLowerCase().contains(query) ||
            chapter.nameArabic.contains(query) ||
            chapter.translatedName.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _handleDownload(Chapter chapter) async {
    final storage = Locator.storage;
    final download = Locator.download;
    final api = Locator.api;
    final reciterId = storage.getEffectiveReciterId();
    final isDownloaded = storage.isChapterDownloaded(reciterId, chapter.id);

    if (isDownloaded) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('حذف الصوت', style: TextStyle(color: Colors.white)),
          content: Text(
            'هل أنت متأكد من حذف الملف الصوتي لسورة ${chapter.nameSimple}؟',
            style: const TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.pop(context, false),
            ),
            TextButton(
              child: const Text('حذف', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await download.deleteChapter(reciterId, chapter.id);
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف الملف الصوتي لسورة ${chapter.nameSimple}'),
            backgroundColor: Colors.grey[800],
          ),
        );
      }
    } else {
      try {
        final audioData = await api.fetchChapterAudioAndTimings(reciterId, chapter.id);
        final audioUrl = audioData['audio_url'] as String?;
        if (audioUrl == null) throw Exception('رابط التحميل غير متوفر.');

        await download.downloadChapter(reciterId, chapter.id, audioUrl);
        setState(() {});
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل التحميل: ${e.toString()}'),
            backgroundColor: Colors.red[800],
          ),
        );
      }
    }
  }

  // Sequential Bulk Downloader
  Future<void> _startBulkDownload() async {
    setState(() {
      _isBulkDownloading = true;
    });

    final storage = Locator.storage;
    final download = Locator.download;
    final api = Locator.api;
    final reciterId = storage.getEffectiveReciterId();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('بدء تحميل كافة السور لهذا القارئ في الخلفية...'),
        duration: Duration(seconds: 3),
      ),
    );

    for (int i = 0; i < _chapters.length; i++) {
      if (!_isBulkDownloading) break; // Bulk process cancelled
      final chapter = _chapters[i];
      final isDownloaded = storage.isChapterDownloaded(reciterId, chapter.id);

      if (!isDownloaded) {
        setState(() {
          _bulkDownloadId = chapter.id;
        });

        try {
          final audioData = await api.fetchChapterAudioAndTimings(reciterId, chapter.id);
          final audioUrl = audioData['audio_url'] as String?;
          if (audioUrl != null) {
            await download.downloadChapter(reciterId, chapter.id, audioUrl);
          }
        } catch (e) {
          debugPrint('Bulk download error for chapter ${chapter.id}: $e');
        }
      }
    }

    if (mounted) {
      setState(() {
        _isBulkDownloading = false;
        _bulkDownloadId = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اكتمل تحميل جميع سور القارئ المختار! 🎉'),
          backgroundColor: Color(0xFFC19A6B),
        ),
      );
    }
  }

  void _cancelBulkDownload() {
    setState(() {
      _isBulkDownloading = false;
      _bulkDownloadId = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم إيقاف عملية التحميل الجماعي.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _deleteAllAudio() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('حذف جميع التلاوات', style: TextStyle(color: Colors.white)),
        content: const Text(
          'هل أنت متأكد من حذف كافة الملفات الصوتية المخزنة لهذا القارئ؟',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: const Text('حذف الكل', style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final storage = Locator.storage;
      final download = Locator.download;
      final reciterId = storage.getEffectiveReciterId();

      setState(() {
        _isLoading = true;
      });

      for (var chapter in _chapters) {
        if (storage.isChapterDownloaded(reciterId, chapter.id)) {
          await download.deleteChapter(reciterId, chapter.id);
        }
      }

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إفراغ التلاوات المخزنة بالكامل.'),
          backgroundColor: Colors.grey,
        ),
      );
    }
  }

  Future<void> _playSurah(Chapter chapter) async {
    final storage = Locator.storage;
    final api = Locator.api;
    final audio = Locator.audio;
    final reciterId = storage.getEffectiveReciterId();

    final isDownloaded = storage.isChapterDownloaded(reciterId, chapter.id);
    List<VerseTiming> timings = [];
    String? audioUrl;

    if (isDownloaded) {
      final cached = storage.getCachedTimings(reciterId, chapter.id);
      if (cached != null) {
        timings = cached;
      }
      try {
        await audio.playSurah(chapter, null, timings);
        return;
      } catch (_) {
        // Fallback to online if local load fails
      }
    }

    try {
      final audioData = await api.fetchChapterAudioAndTimings(reciterId, chapter.id);
      audioUrl = audioData['audio_url'] as String?;
      timings = audioData['timings'] as List<VerseTiming>? ?? [];
      await audio.playSurah(chapter, audioUrl, timings);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل تشغيل الصوت: ${e.toString()}'),
          backgroundColor: Colors.red[800],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Locator.storage.isDarkMode();
    final baseReciterId = Locator.storage.getSelectedReciterId();
    final reciterId = Locator.storage.getEffectiveReciterId();

    return Scaffold(
      appBar: AppBar(
        title: const Text('مكتبة الاستماع والتحميل', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[200],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'القارئ والأسلوب:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                DropdownButton<int>(
                                  value: baseReciterId,
                                  dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black87,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'system-ui',
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 7, child: Text('مشاري العفاسي')),
                                    DropdownMenuItem(value: 6, child: Text('محمود الحصري')),
                                    DropdownMenuItem(value: 2, child: Text('عبد الباسط عبد الصمد')),
                                    DropdownMenuItem(value: 9, child: Text('محمد صديق المنشاوي')),
                                  ],
                                  onChanged: (val) async {
                                    if (val != null) {
                                      await Locator.storage.setSelectedReciterId(val);
                                      if (val == 7) {
                                        await Locator.storage.setSelectedStyle('murattal');
                                      }
                                      setState(() {});
                                    }
                                  },
                                ),
                                if (baseReciterId != 7) ...[
                                  const SizedBox(width: 8),
                                  DropdownButton<String>(
                                    value: Locator.storage.getSelectedStyle(),
                                    dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                    style: TextStyle(
                                      color: isDark ? Colors.white : Colors.black87,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    items: baseReciterId == 6
                                        ? const [
                                            DropdownMenuItem(value: 'murattal', child: Text('مرتّل')),
                                            DropdownMenuItem(value: 'mujawwad', child: Text('معلّم')),
                                          ]
                                        : const [
                                            DropdownMenuItem(value: 'murattal', child: Text('مرتّل')),
                                            DropdownMenuItem(value: 'mujawwad', child: Text('مجوّد')),
                                          ],
                                    onChanged: (val) async {
                                      if (val != null) {
                                        await Locator.storage.setSelectedStyle(val);
                                        setState(() {});
                                        String styleAr = '';
                                        if (baseReciterId == 6) {
                                          styleAr = val == 'mujawwad' ? 'معلّم' : 'مرتّل';
                                        } else {
                                          styleAr = val == 'mujawwad' ? 'مجوّد' : 'مرتّل';
                                        }
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('تم اختيار أسلوب التلاوة: $styleAr'),
                                            backgroundColor: const Color(0xFFC19A6B),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _isBulkDownloading
                                  ? ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[850]),
                                      icon: const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      ),
                                      label: Text('إيقاف ($bulkProgressString)'),
                                      onPressed: _cancelBulkDownload,
                                    )
                                  : ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC19A6B)),
                                      icon: const Icon(Icons.download, color: Colors.white),
                                      label: const Text('تحميل الكل', style: TextStyle(color: Colors.white)),
                                      onPressed: _chapters.isEmpty ? null : _startBulkDownload,
                                    ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[900]),
                              icon: const Icon(Icons.delete_sweep, color: Colors.white),
                              label: const Text('حذف الكل', style: TextStyle(color: Colors.white)),
                              onPressed: _chapters.isEmpty || _isBulkDownloading ? null : _deleteAllAudio,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'ابحث عن السورة للاستماع إليها...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFFC19A6B)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey[200],
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC19A6B)),
                        ),
                      )
                    : _errorMessage.isNotEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
                                  const SizedBox(height: 16),
                                  Text(_errorMessage, style: const TextStyle(color: Colors.grey)),
                                  const SizedBox(height: 20),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC19A6B)),
                                    onPressed: _loadChapters,
                                    child: const Text('إعادة المحاولة', style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _filteredChapters.length,
                            padding: const EdgeInsets.fromLTRB(0, 8, 0, 110), // Room for bottom player
                            separatorBuilder: (context, index) => Divider(
                              height: 1,
                              color: isDark ? Colors.grey[900] : Colors.grey[300],
                            ),
                            itemBuilder: (context, index) {
                              final chapter = _filteredChapters[index];
                              final isDownloaded = Locator.storage.isChapterDownloaded(reciterId, chapter.id);
                              final isCurrentBulk = _isBulkDownloading && _bulkDownloadId == chapter.id;

                              return ListTile(
                                leading: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFC19A6B).withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${chapter.id}',
                                      style: const TextStyle(
                                        color: Color(0xFFC19A6B),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Text(chapter.nameSimple, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    Text(
                                      '(${chapter.versesCount} آيات)',
                                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                    ),
                                  ],
                                ),
                                subtitle: Text(chapter.nameArabic, style: const TextStyle(fontFamily: 'UthmanicHafs', fontSize: 16, color: Color(0xFFC19A6B))),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Listen Play button
                                    IconButton(
                                      icon: const Icon(Icons.play_circle_fill, color: Color(0xFFC19A6B), size: 30),
                                      onPressed: () => _playSurah(chapter),
                                    ),
                                    const SizedBox(width: 8),
                                    // Individual Download Action
                                    StreamBuilder<Map<String, double>>(
                                      stream: Locator.download.progressStream,
                                      builder: (context, snapshot) {
                                        final progressMap = snapshot.data ?? {};
                                        final progress = progressMap['${reciterId}_${chapter.id}'];

                                        if (progress != null || isCurrentBulk) {
                                          return SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              value: progress,
                                              strokeWidth: 3,
                                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFC19A6B)),
                                            ),
                                          );
                                        }

                                        if (isDownloaded) {
                                          return const SizedBox.shrink();
                                        }

                                        return IconButton(
                                          icon: const Icon(
                                            Icons.download_for_offline_outlined,
                                            color: Colors.grey,
                                          ),
                                          onPressed: () => _handleDownload(chapter),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
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

  String get bulkProgressString {
    if (_bulkDownloadId == 0) return '0%';
    final currentCh = _chapters.firstWhere((c) => c.id == _bulkDownloadId, orElse: () => _chapters.first);
    final completed = _chapters.indexOf(currentCh);
    final percentage = ((completed / _chapters.length) * 100).toInt();
    return '$percentage%';
  }
}
