import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:audio_session/audio_session.dart';
import 'storage_service.dart';
import 'api_service.dart';
import 'teacher_sync_service.dart';
import 'reminder_service.dart';
import 'surah_display.dart';
import '../models.dart';
import 'package:quran_library/quran_library.dart' hide AudioService;

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

class AudioService extends GetxService {
  final StorageService _storageService = Get.find<StorageService>();
  final AudioPlayer _player = AudioPlayer();

  Chapter? _activeChapter;
  
  // Reactive states for UI updates
  final Rxn<Chapter> activeChapter = Rxn<Chapter>();
  final Rxn<String> activeVerseKey = Rxn<String>();
  final RxBool isPlaying = false.obs;
  final RxBool isBuffering = false.obs;
  final RxBool isAudioHubPlayback = false.obs;
  final Rx<Duration> position = Duration.zero.obs;
  final Rx<Duration> duration = Duration.zero.obs;
  final RxInt verseRepeat = 0.obs;
  final RxInt rangeRepeat = 0.obs;

  // Custom / Rare Recitations playback state
  final Rxn<String> customId = Rxn<String>();
  final Rxn<String> customTitle = Rxn<String>();
  final Rxn<String> customSubtitle = Rxn<String>();
  final Rxn<String> customAudioUrl = Rxn<String>();

  // Hifz delay reactive states
  final RxBool isWaitingDelay = false.obs;
  final RxInt delayCountdown = 0.obs;

  /// Flips to true only when a Hifz loop ran through every verse and range
  /// repetition (as opposed to being stopped by the user or replaced).
  final RxBool hifzLoopFinished = false.obs;

  StreamSubscription? _playerStateSub;
  StreamSubscription? _currentIndexSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _interruptionSub;
  StreamSubscription? _becomingNoisySub;

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

  // Audio Hub listening-time tracking (see _startListeningTicker below).
  Timer? _listeningTimer;
  int _audioListeningElapsedSeconds = 0;
  bool _audioLiveActivityActive = false;

  /// The ayah number (1-based, within the active Hifz range) the student
  /// actually reached — not the planned end. Must be read before `stop()`
  /// resets the internal Hifz state (i.e. before `stopHifz()` is called).
  int? get hifzReachedAyahNumber {
    if (!isHifzMode || _hifzAudioPathsOrUrls.isEmpty) return null;
    return _hifzCurrentIndex + 1;
  }

  @override
  void onInit() {
    super.onInit();
    _init();
    _initAudioSession();
    _startListeningTicker();
  }

