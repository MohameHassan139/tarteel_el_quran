import 'package:flutter/material.dart';
import '../../models.dart';
import '../../core/api_service.dart';
import '../../main.dart'; // To get Locator
import 'mushaf_view_screen.dart';

class MushafScreen extends StatefulWidget {
  const MushafScreen({super.key});

  @override
  State<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends State<MushafScreen> {
  List<Chapter> _chapters = [];
  List<Chapter> _filteredChapters = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final TextEditingController _searchController = TextEditingController();

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
    final reciterId = storage.getSelectedReciterId();

    final isDownloaded = storage.isChapterDownloaded(reciterId, chapter.id);

    if (isDownloaded) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('حذف الصوت', style: TextStyle(color: Colors.white)),
          content: Text(
            'هل أنت متأكد من حذف الملف الصوتي الخاص بسورة ${chapter.nameSimple} من الهاتف؟',
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
        setState(() {}); // Rebuild list to show updated download icon
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف الملف الصوتي لسورة ${chapter.nameSimple}'),
            backgroundColor: Colors.grey[800],
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('جاري بدء تحميل سورة ${chapter.nameSimple}...'),
          duration: const Duration(seconds: 2),
        ),
      );

      try {
        final audioData = await api.fetchChapterAudioAndTimings(reciterId, chapter.id);
        final audioUrl = audioData['audio_url'] as String?;
        if (audioUrl == null) {
          throw Exception('عذراً، لم نتمكن من الحصول على رابط التحميل.');
        }

        await download.downloadChapter(reciterId, chapter.id, audioUrl);
        setState(() {}); // Rebuild to update state
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحميل سورة ${chapter.nameSimple} بنجاح!'),
            backgroundColor: const Color(0xFFC19A6B),
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    final isDark = Locator.storage.isDarkMode();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'المصحف الشريف',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ابحث عن السورة...',
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
                              Text(
                                _errorMessage,
                                style: const TextStyle(color: Colors.grey, fontSize: 16),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFC19A6B),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                onPressed: _loadChapters,
                                child: const Text('إعادة المحاولة', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filteredChapters.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: isDark ? Colors.grey[900] : Colors.grey[300],
                        ),
                        itemBuilder: (context, index) {
                          final chapter = _filteredChapters[index];
                          final storage = Locator.storage;
                          final reciterId = storage.getSelectedReciterId();
                          final isDownloaded = storage.isChapterDownloaded(reciterId, chapter.id);

                          return ListTile(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MushafViewScreen(chapter: chapter),
                                ),
                              ).then((_) {
                                // Rebuild when returning to show downloaded icon if changed
                                setState(() {});
                              });
                            },
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
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  chapter.nameSimple,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '(${chapter.versesCount} آيات)',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              chapter.translatedName,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  chapter.nameArabic,
                                  style: const TextStyle(
                                    fontFamily: 'UthmanicHafs',
                                    fontSize: 20,
                                    color: Color(0xFFC19A6B),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Download progress / trigger button
                                StreamBuilder<Map<String, double>>(
                                  stream: Locator.download.progressStream,
                                  builder: (context, snapshot) {
                                    final progressMap = snapshot.data ?? {};
                                    final progress = progressMap['${reciterId}_${chapter.id}'];

                                    if (progress != null) {
                                      return SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          value: progress,
                                          strokeWidth: 3,
                                          valueColor: const AlwaysStoppedAnimation<Color>(
                                            Color(0xFFC19A6B),
                                          ),
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
    );
  }
}
