import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/audio_service.dart';
import '../../core/storage_service.dart';
import '../../core/surah_display.dart';
import 'widgets/tranquil_animated_background.dart';
import 'widgets/audio_pulsing_visualizer.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  final AudioService _audio = Get.find<AudioService>();
  final StorageService _storage = Get.find<StorageService>();
  final GlobalKey<TranquilAnimatedBackgroundState> _bgKey = GlobalKey<TranquilAnimatedBackgroundState>();

  Timer? _sleepTimer;
  int? _sleepTimerMinutesRemaining;
  Timer? _autoRandomBgTimer;
  int? _lastChapterId;

  @override
  void initState() {
    super.initState();
    _lastChapterId = _audio.activeChapter.value?.id;

    // Optional subtle auto-rotation of background every 75 seconds for natural variety
    _autoRandomBgTimer = Timer.periodic(const Duration(seconds: 75), (_) {
      if (mounted && _audio.isPlaying.value) {
        _bgKey.currentState?.nextRandomBackground();
      }
    });
  }

  String _formatDuration(Duration duration) {
    final int hours = duration.inHours;
    final int minutes = duration.inMinutes.remainder(60);
    final int seconds = duration.inSeconds.remainder(60);

    final String minStr = minutes.toString().padLeft(2, '0');
    final String secStr = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:$minStr:$secStr';
    }
    return '$minStr:$secStr';
  }

  void _showSleepTimerModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final options = [
          {'title': 'إيقاف المؤقت', 'minutes': 0},
          {'title': '15 دقيقة', 'minutes': 15},
          {'title': '30 دقيقة', 'minutes': 30},
          {'title': '45 دقيقة', 'minutes': 45},
          {'title': '60 دقيقة', 'minutes': 60},
        ];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.bedtime_rounded, color: Color(0xFFD4AF37), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'مؤقت النوم',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...options.map((opt) {
                  final mins = opt['minutes'] as int;
                  final isCurrent = mins == 0
                      ? (_sleepTimer == null)
                      : (_sleepTimerMinutesRemaining == mins);

                  return ListTile(
                    onTap: () {
                      _setSleepTimer(mins);
                      Navigator.pop(ctx);
                    },
                    leading: Icon(
                      mins == 0 ? Icons.timer_off_outlined : Icons.timer_outlined,
                      color: isCurrent ? const Color(0xFFD4AF37) : Colors.white60,
                    ),
                    title: Text(
                      opt['title'] as String,
                      style: TextStyle(
                        color: isCurrent ? Colors.white : Colors.white70,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: isCurrent
                        ? const Icon(Icons.check, color: Color(0xFFD4AF37))
                        : null,
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    if (minutes <= 0) {
      setState(() {
        _sleepTimer = null;
        _sleepTimerMinutesRemaining = null;
      });
      Get.snackbar(
        'مؤقت النوم',
        'تم إيقاف مؤقت النوم',
        backgroundColor: Colors.black87,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() {
      _sleepTimerMinutesRemaining = minutes;
    });

    _sleepTimer = Timer(Duration(minutes: minutes), () {
      _audio.pause();
      setState(() {
        _sleepTimer = null;
        _sleepTimerMinutesRemaining = null;
      });
      Get.snackbar(
        'مؤقت النوم',
        'تم إيقاف التلاوة بحسب مؤقت النوم',
        backgroundColor: Colors.black87,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    });

    Get.snackbar(
      'مؤقت النوم',
      'سيتم إيقاف التلاوة بعد $minutes دقيقة',
      backgroundColor: Colors.black87,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void _cyclePlaybackSpeed() {
    final speeds = [1.0, 1.25, 1.5, 1.75, 2.0, 0.75];
    final current = _audio.playbackSpeed.value;
    final nextIndex = (speeds.indexOf(current) + 1) % speeds.length;
    _audio.setPlaybackSpeed(speeds[nextIndex]);
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _autoRandomBgTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Get.locale?.languageCode == 'ar';

    return Obx(() {
      final isPlaying = _audio.isPlaying.value;
      final isBuffering = _audio.isBuffering.value;
      final chapter = _audio.activeChapter.value;

      // Auto-shuffle background when surah changes
      if (chapter != null && chapter.id != _lastChapterId) {
        _lastChapterId = chapter.id;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _bgKey.currentState?.nextRandomBackground();
        });
      }

      final reciterName = _audio.currentReciterName.value ??
          _audio.customSubtitle.value ??
          'قارئ القرآن الكريم';
      final moshafName = _audio.currentMoshafName.value ??
          (isAr ? 'المصحف المرتل' : 'Holy Quran Recitation');

      final surahTitle = _audio.customTitle.value ??
          (chapter != null
              ? (isAr
                  ? 'سورة ${SurahDisplay.stripArabicSurahPrefix(chapter.nameArabic)}'
                  : chapter.nameSimple)
              : 'ترتيل القرآن');

      final pos = _audio.position.value;
      final dur = _audio.duration.value;
      final double sliderMax = dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1.0;
      final double sliderVal = pos.inMilliseconds.toDouble().clamp(0.0, sliderMax);

      return Scaffold(
        body: TranquilAnimatedBackground(
          key: _bgKey,
          child: SafeArea(
            child: Column(
              children: [
                // Top Navigation Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 34),
                        tooltip: 'رجوع',
                        onPressed: () => Get.back(),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            const Text(
                              'مشغل التلاوة والسكينة',
                              style: TextStyle(
                                color: Color(0xFFD4AF37),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              moshafName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Shuffle Random Background Button
                      IconButton(
                        icon: const Icon(Icons.shuffle_rounded, color: Colors.white70, size: 22),
                        tooltip: 'تغيير الخلفية عشوائياً',
                        onPressed: () {
                          _bgKey.currentState?.nextRandomBackground();
                          Get.snackbar(
                            'خلفية متحركة',
                            'تم تبديل المشهد البحري عشوائياً',
                            backgroundColor: Colors.black87,
                            colorText: Colors.white,
                            duration: const Duration(seconds: 1),
                            snackPosition: SnackPosition.TOP,
                          );
                        },
                      ),
                      // Sleep Timer Button
                      IconButton(
                        icon: Icon(
                          _sleepTimer != null ? Icons.bedtime_rounded : Icons.bedtime_outlined,
                          color: _sleepTimer != null ? const Color(0xFFD4AF37) : Colors.white70,
                          size: 24,
                        ),
                        tooltip: 'مؤقت النوم',
                        onPressed: () => _showSleepTimerModal(context),
                      ),
                    ],
                  ),
                ),

                // Center Circle & Visualizer (Compact & Elegant)
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Concentric sound wave visualizer + compact circular medallion
                          AudioPulsingVisualizer(
                            reciterName: reciterName,
                            isPlaying: isPlaying,
                            circleDiameter: 138, // Compact size
                          ),
                          const SizedBox(height: 22),

                          // Surah Name with Uthmanic Font & Gold Glow
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              surahTitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'UthmanicHafs',
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Color(0xFFD4AF37),
                                    blurRadius: 18,
                                  ),
                                  Shadow(
                                    color: Colors.black,
                                    blurRadius: 12,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Sheikh / Reciter Name
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              reciterName,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.92),
                                shadows: const [
                                  Shadow(color: Colors.black, blurRadius: 8),
                                ],
                              ),
                            ),
                          ),

                          // Live Ayah or Subtitle
                          if (_audio.activeVerseKey.value != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFD4AF37).withOpacity(0.4),
                                ),
                              ),
                              child: Text(
                                _audio.activeVerseKey.value!,
                                style: const TextStyle(
                                  color: Color(0xFFFDE68A),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // Persistent Playback Bar at the bottom (الشريط بتاع التشغيل تحت)
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withOpacity(0.12),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Seek Slider
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3.5,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.5),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                          activeTrackColor: const Color(0xFF38BDF8),
                          inactiveTrackColor: Colors.white24,
                          thumbColor: const Color(0xFFD4AF37),
                          overlayColor: const Color(0xFFD4AF37).withOpacity(0.2),
                        ),
                        child: Slider(
                          value: sliderVal,
                          min: 0.0,
                          max: sliderMax,
                          onChanged: (val) {
                            _audio.seek(Duration(milliseconds: val.toInt()));
                          },
                        ),
                      ),

                      // Time Display (Elapsed / Total)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(pos),
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            Text(
                              _formatDuration(dur),
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Primary Playback Controls Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Previous Surah
                          IconButton(
                            icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 34),
                            tooltip: 'السورة السابقة',
                            onPressed: () {
                              _audio.playPreviousSurah();
                              _bgKey.currentState?.nextRandomBackground();
                            },
                          ),
                          const SizedBox(width: 8),

                          // Rewind 10 Seconds
                          IconButton(
                            icon: const Icon(Icons.replay_10_rounded, color: Colors.white70, size: 28),
                            tooltip: 'تأخير 10 ثوانٍ',
                            onPressed: () => _audio.skipBackward(10),
                          ),
                          const SizedBox(width: 14),

                          // Main Play / Pause Button with Buffering state
                          GestureDetector(
                            onTap: () {
                              if (isPlaying) {
                                _audio.pause();
                              } else {
                                _audio.resume();
                              }
                            },
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFE5C07B),
                                    Color(0xFFD4AF37),
                                    Color(0xFF996515),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFD4AF37).withOpacity(0.4),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: isBuffering
                                    ? const SizedBox(
                                        width: 26,
                                        height: 26,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 3,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                                        ),
                                      )
                                    : Icon(
                                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                        color: Colors.black87,
                                        size: 40,
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Forward 10 Seconds
                          IconButton(
                            icon: const Icon(Icons.forward_10_rounded, color: Colors.white70, size: 28),
                            tooltip: 'تقديم 10 ثوانٍ',
                            onPressed: () => _audio.skipForward(10),
                          ),
                          const SizedBox(width: 8),

                          // Next Surah
                          IconButton(
                            icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 34),
                            tooltip: 'السورة التالية',
                            onPressed: () {
                              _audio.playNextSurah();
                              _bgKey.currentState?.nextRandomBackground();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Secondary Controls Row: Speed & Continuous Play
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Playback Speed Button
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              backgroundColor: Colors.white.withOpacity(0.12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: _cyclePlaybackSpeed,
                            child: Text(
                              '${_audio.playbackSpeed.value}x',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),

                          // Continuous Play Toggle
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              backgroundColor: _storage.getAudioHubPlayAll()
                                  ? const Color(0xFFD4AF37).withOpacity(0.25)
                                  : Colors.white.withOpacity(0.10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () {
                              final current = _storage.getAudioHubPlayAll();
                              _storage.setAudioHubPlayAll(!current);
                              setState(() {});
                            },
                            icon: Icon(
                              Icons.repeat_rounded,
                              size: 16,
                              color: _storage.getAudioHubPlayAll()
                                  ? const Color(0xFFD4AF37)
                                  : Colors.white70,
                            ),
                            label: Text(
                              _storage.getAudioHubPlayAll() ? 'تشغيل متتالي' : 'سورة واحدة',
                              style: TextStyle(
                                fontSize: 12,
                                color: _storage.getAudioHubPlayAll()
                                    ? Colors.white
                                    : Colors.white70,
                              ),
                            ),
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
      );
    });
  }
}