  @override
  void onClose() {
    _playerStateSub?.cancel();
    _currentIndexSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _interruptionSub?.cancel();
    _becomingNoisySub?.cancel();
    _delayTimer?.cancel();
    _listeningTimer?.cancel();
    _player.dispose();
    super.onClose();
  }

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));

      // Handle audio interruptions (e.g., incoming phone call vs notification ducking)
      bool playInterrupted = false;
      _interruptionSub = session.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              // Let system duck audio volume during short notifications without pausing
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              if (isPlaying.value) {
                playInterrupted = true;
                pause();
              }
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              break;
            case AudioInterruptionType.pause:
              if (playInterrupted) {
                playInterrupted = false;
                resume();
              }
              break;
            case AudioInterruptionType.unknown:
              break;
          }
        }
      });

      // Handle headphone unplugging
      _becomingNoisySub = session.becomingNoisyEventStream.listen((_) {
        pause();
      });
    } catch (e) {
      debugPrint('AudioSession init error: $e');
    }
  }

  /// Tracks Audio Hub listening time and live activity. `onChapterFinished`
  /// is only ever non-null for continuous Audio Hub playback (see
  /// AudioHubController.playSurah / didChangeAppLifecycleState above), which
  /// is what distinguishes it from a single Mushaf surah or a Hifz loop.
  /// Lives on this permanent singleton (not AudioHubController, which gets
  /// disposed when that screen closes) so it keeps counting in the background.
  void _startListeningTicker() {
    _listeningTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final isAudioHubListening = isPlaying.value && isAudioHubPlayback.value;

      if (!isAudioHubListening) {
        if (_audioLiveActivityActive) {
          _audioLiveActivityActive = false;
          _audioListeningElapsedSeconds = 0;
          if (Get.isRegistered<TeacherSyncService>()) {
            final sync = Get.find<TeacherSyncService>();
            if (sync.isStudent) unawaited(sync.clearLiveActivity());
          }
        }
        return;
      }

      _audioListeningElapsedSeconds++;
      unawaited(_storageService.logAudioListeningSeconds(1));
      if (Get.isRegistered<ReminderService>()) {
        unawaited(Get.find<ReminderService>().logWardProgress(1));
      }

      if (_audioListeningElapsedSeconds % 15 != 0) return;
      _audioLiveActivityActive = true;
      if (!Get.isRegistered<TeacherSyncService>()) return;
      final sync = Get.find<TeacherSyncService>();
      if (!sync.isStudent) return;
      unawaited(sync.setLiveActivity(
        feature: 'audio',
        label: _activeChapter?.nameSimple ?? '',
        elapsedSeconds: _audioListeningElapsedSeconds,
        chapterId: _activeChapter?.id,
      ));
      unawaited(sync.syncTodayActivity());
    });
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
  ///
  /// [keepSessionAlive] skips the full `stop()` teardown and resets state
  /// in place instead. Used when auto-advancing to the next track in a
  /// continuous queue (e.g. Audio Hub), because `stop()` tears down the
  /// just_audio_background media session/foreground notification, and
  /// restarting one from a backgrounded/screen-off state can silently fail
  /// on Android — so the running session must be kept alive across tracks.
  Future<void> playSurah(Chapter chapter, List<String> audioPathsOrUrls, {bool clearCompletionCallback = true, List<MediaItem>? mediaItems, bool keepSessionAlive = false, int initialIndex = 0}) async {
    if (clearCompletionCallback) {
      onChapterFinished = null;
    }
    if (keepSessionAlive) {
      _resetStateForNewSurah();
    } else {
      await stop();
    }
    if (audioPathsOrUrls.isEmpty) return;

    _activeChapter = chapter;
    activeChapter.value = chapter;
    _loopConfig = null;
    _lastTrackedIndex = null;

    final isAr = _storageService.getAppLanguage() == 'ar';

    final playlist = ConcatenatingAudioSource(
      children: List.generate(audioPathsOrUrls.length, (index) {
        final path = audioPathsOrUrls[index];
        final MediaItem tag;
        if (mediaItems != null && index < mediaItems.length) {
          tag = mediaItems[index];
        } else {
          tag = MediaItem(
            id: 'audio_${chapter.id}_$index',
            title: isAr ? 'سورة ${SurahDisplay.stripArabicSurahPrefix(chapter.nameArabic)}' : chapter.nameSimple,
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

    final safeInitialIndex = initialIndex.clamp(0, audioPathsOrUrls.length - 1);

    try {
      await _player.setAudioSource(playlist, initialIndex: safeInitialIndex, initialPosition: Duration.zero);
      _isCompleted = false;
      await _player.play();
    } catch (_) {
      rethrow;
    }
  }

  /// Start Hifz playback loop using the sequential single-item player state machine.
  Future<void> playHifz(Chapter chapter, List<String> audioPathsOrUrls, HifzLoopConfig config) async {
    hifzLoopFinished.value = false;
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
      title: isAr ? 'سورة ${SurahDisplay.stripArabicSurahPrefix(_activeChapter!.nameArabic)}' : _activeChapter!.nameSimple,
      artist: isAr ? 'آية ${_hifzCurrentIndex + 1}' : 'Ayah ${_hifzCurrentIndex + 1}',
      album: isAr ? 'مساحة الحفظ والتركيز' : 'Memorization Workspace',
    );

    final AudioSource source = path.startsWith('http')
        ? AudioSource.uri(Uri.parse(path), tag: tag)
        : AudioSource.file(path, tag: tag);

    _isCompleted = false;
    await _player.setAudioSource(source);
    // just_audio's play() future only completes when playback pauses/ends,
    // so awaiting it would stall callers (startHifz timers, replay) for the
    // whole ayah. Loading errors are already surfaced by setAudioSource.
    unawaited(_player.play().catchError((Object _) {}));
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
          hifzLoopFinished.value = true;
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
    // Set before starting: play()'s future only completes on the NEXT pause,
    // so assigning after `await` used to flip the icon back to "playing"
    // right after the user paused.
    isPlaying.value = true;
    if (isWaitingDelay.value) {
      _startHifzDelayTimer(() {
        _playHifzCurrentAyah();
      });
    } else {
      unawaited(_player.play().catchError((Object _) {}));
    }
  }

  Future<void> playNextMushafSurah() async {
    if (!_storageService.getMushafPlayNext()) return;
    final current = _activeChapter;
    if (current == null) return;

    final nextId = (current.id % 114) + 1;

    Chapter? nextChapter;
    final cached = _storageService.getCachedChapters();
    if (cached != null && cached.isNotEmpty) {
      nextChapter = cached.firstWhereOrNull((c) => c.id == nextId);
    }
    if (nextChapter == null && QuranCtrl.instance.surahsList.isNotEmpty) {
      final s = QuranCtrl.instance.surahsList.firstWhereOrNull((s) => s.number == nextId);
      if (s != null) {
        nextChapter = Chapter(
          id: s.number,
          nameSimple: s.englishName,
          nameComplex: s.englishName,
          nameArabic: s.name,
          versesCount: s.ayahsNumber,
          revelationPlace: s.revelationType,
          revelationOrder: 0,
          translatedName: s.englishNameTranslation,
        );
      }
    }
    if (nextChapter == null) return;

    final reciterId = _storageService.getEffectiveReciterId();
    final isDownloaded = _storageService.isChapterDownloaded(reciterId, nextChapter.id, nextChapter.versesCount);
    List<String> audioUrls = [];
    if (isDownloaded) {
      audioUrls = _storageService.getChapterAudioPathsOrUrls(reciterId, nextChapter.id, nextChapter.versesCount);
    }
    if (audioUrls.isEmpty && Get.isRegistered<ApiService>()) {
      try {
        audioUrls = await Get.find<ApiService>().fetchChapterAudio(reciterId, nextChapter.id);
      } catch (e) {
        debugPrint('playNextMushafSurah error fetching audio: $e');
      }
    }

    if (audioUrls.isEmpty) return;

    isAudioHubPlayback.value = false;
    onChapterFinished = playNextMushafSurah;
    await playSurah(
      nextChapter,
      audioUrls,
      clearCompletionCallback: false,
      keepSessionAlive: true,
    );
  }

  Future<void> stop() async {
    isAudioHubPlayback.value = false;
    _resetStateForNewSurah();
    await _player.stop();
    _activeChapter = null;
    activeChapter.value = null;
    activeVerseKey.value = null;
  }

  /// Resets Dart-side playback bookkeeping without touching the underlying
  /// player/media session. See [playSurah]'s `keepSessionAlive` for why.
  void _resetStateForNewSurah() {
    _isCompleted = true;
    _delayTimer?.cancel();
    isWaitingDelay.value = false;
    delayCountdown.value = 0;
    _loopConfig = null;
    _hifzAudioPathsOrUrls = [];
    customId.value = null;
    customTitle.value = null;
    customSubtitle.value = null;
    customAudioUrl.value = null;
  }

  /// Play a rare recording or external concert recitation track.
  Future<void> playRareRecitation({
    required String id,
    required String title,
    required String reciterName,
    required String audioPathOrUrl,
    String? location,
    Chapter? associatedChapter,
  }) async {
    await stop();
    _loopConfig = null;
    _lastTrackedIndex = null;
    customId.value = id;
    customTitle.value = title;
    customSubtitle.value = reciterName;
    customAudioUrl.value = audioPathOrUrl;

    final isAr = _storageService.getAppLanguage() == 'ar';
    final chapter = associatedChapter ??
        Chapter(
          id: 0,
          nameSimple: title,
          nameComplex: title,
          nameArabic: title,
          versesCount: 1,
          revelationPlace: location ?? '',
          revelationOrder: 0,
          translatedName: reciterName,
        );

    _activeChapter = chapter;
    activeChapter.value = chapter;
    activeVerseKey.value = location ?? (isAr ? 'تسجيل نادر' : 'Rare Recording');

    final mediaItem = MediaItem(
      id: 'rare_$id',
      title: title,
      artist: reciterName,
      album: location ?? (isAr ? 'تلاوات المحافل والنوادر' : 'Rare Concert Recitations'),
    );

    final AudioSource source = audioPathOrUrl.startsWith('http')
        ? AudioSource.uri(Uri.parse(audioPathOrUrl), tag: mediaItem)
        : AudioSource.file(audioPathOrUrl, tag: mediaItem);

    _isCompleted = false;
    await _player.setAudioSource(source);
    await _player.play();
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
    if (_lastTrackedIndex == currentIndex) return;
    _lastTrackedIndex = currentIndex;
    
    final activeKey = '${_activeChapter!.id}:${currentIndex + 1}';
    
    if (activeVerseKey.value != activeKey) {
      activeVerseKey.value = activeKey;
    }
  }
}
