import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
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

class AudioService {
  final StorageService _storageService;
  final AudioPlayer _player = AudioPlayer();

  Chapter? _activeChapter;
  List<VerseTiming> _timings = [];
  
  // Notifiers for UI updates
  final ValueNotifier<Chapter?> activeChapterNotifier = ValueNotifier<Chapter?>(null);
  final ValueNotifier<String?> activeVerseKeyNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<Duration> positionNotifier = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration> durationNotifier = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<int> verseRepeatNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> rangeRepeatNotifier = ValueNotifier<int>(0);

  StreamSubscription? _positionSub;
  StreamSubscription? _playerStateSub;
  StreamSubscription? _durationSub;

  // Hifz looping runtime state
  HifzLoopConfig? _loopConfig;
  int _currentVerseRepeatCount = 0;
  int _currentRangeRepeatCount = 0;
  String? _lastTrackedVerseKey;

  AudioService(this._storageService) {
    _init();
  }

  void _init() {
    _playerStateSub = _player.playerStateStream.listen((state) {
      isPlayingNotifier.value = state.playing;
    });

    _positionSub = _player.positionStream.listen((pos) {
      positionNotifier.value = pos;
      _updateActiveVerse(pos);
    });

    _durationSub = _player.durationStream.listen((dur) {
      if (dur != null) {
        durationNotifier.value = dur;
      }
    });
  }

  Chapter? get activeChapter => _activeChapter;
  AudioPlayer get player => _player;

  /// Start playing a Surah either from local file (if downloaded) or streaming.
  Future<void> playSurah(Chapter chapter, String? streamUrl, List<VerseTiming> timings) async {
    await stop();
    _activeChapter = chapter;
    activeChapterNotifier.value = chapter;
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
    verseRepeatNotifier.value = 0;
    rangeRepeatNotifier.value = 0;

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
    activeChapterNotifier.value = null;
    activeVerseKeyNotifier.value = null;
    positionNotifier.value = Duration.zero;
    durationNotifier.value = Duration.zero;
    _loopConfig = null;
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
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
  void _updateActiveVerse(Duration position) {
    if (_timings.isEmpty) return;
    final ms = position.inMilliseconds;

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

    if (activeVerseKeyNotifier.value != activeKey) {
      activeVerseKeyNotifier.value = activeKey;
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
        rangeRepeatNotifier.value = _currentRangeRepeatCount;
        if (_currentRangeRepeatCount < loop.rangeRepetitions) {
          // Loop the entire range again
          _currentVerseRepeatCount = 0;
          verseRepeatNotifier.value = 0;
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
        verseRepeatNotifier.value = 0;
      }

      // If active verse is within range, check if it reached the end of its duration
      final currentTiming = _timings[activeIndex];
      // We give a small buffer (e.g. 150ms) to seek back smoothly before transition
      if (ms >= currentTiming.timestampTo - 200) {
        if (_currentVerseRepeatCount < loop.verseRepetitions - 1) {
          _currentVerseRepeatCount++;
          verseRepeatNotifier.value = _currentVerseRepeatCount;
          _player.seek(Duration(milliseconds: currentTiming.timestampFrom));
        }
      }
    }
  }

  void dispose() {
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    _durationSub?.cancel();
    _player.dispose();
  }
}
