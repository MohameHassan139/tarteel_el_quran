import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:get/get.dart';
import 'storage_service.dart';
import '../models.dart';

class HifzLoopConfig {
  final String startVerseKey;
  final String endVerseKey;
  final int verseRepetitions; // Repeat each verse X times
  final int rangeRepetitions; // Repeat the whole range Y times
  final int delaySeconds;      // Delay/silence in seconds between verses
  
  HifzLoopConfig({
    required this.startVerseKey,
    required this.endVerseKey,
    this.verseRepetitions = 1,
    this.rangeRepetitions = 1,
    this.delaySeconds = 0,
  });

  bool get isActive => startVerseKey.isNotEmpty;
}

class AudioService extends GetxService with WidgetsBindingObserver {
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

  // Hifz delay reactive states
  final RxBool isWaitingDelay = false.obs;
  final RxInt delayCountdown = 0.obs;

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

  // Hifz sequential playback tracking
  List<String> _hifzAudioPathsOrUrls = [];
  int _hifzCurrentIndex = 0;
  int _hifzStartIndex = 0;
  int _hifzEndIndex = 0;
  Timer? _delayTimer;

  bool get isHifzMode => _loopConfig != null;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _playerStateSub?.cancel();
    _currentIndexSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _delayTimer?.cancel();
    _player.dispose();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      // If we are NOT in Audio Hub mode, pause the player when app goes to background
      if (onChapterFinished == null) {
        pause();
      }
    }
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
      // Only update active verse from playlist index if not in Hifz mode (which uses single items)
      if (index != null && _activeChapter != null && !isHifzMode) {
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
    if (isHifzMode) {
      _handleHifzAyahCompleted();
    } else if (onChapterFinished != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        onChapterFinished?.call();
      });
    }
  }

  Chapter? get currentActiveChapterRaw => _activeChapter;
  AudioPlayer get player => _player;

  /// Start playing a Surah.
  /// `audioPathsOrUrls` contains the path/URL for each Ayah.
  Future<void> playSurah(Chapter chapter, List<String> audioPathsOrUrls, {bool clearCompletionCallback = true, List<MediaItem>? mediaItems}) async {
    if (clearCompletionCallback) {
      onChapterFinished = null;
    }
    await stop();
    if (audioPathsOrUrls.isEmpty) return;

    _activeChapter = chapter;
    activeChapter.value = chapter;
    _loopConfig = null;
    _lastTrackedIndex = null;

    final isAr = _storageService.getAppLanguage() == 'ar';

    final playlist = ConcatenatingAudioSource(
      useLazyPreparation: true,
      children: List.generate(audioPathsOrUrls.length, (index) {
        final path = audioPathsOrUrls[index];
        final MediaItem tag;
        if (mediaItems != null && index < mediaItems.length) {
          tag = mediaItems[index];
        } else {
          tag = MediaItem(
            id: 'audio_${chapter.id}_$index',
            title: isAr ? 'سورة ${chapter.nameArabic}' : chapter.nameSimple,
            artist: isAr ? 'آية ${index + 1}' : 'Ayah ${index + 1}',
            album: isAr ? 'المصحف الشريف' : 'Holy Quran',
          );
        }

        if (path.startsWith('http')) {
          return AudioSource.uri(Uri.parse(path), tag: tag);
        } else {
          return AudioSource.file(path, tag: tag);
        }
      }),
    );

    try {
      await _player.setAudioSource(playlist, initialIndex: 0, initialPosition: Duration.zero);
      _isCompleted = false;
      await _player.play();
    } catch (_) {
      rethrow;
    }
  }

  /// Start Hifz playback loop using the sequential single-item player state machine.
  Future<void> playHifz(Chapter chapter, List<String> audioPathsOrUrls, HifzLoopConfig config) async {
    await stop();

    _activeChapter = chapter;
    activeChapter.value = chapter;
    _loopConfig = config;
    _hifzAudioPathsOrUrls = audioPathsOrUrls;

    _hifzStartIndex = _getIndexForKey(config.startVerseKey);
    _hifzEndIndex = _getIndexForKey(config.endVerseKey);

    if (_hifzStartIndex == -1 || _hifzEndIndex == -1) {
      await stop();
      return;
    }

    _hifzCurrentIndex = _hifzStartIndex;
    _currentVerseRepeatCount = 0;
    _currentRangeRepeatCount = 0;
    verseRepeat.value = 0;
    rangeRepeat.value = 0;

    isWaitingDelay.value = false;
    delayCountdown.value = 0;
    _delayTimer?.cancel();

    await _playHifzCurrentAyah();
  }

  Future<void> _playHifzCurrentAyah() async {
    if (_activeChapter == null || _loopConfig == null || _hifzAudioPathsOrUrls.isEmpty) return;

    final path = _hifzAudioPathsOrUrls[_hifzCurrentIndex];
    final activeKey = '${_activeChapter!.id}:${_hifzCurrentIndex + 1}';
    activeVerseKey.value = activeKey;

    isWaitingDelay.value = false;
    _delayTimer?.cancel();

    final isAr = _storageService.getAppLanguage() == 'ar';
    final MediaItem tag = MediaItem(
      id: 'hifz_${_activeChapter!.id}_$_hifzCurrentIndex',
      title: isAr ? 'سورة ${_activeChapter!.nameArabic}' : _activeChapter!.nameSimple,
      artist: isAr ? 'آية ${_hifzCurrentIndex + 1}' : 'Ayah ${_hifzCurrentIndex + 1}',
      album: isAr ? 'مساحة الحفظ والتركيز' : 'Memorization Workspace',
    );

    final AudioSource source = path.startsWith('http')
        ? AudioSource.uri(Uri.parse(path), tag: tag)
        : AudioSource.file(path, tag: tag);

    try {
      _isCompleted = false;
      await _player.setAudioSource(source);
      await _player.play();
    } catch (_) {
      rethrow;
    }
  }

  Future<void> _handleHifzAyahCompleted() async {
    final loop = _loopConfig;
    if (loop == null) return;

    _currentVerseRepeatCount++;
    verseRepeat.value = _currentVerseRepeatCount;

    if (_currentVerseRepeatCount < loop.verseRepetitions) {
      // Repeat the current ayah
      if (loop.delaySeconds > 0) {
        await _startHifzDelayTimer(() {
          _playHifzCurrentAyah();
        });
      } else {
        _isCompleted = false;
        await _player.seek(Duration.zero);
        await _player.play();
      }
    } else {
      // Move to the next ayah
      _currentVerseRepeatCount = 0;
      verseRepeat.value = 0;

      if (_hifzCurrentIndex < _hifzEndIndex) {
        _hifzCurrentIndex++;
        if (loop.delaySeconds > 0) {
          await _startHifzDelayTimer(() {
            _playHifzCurrentAyah();
          });
        } else {
          await _playHifzCurrentAyah();
        }
      } else {
        // Completed the range loop
        _currentRangeRepeatCount++;
        rangeRepeat.value = _currentRangeRepeatCount;

        if (_currentRangeRepeatCount < loop.rangeRepetitions) {
          _hifzCurrentIndex = _hifzStartIndex;
          if (loop.delaySeconds > 0) {
            await _startHifzDelayTimer(() {
              _playHifzCurrentAyah();
            });
          } else {
            await _playHifzCurrentAyah();
          }
        } else {
          // Finished all repetitions and ranges
          await stop();
        }
      }
    }
  }

  Future<void> _startHifzDelayTimer(VoidCallback onFinished) async {
    isWaitingDelay.value = true;
    delayCountdown.value = _loopConfig?.delaySeconds ?? 0;

    _delayTimer?.cancel();
    _delayTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (delayCountdown.value > 1) {
        delayCountdown.value--;
      } else {
        timer.cancel();
        isWaitingDelay.value = false;
        delayCountdown.value = 0;
        onFinished();
      }
    });
  }

  Future<void> pause() async {
    if (isWaitingDelay.value) {
      _delayTimer?.cancel();
    } else {
      await _player.pause();
    }
    isPlaying.value = false;
  }

  Future<void> resume() async {
    if (isWaitingDelay.value) {
      _startHifzDelayTimer(() {
        _playHifzCurrentAyah();
      });
    } else {
      await _player.play();
    }
    isPlaying.value = true;
  }

  Future<void> stop() async {
    _isCompleted = true;
    _delayTimer?.cancel();
    isWaitingDelay.value = false;
    delayCountdown.value = 0;
    await _player.stop();
    _activeChapter = null;
    activeChapter.value = null;
    activeVerseKey.value = null;
    _loopConfig = null;
    _hifzAudioPathsOrUrls = [];
  }

  Future<void> seek(Duration targetPosition) async {
    if (!isWaitingDelay.value) {
      await _player.seek(targetPosition);
    }
  }

  /// Seek directly to a specific Verse by key.
  Future<void> seekToVerse(String verseKey) async {
    final index = _getIndexForKey(verseKey);
    if (index != -1) {
      if (isHifzMode) {
        if (index >= _hifzStartIndex && index <= _hifzEndIndex) {
          _hifzCurrentIndex = index;
          _currentVerseRepeatCount = 0;
          verseRepeat.value = 0;
          await _playHifzCurrentAyah();
        }
      } else {
        await _player.seek(Duration.zero, index: index);
      }
    }
  }

  bool get canGoNextHifz => isHifzMode && _hifzCurrentIndex < _hifzEndIndex;
  bool get canGoPrevHifz => isHifzMode && _hifzCurrentIndex > _hifzStartIndex;

  Future<void> playNextHifz() async {
    if (canGoNextHifz) {
      _hifzCurrentIndex++;
      _currentVerseRepeatCount = 0;
      verseRepeat.value = 0;
      await _playHifzCurrentAyah();
    }
  }

  Future<void> playPrevHifz() async {
    if (canGoPrevHifz) {
      _hifzCurrentIndex--;
      _currentVerseRepeatCount = 0;
      verseRepeat.value = 0;
      await _playHifzCurrentAyah();
    }
  }

  /// Enable or disable single-ayah repeat mode (used in normal Mushaf mode).
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

  /// Synchronize active verse with play index (used in normal Mushaf mode).
  Future<void> _updateActiveVerse(int currentIndex) async {
    if (_activeChapter == null) return;
    
    final activeKey = '${_activeChapter!.id}:${currentIndex + 1}';
    
    if (activeVerseKey.value != activeKey) {
      activeVerseKey.value = activeKey;
    }
    _lastTrackedIndex = currentIndex;
  }
}
