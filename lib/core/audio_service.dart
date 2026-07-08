import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:get/get.dart';
import 'storage_service.dart';
import '../models.dart';

class HifzLoopConfig {
  final String startVerseKey;
  final String endVerseKey;
  final int verseRepetitions; // Repeat each verse X times
  final int rangeRepetitions; // Repeat the whole range Y times
  
  HifzLoopConfig({
    required this.startVerseKey,
    required this.endVerseKey,
    this.verseRepetitions = 1,
    this.rangeRepetitions = 1,
  });

  bool get isActive => startVerseKey.isNotEmpty;
}

class AudioService extends GetxService {
  final StorageService _storageService = Get.find<StorageService>();
  final AudioPlayer _player = AudioPlayer();

  Chapter? _activeChapter;
  List<VerseTiming> _timings = [];
  
  // Reactive states for UI updates
  final Rxn<Chapter> activeChapter = Rxn<Chapter>();
  final Rxn<String> activeVerseKey = Rxn<String>();
  final RxBool isPlaying = false.obs;
  final Rx<Duration> position = Duration.zero.obs;
  final Rx<Duration> duration = Duration.zero.obs;
  final RxInt verseRepeat = 0.obs;
  final RxInt rangeRepeat = 0.obs;

  // Single-ayah repeat mode (for mushaf screen)
  bool _repeatSingleAyah = false;
  VerseTiming? _repeatAyahTiming;

  StreamSubscription? _positionSub;
  StreamSubscription? _playerStateSub;
  StreamSubscription? _durationSub;

  // Hifz looping runtime state
  HifzLoopConfig? _loopConfig;
  int _currentVerseRepeatCount = 0;
  int _currentRangeRepeatCount = 0;
  String? _lastTrackedVerseKey;

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  void _init() {
    _playerStateSub = _player.playerStateStream.listen((state) {
      isPlaying.value = state.playing;
    });

    _positionSub = _player.positionStream.listen((pos) {
      position.value = pos;
      _updateActiveVerse(pos);
    });

    _durationSub = _player.durationStream.listen((dur) {
      if (dur != null) {
        duration.value = dur;
      }
    });
  }

  Chapter? get currentActiveChapterRaw => _activeChapter;
  AudioPlayer get player => _player;

  /// Start playing a Surah either from local file (if downloaded) or streaming.
  Future<void> playSurah(Chapter chapter, String? streamUrl, List<VerseTiming> timings) async {
    await stop();
    _activeChapter = chapter;
    activeChapter.value = chapter;
    _timings = timings;
    _loopConfig = null;
    _lastTrackedVerseKey = null;

    final reciterId = _storageService.getEffectiveReciterId();
    final localPath = _storageService.getDownloadedAudioPath(reciterId, chapter.id);

    try {
      if (localPath != null) {
        // Play local file
        await _player.setAudioSource(AudioSource.file(localPath));
      } else if (streamUrl != null) {
        // Play online stream
        await _player.setAudioSource(AudioSource.uri(Uri.parse(streamUrl)));
      } else {
        throw Exception('Audio is not downloaded and streaming URL is unavailable.');
      }
      await _player.play();
    } catch (_) {
      rethrow;
    }
  }

