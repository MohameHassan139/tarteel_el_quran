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
  
  // Reactive states for UI updates
  final Rxn<Chapter> activeChapter = Rxn<Chapter>();
  final Rxn<String> activeVerseKey = Rxn<String>();
  final RxBool isPlaying = false.obs;
  final RxBool isBuffering = false.obs;
  final Rx<Duration> position = Duration.zero.obs;
  final Rx<Duration> duration = Duration.zero.obs;
  final RxInt verseRepeat = 0.obs;
  final RxInt rangeRepeat = 0.obs;

  StreamSubscription? _playerStateSub;
  StreamSubscription? _currentIndexSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;

  // Hifz looping runtime state
  HifzLoopConfig? _loopConfig;
  int _currentVerseRepeatCount = 0;
  int _currentRangeRepeatCount = 0;
  int? _lastTrackedIndex;
  bool _isCompleted = false;

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  Future<void> Function()? onChapterFinished;

  void _init() {
    _playerStateSub = _player.playerStateStream.listen((state) {
      isPlaying.value = state.playing;
      isBuffering.value = state.processingState == ProcessingState.buffering ||
                          state.processingState == ProcessingState.loading;

      if (state.processingState == ProcessingState.completed) {
        if (!_isCompleted) {
          _isCompleted = true;
          _handlePlaybackCompleted();
        }
      }
    });

    _currentIndexSub = _player.currentIndexStream.listen((index) {
      if (index != null && _activeChapter != null) {
        _updateActiveVerse(index);
      }
    });

    _positionSub = _player.positionStream.listen((pos) {
      position.value = pos;
    });

    _durationSub = _player.durationStream.listen((dur) {
      if (dur != null) {
        duration.value = dur;
      }
    });
  }

  void _handlePlaybackCompleted() {
    if (onChapterFinished != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        onChapterFinished?.call();
      });
    }
  }

  Chapter? get currentActiveChapterRaw => _activeChapter;
  AudioPlayer get player => _player;

  /// Start playing a Surah.
  /// `audioPathsOrUrls` contains the path/URL for each Ayah.
  Future<void> playSurah(Chapter chapter, List<String> audioPathsOrUrls, {bool clearCompletionCallback = true}) async {
    if (clearCompletionCallback) {
      onChapterFinished = null;
    }
    await stop();
    if (audioPathsOrUrls.isEmpty) return;

    _activeChapter = chapter;
    activeChapter.value = chapter;
    _loopConfig = null;
    _lastTrackedIndex = null;

    final playlist = ConcatenatingAudioSource(
      useLazyPreparation: true,
      children: audioPathsOrUrls.map((path) {
        if (path.startsWith('http')) {
          return AudioSource.uri(Uri.parse(path));
        } else {
          return AudioSource.file(path);
        }
      }).toList(),
    );

    try {
      await _player.setAudioSource(playlist, initialIndex: 0, initialPosition: Duration.zero);
      _isCompleted = false;
      await _player.play();
    } catch (_) {
      rethrow;
    }
  }

  Future<void> playHifz(Chapter chapter, List<String> audioPathsOrUrls, HifzLoopConfig config) async {
    await playSurah(chapter, audioPathsOrUrls);
    _loopConfig = config;
    _currentVerseRepeatCount = 0;
    _currentRangeRepeatCount = 0;
    verseRepeat.value = 0;
    rangeRepeat.value = 0;

    // Seek to the start of the first verse in the range
    final startIndex = _getIndexForKey(config.startVerseKey);
    if (startIndex != -1) {
      await _player.seek(Duration.zero, index: startIndex);
    }
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> resume() async {
    await _player.play();
  }

  Future<void> stop() async {
    _isCompleted = true;
    await _player.stop();
    _activeChapter = null;
    activeChapter.value = null;
    activeVerseKey.value = null;
    _loopConfig = null;
  }

  Future<void> seek(Duration targetPosition) async {
    await _player.seek(targetPosition);
  }

  /// Seek directly to a specific Verse by key.
  Future<void> seekToVerse(String verseKey) async {
    final index = _getIndexForKey(verseKey);
    if (index != -1) {
      await _player.seek(Duration.zero, index: index);
    }
  }

  /// Enable or disable single-ayah repeat mode.
  void setRepeatCurrentAyah(bool enabled) {
    if (enabled) {
      _player.setLoopMode(LoopMode.one);
    } else {
      _player.setLoopMode(LoopMode.off);
    }
  }

  int _getIndexForKey(String key) {
    if (_activeChapter == null) return -1;
    final parts = key.split(':');
    if (parts.length == 2 && parts[0] == _activeChapter!.id.toString()) {
      return int.tryParse(parts[1])! - 1; // 0-based index
    }
    return -1;
  }

  /// Synchronize active verse with play index, and handle looping.
  Future<void> _updateActiveVerse(int currentIndex) async {
    if (_activeChapter == null) return;
    
    final activeKey = '${_activeChapter!.id}:${currentIndex + 1}';
    
    if (activeVerseKey.value != activeKey) {
      activeVerseKey.value = activeKey;
    }

    // Process Hifz Looping if active
    final loop = _loopConfig;
    if (loop != null && loop.isActive && _lastTrackedIndex != currentIndex) {
      final startIndex = _getIndexForKey(loop.startVerseKey);
      final endIndex = _getIndexForKey(loop.endVerseKey);
      
      if (startIndex == -1 || endIndex == -1) return;

      // 1. If position goes beyond the end of the whole range
      if (currentIndex > endIndex) {
        _currentRangeRepeatCount++;
        rangeRepeat.value = _currentRangeRepeatCount;
        if (_currentRangeRepeatCount < loop.rangeRepetitions) {
          // Loop the entire range again
          _currentVerseRepeatCount = 0;
          verseRepeat.value = 0;
          _player.seek(Duration.zero, index: startIndex);
          return;
        } else {
          // Finished all loop iterations
          stop();
          return;
        }
      }

      // 2. Handle single-verse repetitions
      if (_lastTrackedIndex != null && _lastTrackedIndex == currentIndex - 1) {
        // We just advanced to the next track. Let's see if we should repeat the previous track
        if (_currentVerseRepeatCount < loop.verseRepetitions - 1) {
          _currentVerseRepeatCount++;
          verseRepeat.value = _currentVerseRepeatCount;
          _player.seek(Duration.zero, index: _lastTrackedIndex);
          return; // Don't update lastTrackedIndex so we repeat
        } else {
          // Finished repeating this verse, move on.
          _currentVerseRepeatCount = 0;
          verseRepeat.value = 0;
        }
      } else if (_lastTrackedIndex != currentIndex) {
         _currentVerseRepeatCount = 0;
         verseRepeat.value = 0;
      }
      _lastTrackedIndex = currentIndex;
    } else {
      _lastTrackedIndex = currentIndex;
    }
  }

  @override
  void onClose() {
    _playerStateSub?.cancel();
    _currentIndexSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _player.dispose();
    super.onClose();
  }
}