  /// Start Hifz mode with specific loop configuration.
  Future<void> playHifz(Chapter chapter, String? streamUrl, List<VerseTiming> timings, HifzLoopConfig config) async {
    await playSurah(chapter, streamUrl, timings);
    _loopConfig = config;
    _currentVerseRepeatCount = 0;
    _currentRangeRepeatCount = 0;
    verseRepeat.value = 0;
    rangeRepeat.value = 0;

    // Seek to the start of the first verse in the range
    final startTiming = _getTimingForKey(config.startVerseKey);
    if (startTiming != null) {
      await _player.seek(Duration(milliseconds: startTiming.timestampFrom));
    }
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> resume() async {
    await _player.play();
  }

  Future<void> stop() async {
    await _player.stop();
    _activeChapter = null;
    activeChapter.value = null;
    activeVerseKey.value = null;
    position.value = Duration.zero;
    duration.value = Duration.zero;
    _loopConfig = null;
  }

  Future<void> seek(Duration targetPosition) async {
    await _player.seek(targetPosition);
  }

  /// Seek directly to a specific VerseTiming (used for previous-ayah button).
  Future<void> seekToTiming(VerseTiming timing) async {
    await _player.seek(Duration(milliseconds: timing.timestampFrom));
  }

  /// Enable or disable single-ayah repeat mode.
  void setRepeatCurrentAyah(bool enabled) {
    _repeatSingleAyah = enabled;
    if (!enabled) _repeatAyahTiming = null;
  }

  VerseTiming? _getTimingForKey(String key) {
    for (var t in _timings) {
      if (t.verseKey == key) return t;
    }
    return null;
  }

  int _getVerseIndex(String key) {
    for (int i = 0; i < _timings.length; i++) {
      if (_timings[i].verseKey == key) return i;
    }
    return -1;
  }

  /// Synchronize active verse with play position, and handle looping.
  Future<void> _updateActiveVerse(Duration currentPosition) async {
    if (_timings.isEmpty) return;
    final ms = currentPosition.inMilliseconds;

    // Find current active verse based on timing
    VerseTiming? activeTiming;
    for (var t in _timings) {
      if (ms >= t.timestampFrom && ms < t.timestampTo) {
        activeTiming = t;
        break;
      }
    }

    if (activeTiming == null) return;
    final activeKey = activeTiming.verseKey;

    if (activeVerseKey.value != activeKey) {
      activeVerseKey.value = activeKey;

      // Track timing for single-ayah repeat
      if (_repeatSingleAyah) {
        _repeatAyahTiming = activeTiming;
      }
    }

    // Handle single-ayah repeat (mushaf screen)
    if (_repeatSingleAyah && _repeatAyahTiming != null) {
      final repTiming = _repeatAyahTiming!;
      if (ms >= repTiming.timestampTo - 150) {
        await _player.seek(Duration(milliseconds: repTiming.timestampFrom));
        return;
      }
    }

    // Process Hifz Looping if active
    final loop = _loopConfig;
    if (loop != null && loop.isActive) {
      final startIndex = _getVerseIndex(loop.startVerseKey);
      final endIndex = _getVerseIndex(loop.endVerseKey);
      final activeIndex = _getVerseIndex(activeKey);

      if (startIndex == -1 || endIndex == -1 || activeIndex == -1) return;

      // Ensure player remains inside the loop range boundaries
      final startTiming = _timings[startIndex];
      final endTiming = _timings[endIndex];

      // 1. If position goes beyond the end of the whole range
      if (ms >= endTiming.timestampTo) {
        _currentRangeRepeatCount++;
        rangeRepeat.value = _currentRangeRepeatCount;
        if (_currentRangeRepeatCount < loop.rangeRepetitions) {
          // Loop the entire range again
          _currentVerseRepeatCount = 0;
          verseRepeat.value = 0;
          _player.seek(Duration(milliseconds: startTiming.timestampFrom));
          return;
        } else {
          // Finished all loop iterations
          stop();
          return;
        }
      }

      // 2. Handle single-verse repetitions
      if (_lastTrackedVerseKey != activeKey) {
        // Position changed to a new verse, reset verse repeat counter
        _lastTrackedVerseKey = activeKey;
        _currentVerseRepeatCount = 0;
        verseRepeat.value = 0;
      }

      // If active verse is within range, check if it reached the end of its duration
      final currentTiming = _timings[activeIndex];
      // We give a small buffer (e.g. 150ms) to seek back smoothly before transition
      if (ms >= currentTiming.timestampTo - 200) {
        if (_currentVerseRepeatCount < loop.verseRepetitions - 1) {
          _currentVerseRepeatCount++;
          verseRepeat.value = _currentVerseRepeatCount;
          _player.seek(Duration(milliseconds: currentTiming.timestampFrom));
        }
      }
    }
  }

  @override
  void onClose() {
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    _durationSub?.cancel();
    _player.dispose();
    super.onClose();
  }
}
