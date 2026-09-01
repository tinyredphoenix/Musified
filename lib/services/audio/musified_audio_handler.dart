// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:musified/main.dart';
import 'package:musified/models/full_player_state.dart';
import 'package:musified/models/position_data.dart';
import 'package:musified/services/audio/audio_browse_catalog.dart';
import 'package:musified/services/audio/audio_completion_coordinator.dart';
import 'package:musified/services/audio/audio_handler_hub.dart';
import 'package:musified/services/audio/audio_playback_coordinator.dart';
import 'package:musified/services/audio/audio_playback_install.dart';
import 'package:musified/services/audio/audio_queue_controller.dart';
import 'package:musified/services/audio/audio_queue_state.dart';
import 'package:musified/services/common_services.dart';

import 'package:musified/services/settings_manager.dart';
import 'package:musified/utilities/app_utils.dart';
import 'package:musified/utilities/flutter_toast.dart';
import 'package:musified/utilities/map_utils.dart';
import 'package:musified/utilities/mediaitem.dart';
import 'package:rxdart/rxdart.dart';

class MusifiedAudioHandler extends BaseAudioHandler {
  MusifiedAudioHandler() {
    audioPlayer = AudioPlayer();
    _playback = AudioPlaybackCoordinator(
      audioPlayer: audioPlayer,
      offlineTransitionTimeout: _offlineTransitionTimeout,
      streamTransitionTimeout: _streamTransitionTimeout,
    );
    _setupEventSubscriptions();
    _updatePlaybackState();
    _initialize();
  }

  late final AudioPlayer audioPlayer;

  Timer? _sleepTimer;
  Timer? _debounceTimer;
  bool sleepTimerExpired = false;
  bool sleepTimerEndOfSong = false;

  final AudioHandlerHub _hub = AudioHandlerHub();
  final AudioCompletionCoordinator _completion = AudioCompletionCoordinator();
  late final AudioPlaybackCoordinator _playback;
  final BehaviorSubject<List<Map>> _queueMapStream =
      BehaviorSubject<List<Map>>.seeded([]);
  int _currentLoadingTransitionId = -1;
  bool _isUpdatingState = false;
  bool _pendingPlaybackStateUpdate = false;
  int _songTransitionCounter = 0;

  bool _isSeeking = false;
  Duration? _pendingSeekPosition;
  bool _wasPlayingBeforeInterruption = false;

  /// Shared playing indicator for list tiles (avoids per-row mediaItem streams).
  final ValueNotifier<String?> currentPlayingYtid = ValueNotifier<String?>(null);
  final ValueNotifier<int> queueItemCount = ValueNotifier<int>(0);
  String? _lastPublishedMediaSignature;

  
  // Resolve only the next item, and never compete with the foreground load.
  // Multiple manifest requests were saturating the connection and making a
  // user-initiated tap wait behind two background YouTube requests.
  static const Duration _offlineTransitionTimeout = Duration(seconds: 6);
  static const Duration _streamTransitionTimeout = Duration(seconds: 12);
  static const Duration _debounceInterval = Duration(milliseconds: 80);
  static const Duration _positionDataThreshold = Duration(milliseconds: 250);
  static const Duration _playbackStateHeartbeat = Duration(seconds: 1);

  // --- Streams / UI combine ---
  late final Stream<PositionData> _positionDataStream =
      Rx.combineLatest4<Duration, Duration, Duration?, MediaItem?, PositionData>(
        audioPlayer.positionStream,
        audioPlayer.bufferedPositionStream,
        audioPlayer.durationStream,
        mediaItem,
        (position, bufferedPosition, playerDuration, item) {
          final catalog = item?.duration ??
              _catalogDurationFromExtras(item?.extras);
          var displayDuration = playerDuration ?? Duration.zero;
          if (catalog != null &&
              catalog > const Duration(seconds: 5) &&
              displayDuration > catalog + const Duration(seconds: 5)) {
            displayDuration = catalog;
          }
          var displayPosition = position;
          if (catalog != null &&
              catalog > Duration.zero &&
              displayPosition > catalog) {
            displayPosition = catalog;
          }
          return PositionData(
            displayPosition,
            bufferedPosition,
            displayDuration,
          );
        },
      ).distinct((prev, curr) {
        return (prev.position - curr.position).abs() < _positionDataThreshold &&
            prev.duration == curr.duration &&
            (prev.bufferedPosition - curr.bufferedPosition).abs() <
                _positionDataThreshold;
      }).asBroadcastStream();

  Stream<PositionData> get positionDataStream => _positionDataStream;

  late final Stream<PlaybackState> _playbackStateStream = playbackState
      .distinct((prev, curr) {
        final prevPositionBucket =
            prev.updatePosition.inMilliseconds ~/
            _positionDataThreshold.inMilliseconds;
        final currPositionBucket =
            curr.updatePosition.inMilliseconds ~/
            _positionDataThreshold.inMilliseconds;
        return prev.playing == curr.playing &&
            prev.processingState == curr.processingState &&
            prev.queueIndex == curr.queueIndex &&
            prev.speed == curr.speed &&
            prevPositionBucket == currPositionBucket;
      })
      .asBroadcastStream();

  Stream<PlaybackState> get playbackStateStream => _playbackStateStream;

  /// Single cached combine so mini-player rebuilds do not recreate subscriptions.
  late final Stream<FullPlayerState> fullPlayerStateStream =
      Rx.combineLatest4(
        playbackStateStream,
        queue.distinct(),
        positionDataStream,
        mediaItem.distinct(
          (prev, next) =>
              prev?.id == next?.id &&
              prev?.artUri == next?.artUri &&
              prev?.title == next?.title,
        ),
        (
          PlaybackState state,
          List<MediaItem> queueItems,
          PositionData pos,
          MediaItem? item,
        ) =>
            FullPlayerState(
              playbackState: state,
              queue: queueItems,
              position: pos,
              mediaItem: item,
            ),
      ).throttleTime(const Duration(milliseconds: 120), trailing: true).asBroadcastStream();

  static const List<MediaControl> _controlsMultiplePlaying = [
    MediaControl.skipToPrevious,
    MediaControl.pause,
    MediaControl.stop,
    MediaControl.skipToNext,
  ];

  static const List<MediaControl> _controlsMultiplePaused = [
    MediaControl.skipToPrevious,
    MediaControl.play,
    MediaControl.stop,
    MediaControl.skipToNext,
  ];

  static const List<MediaControl> _controlsSinglePlaying = [
    MediaControl.rewind,
    MediaControl.pause,
    MediaControl.stop,
    MediaControl.fastForward,
  ];

  static const List<MediaControl> _controlsSinglePaused = [
    MediaControl.rewind,
    MediaControl.play,
    MediaControl.stop,
    MediaControl.fastForward,
  ];

  List<MediaControl> _controls(bool playing) {
    final hasMultipleTracks = _hub.queue.items.length > 1;
    if (hasMultipleTracks) {
      return playing ? _controlsMultiplePlaying : _controlsMultiplePaused;
    } else {
      return playing ? _controlsSinglePlaying : _controlsSinglePaused;
    }
  }

  final List<StreamSubscription> _subscriptions = [];

  final _processingStateMap = {
    ProcessingState.idle: AudioProcessingState.idle,
    ProcessingState.loading: AudioProcessingState.loading,
    ProcessingState.buffering: AudioProcessingState.buffering,
    ProcessingState.ready: AudioProcessingState.ready,
    ProcessingState.completed: AudioProcessingState.completed,
  };

  void _logStreamError(String message, Object error, StackTrace stackTrace) {
    logger.log(message, error: error, stackTrace: stackTrace);
  }

  void _setupEventSubscriptions() {
    _subscriptions
      ..add(
      audioPlayer.playbackEventStream
          .throttleTime(const Duration(milliseconds: 100))
          .listen(
            (event) {
              _updatePlaybackState();
            },
            onError: (error, stackTrace) {
              _logStreamError('Playback event stream error', error, stackTrace);
            },
          ),
      )
      ..add(
      audioPlayer.processingStateStream.distinct().listen(
        _handleProcessingStateChange,
        onError: (error, stackTrace) {
          _logStreamError('Processing state stream error', error, stackTrace);
        },
      ),
    );

    _subscriptions
      ..add(
      audioPlayer.positionStream
          .throttleTime(const Duration(milliseconds: 100))
          .listen(
            (position) =>
                _completion.handleNearEndSkip(_nearEndSkipContext(position)),
            onError: (error, stackTrace) {
              _logStreamError('Position stream error', error, stackTrace);
            },
          ),
      )
      ..add(
      audioPlayer.durationStream.listen(
        (duration) {
          final transitionInProgress = _currentLoadingTransitionId >= 0;
          final sourceBelongsToCurrentTransition =
              !transitionInProgress ||
              _playback.installedSourceTransitionId == _currentLoadingTransitionId;
          if (sourceBelongsToCurrentTransition &&
              _hub.queue.currentIndex < _hub.queue.items.length &&
              duration != null) {
            _updateCurrentMediaItemWithDuration(duration);
          }
        },
        onError: (error, stackTrace) {
          _logStreamError('Duration stream error', error, stackTrace);
        },
      ),
    );

    _subscriptions
      ..add(
      audioPlayer.playerStateStream
          .distinct()
          .throttleTime(const Duration(milliseconds: 100))
          .listen(
            (state) {
              if (state.processingState == ProcessingState.idle &&
                  !state.playing &&
                  _playback.lastError != null) {
                Future.microtask(
                  () => _completion.handlePlaybackError(_playbackErrorContext()),
                );
              }
              _debouncedStateUpdate();
            },
            onError: (error, stackTrace) {
              _logStreamError('Player state stream error', error, stackTrace);
            },
          ),
      )
      ..add(
      audioPlayer.currentIndexStream.distinct().listen(
        (index) {
          if (!_playback.gaplessSourceActive || index == null || index <= 0) return;
          if (_currentLoadingTransitionId >= 0 || _playback.sourceSwitchInFlight) return;
          final newQueueIndex = _playback.gaplessBaseQueueIndex + index;
          if (newQueueIndex != _hub.queue.currentIndex &&
              newQueueIndex >= 0 &&
              newQueueIndex < _hub.queue.items.length) {
            _syncQueueIndexFromGaplessAdvance(newQueueIndex);
          }
        },
        onError: (error, stackTrace) {
          _logStreamError('Current index stream error', error, stackTrace);
        },
      ),
      )
      ..add(
      Rx.combineLatest2(
            audioPlayer.currentIndexStream.distinct(),
            audioPlayer.sequenceStateStream.distinct(),
            (index, sequence) => {'index': index, 'sequence': sequence},
          )
          .throttleTime(const Duration(milliseconds: 100))
          .listen(
            (data) {
              _debouncedStateUpdate();
            },
            onError: (error, stackTrace) {
              _logStreamError('Current index stream error', error, stackTrace);
            },
          ),
    );
  }

  Future<void> dispose() async {
    for (final sub in _subscriptions) {
      unawaited(sub.cancel());
    }
    _subscriptions.clear();
    _sleepTimer?.cancel();
    _debounceTimer?.cancel();
    currentPlayingYtid.dispose();
    queueItemCount.dispose();
    await _queueMapStream.close();
    await audioPlayer.dispose();
  }

  void _debouncedStateUpdate() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceInterval, () {
      if (!_isUpdatingState) {
        _updatePlaybackState();
      }
    });
  }

  void _hydrateQueueEntryIds() {
    _hub.queue.entryIds
      ..ensureIds(_hub.queue.items)
      ..ensureIds(_hub.queue.originalItems);
  }

  MediaItem _getMediaItemForQueue(Map song) {
    return mapToMediaItem(song).copyWith(id: _hub.queue.entryIds.ensureId(song));
  }

  List<MediaItem> _buildQueueMediaItems() =>
      _hub.queue.items.map(_getMediaItemForQueue).toList(growable: false);

  bool _shouldUpdateDuration(Duration? currentDuration, Duration nextDuration) {
    if (currentDuration != null && currentDuration > Duration.zero) {
      final ratio = nextDuration.inMilliseconds / currentDuration.inMilliseconds;
      // Detect iOS CoreAudio / AVPlayer HE-AAC SBR timescale doubling (e.g. 22.05kHz vs 44.1kHz)
      if (ratio > 1.7 && ratio < 2.3) {
        return false;
      }
      if (ratio > 0.4 && ratio < 0.6) {
        return false;
      }
    }
    return currentDuration == null ||
        !durationEquals(currentDuration, nextDuration);
  }

  /// iOS AVPlayer reports ~2× for HE-AAC/SBR. Prefer catalog length; if the
  /// catalog is missing and the stream is HE-AAC, halve the player duration.
  Duration _canonicalPlaybackDuration(
    Map song,
    MediaItem? currentItem,
    Duration playerDuration,
  ) {
    final catalog =
        parseSongDuration(song['duration']) ??
        _catalogDurationFromExtras(currentItem?.extras);
    if (catalog != null &&
        playerDuration > catalog + const Duration(seconds: 5)) {
      return catalog;
    }
    if (catalog == null &&
        isHeAacFormatLabel(song['resolvedFormat']?.toString()) &&
        playerDuration > const Duration(seconds: 10)) {
      return Duration(milliseconds: playerDuration.inMilliseconds ~/ 2);
    }
    return playerDuration;
  }

  Duration? _catalogDurationFromExtras(Map<String, dynamic>? extras) {
    final catalogSec = extras?['catalogDurationSeconds'];
    if (catalogSec is int && catalogSec > 0) {
      return Duration(seconds: catalogSec);
    }
    return parseSongDuration(extras?['catalogDurationSeconds']);
  }

  String _mediaItemSignature(MediaItem item) {
    final dur = item.duration?.inSeconds ?? -1;
    return '${item.id}|${item.title}|${item.artUri}|${item.extras?['resolvedSource']}|$dur';
  }

  void _publishMediaItem(MediaItem item, {bool force = false}) {
    final signature = _mediaItemSignature(item);
    if (!force && signature == _lastPublishedMediaSignature) {
      return;
    }
    _lastPublishedMediaSignature = signature;
    final ytid = item.extras?['ytid']?.toString();
    if (ytid != null && ytid.isNotEmpty) {
      currentPlayingYtid.value = ytid;
    }
    mediaItem.add(item);
  }

  void _clearPublishedMediaState() {
    _lastPublishedMediaSignature = null;
    currentPlayingYtid.value = null;
  }

  Future<String?> _resolveNextStreamUrl(Map nextSong) async {
    return _hub.preload.resolveNextStreamUrl(
      nextSong,
      offlineModeEnabled: offlineMode.value,
      loadInProgress: _currentLoadingTransitionId >= 0,
    );
  }

  GaplessInstallContext _gaplessContext() {
    final nextIndex = _hub.queue.currentIndex + 1;
    return GaplessInstallContext(
      offlineModeEnabled: offlineMode.value,
      repeatOne: repeatNotifier.value == AudioServiceRepeatMode.one,
      currentIndex: _hub.queue.currentIndex,
      queueLength: _hub.queue.items.length,
      nextSong: nextIndex < _hub.queue.items.length
          ? _hub.queue.items[nextIndex]
          : null,
      currentSongTitle: currentSong?['title']?.toString(),
      hasPlayableOfflineFile: hasPlayableOfflineFile,
      resolveNextStreamUrl: _resolveNextStreamUrl,
    );
  }

  Future<bool> _installPlayback({
    required Map song,
    required AudioSource audioSource,
    required String songUrl,
    required bool isOffline,
    String? mediaId,
    bool allowOnlineRetry = true,
    int? transitionId,
    Duration? resumeAt,
  }) {
    return _playback.setAudioSourceAndPlay(
      song: song,
      audioSource: audioSource,
      songUrl: songUrl,
      isOffline: isOffline,
      gaplessCtx: _gaplessContext(),
      isStale: _isStaleTransition,
      logPlayer: _logPlayer,
      offlineModeEnabled: () => offlineMode.value,
      onDurationKnown: _updateCurrentMediaItemWithDuration,
      onPlaybackStateChanged: _updatePlaybackState,
      ensureActuallyPlaying: _ensureActuallyPlaying,
      onRecentlyPlayed: (s) => updateRecentlyPlayed(s['ytid'], songFallback: s),
      schedulePreload: _preloadUpcomingSongs,
      mediaId: mediaId,
      allowOnlineRetry: allowOnlineRetry,
      transitionId: transitionId,
      resumeAt: resumeAt,
    );
  }

  PlaybackErrorContext _playbackErrorContext() {
    return PlaybackErrorContext(
      lastError: _playback.lastError,
      setLastError: (error) => _playback.lastError = error,
      canRetryPlayback: () =>
          hasNext ||
          (repeatNotifier.value == AudioServiceRepeatMode.all &&
              _hub.queue.items.isNotEmpty) ||
          playNextSongAutomatically.value,
      stopPlayback: stop,
      invalidateStreamCache: invalidateSongStreamCache,
      removePreloadedUrl: (ytid) => _hub.preloadCache.streamUrls.remove(ytid),
      retryCurrentSong: playSong,
      skipToNext: skipToNext,
      songYtid: _songYtid,
      currentSong: () => currentSong,
    );
  }

  SongCompletionContext _songCompletionContext() {
    return SongCompletionContext(
      addCurrentToHistory: () async {
        if (_hub.queue.currentIndex >= 0 &&
            _hub.queue.currentIndex < _hub.queue.items.length) {
          _addToHistory(_hub.queue.items[_hub.queue.currentIndex]);
        }
      },
      repeatOne: repeatNotifier.value == AudioServiceRepeatMode.one,
      playAgain: playAgain,
      skipToNext: skipToNext,
      currentQueueIndex: () => _hub.queue.currentIndex,
      stopPlayback: stop,
    );
  }

  ProcessingCompletedContext _processingCompletedContext() {
    return ProcessingCompletedContext(
      loadInProgress: _currentLoadingTransitionId >= 0,
      sourceSwitchInFlight: _playback.sourceSwitchInFlight,
      gaplessSourceActive: _playback.gaplessSourceActive,
      gaplessBaseQueueIndex: _playback.gaplessBaseQueueIndex,
      playerIndex: audioPlayer.currentIndex ?? 0,
      sequenceLength: audioPlayer.sequence.length,
      queueLength: _hub.queue.items.length,
      sleepTimerEndOfSong: sleepTimerEndOfSong,
      sleepTimerExpired: sleepTimerExpired,
      syncGaplessAdvance: _syncQueueIndexFromGaplessAdvance,
      clearGaplessActive: () => _playback.gaplessSourceActive = false,
      onSleepTimerEndOfSong: () {
        sleepTimerExpired = true;
        sleepTimerEndOfSong = false;
        unawaited(stop());
        sleepTimerNotifier.value = null;
      },
      onCompleteTrack: () => _completion.completeSong(_songCompletionContext()),
      logPlayer: (message) => _logPlayer(message),
    );
  }

  NearEndSkipContext _nearEndSkipContext(Duration position) {
    return NearEndSkipContext(
      position: position,
      sleepTimerExpired: sleepTimerExpired,
      lastInstalledWasClipped: _playback.lastInstalledWasClipped,
      gaplessSourceActive: _playback.gaplessSourceActive,
      loadInProgress: _currentLoadingTransitionId >= 0,
      sourceSwitchInFlight: _playback.sourceSwitchInFlight,
      playerPlaying: audioPlayer.playing,
      processingState: audioPlayer.processingState,
      playerDuration: audioPlayer.duration,
      currentSong: currentSong,
      currentMediaItem: mediaItem.valueOrNull,
      canonicalDuration: _canonicalPlaybackDuration,
      catalogFromExtras: _catalogDurationFromExtras,
      triggerCompleted: () =>
          _handleProcessingStateChange(ProcessingState.completed),
    );
  }

  void _syncQueueIndexFromGaplessAdvance(int newIndex) {
    if (newIndex < 0 || newIndex >= _hub.queue.items.length) return;
    _hub.queue.currentIndex = newIndex;
    _playback.gaplessSourceActive = false;
    _publishMediaItem(_getMediaItemForQueue(_hub.queue.items[newIndex]), force: true);
    _updatePlaybackState();
    _preloadUpcomingSongs();
    logger.log(
      'Gapless advance → queue index $newIndex (${_hub.queue.items[newIndex]['title']})',
    );
  }

  void _logPlayer(String message, {Map<String, Object?>? extra}) {
    logger.log(
      message,
      data: {
        'playing': audioPlayer.playing,
        'state': audioPlayer.processingState.name,
        'seq': '${audioPlayer.currentIndex ?? '-'}/${audioPlayer.sequence.length}',
        'pos': '${audioPlayer.position.inSeconds}s',
        'dur': '${audioPlayer.duration?.inSeconds ?? '-'}s',
        'q': '${_hub.queue.currentIndex}/${_hub.queue.items.length}',
        'load': _currentLoadingTransitionId,
        'done': _completion.eventPending,
        if (_playback.lastError != null) 'err': _playback.lastError,
        ...?extra,
      },
    );
  }

  void _showPlaybackStreamError() {
    final message = consumeYoutubeStreamError() ??
        "Couldn't play this track. Check Settings → YouTube Stream Client.";
    showAppToast(message);
  }

  bool _isCurrentMediaItemMatchingSong(
    MediaItem? currentItem,
    MediaItem currentQueueMediaItem,
    String? currentSongYtid,
  ) {
    if (currentItem == null) return false;

    if (currentItem.id == currentQueueMediaItem.id) {
      return true;
    }

    return currentSongYtid != null &&
        currentSongYtid.isNotEmpty &&
        currentItem.extras?['ytid']?.toString() == currentSongYtid;
  }

  void _updateCurrentMediaItemWithDuration(Duration duration) {
    try {
      final queueIndex = _hub.queue.currentIndex;
      if (queueIndex < 0 || queueIndex >= _hub.queue.items.length) return;

      final currentSong = _hub.queue.items[queueIndex];
      final currentMediaItem = _getMediaItemForQueue(currentSong);
      final currentSongYtid = currentSong['ytid']?.toString();
      final currentItem = mediaItem.valueOrNull;
      final isMatchingCurrentItem = _isCurrentMediaItemMatchingSong(
        currentItem,
        currentMediaItem,
        currentSongYtid,
      );

      // A duration event from the previous AVPlayer item must never restore
      // that item's title/artwork over the song we just skipped to.
      if (!isMatchingCurrentItem) return;

      duration = _canonicalPlaybackDuration(currentSong, currentItem, duration);

      if (currentItem != null &&
          _shouldUpdateDuration(currentItem.duration, duration)) {
        _publishMediaItem(currentItem.copyWith(duration: duration), force: true);
      }

      final existingQueue = queue.valueOrNull;
      if (existingQueue != null && queueIndex < existingQueue.length) {
        final queueItem = existingQueue[queueIndex];
        if (_shouldUpdateDuration(queueItem.duration, duration)) {
          final updatedQueue = List<MediaItem>.from(existingQueue);
          updatedQueue[queueIndex] = queueItem.copyWith(duration: duration);
          queue.add(updatedQueue);
        }
        return;
      }

      final rebuiltQueue = _buildQueueMediaItems();
      if (queueIndex < rebuiltQueue.length) {
        rebuiltQueue[queueIndex] = rebuiltQueue[queueIndex].copyWith(
          duration: duration,
        );
      }
      queue.add(rebuiltQueue);
    } catch (e, stackTrace) {
      logger.log(
        'Error updating media item with duration',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }



  Future<void> _initialize() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      _subscriptions.add(
        session.interruptionEventStream.listen((event) {
          _logPlayer(
            'Audio interruption ${event.begin ? 'begin' : 'end'}',
            extra: {'type': event.type.name},
          );
          if (event.begin) {
            if (event.type == AudioInterruptionType.duck) {
              unawaited(audioPlayer.setVolume(0.5));
            } else if (event.type == AudioInterruptionType.pause) {
              // Phone call / Siri — not lock screen. Locking must not pause.
              _wasPlayingBeforeInterruption = audioPlayer.playing;
              if (_wasPlayingBeforeInterruption) {
                unawaited(pause());
              }
            } else {
              _wasPlayingBeforeInterruption = audioPlayer.playing;
            }
          } else {
            if (event.type == AudioInterruptionType.duck) {
              unawaited(audioPlayer.setVolume(1));
            } else if (_wasPlayingBeforeInterruption) {
              unawaited(play());
            }
          }
        }),
      );

      _subscriptions.add(
        session.becomingNoisyEventStream.listen((_) {
          unawaited(pause());
        }),
      );

      // Always set loop mode to off - completion coordinator advances the queue.
      // This ensures ProcessingState.completed is always fired for song transitions
      await audioPlayer.setLoopMode(LoopMode.off);

      // Apply stored shuffle mode to audio player
      await audioPlayer.setShuffleModeEnabled(shuffleNotifier.value);
    } catch (e, stackTrace) {
      logger.log(
        'Error initializing audio session',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  bool _hasSignificantPositionChange(
    Duration currentPosition,
    Duration lastUpdatePosition,
    DateTime lastUpdateTime,
    DateTime now,
    double speed,
  ) {
    final expectedPosition =
        lastUpdatePosition + (now.difference(lastUpdateTime)) * speed;
    return (currentPosition - expectedPosition).abs() >
        const Duration(milliseconds: 500);
  }

  void _updatePlaybackState() {
    if (_isUpdatingState) {
      _pendingPlaybackStateUpdate = true;
      return;
    }

    _isUpdatingState = true;

    try {
      final now = DateTime.now();
      // Fresh-track load: the player still holds the previous song's
      // position until the new source is installed. Reporting that to
      // MPNowPlayingInfoCenter makes the lock-screen scrubber jump.
      final loadingFreshTrack =
          _currentLoadingTransitionId >= 0 &&
          _playback.installedSourceTransitionId != _currentLoadingTransitionId &&
          !_playback.sourceSwitchInFlight;
      final currentPosition =
          loadingFreshTrack ? Duration.zero : audioPlayer.position;
      final isPlaying = audioPlayer.playing;
      final currentState = playbackState.valueOrNull;
      final newProcessingState =
          _processingStateMap[audioPlayer.processingState] ??
          AudioProcessingState.idle;
      final bufferedPosition =
          loadingFreshTrack ? Duration.zero : audioPlayer.bufferedPosition;

      final shouldEmitProgressTick =
          currentState != null &&
          isPlaying &&
          now.difference(currentState.updateTime) >= _playbackStateHeartbeat;
      final hasBufferedPositionChange =
          currentState == null ||
          (bufferedPosition - currentState.bufferedPosition).abs() >=
              const Duration(seconds: 1);

      final shouldUpdate =
          currentState == null ||
          currentState.playing != isPlaying ||
          currentState.processingState != newProcessingState ||
          currentState.queueIndex != _hub.queue.currentIndex ||
          currentState.speed != audioPlayer.speed ||
          shouldEmitProgressTick ||
          hasBufferedPositionChange ||
          (_hasSignificantPositionChange(
            currentPosition,
            currentState.updatePosition,
            currentState.updateTime,
            now,
            currentState.speed,
          ));

      if (shouldUpdate) {
        playbackState.add(
          PlaybackState(
            controls: _controls(isPlaying),
            systemActions: const {
              MediaAction.seek,
              MediaAction.seekForward,
              MediaAction.seekBackward,
            },
            processingState: newProcessingState,
            playing: isPlaying,
            updatePosition: currentPosition,
            bufferedPosition: bufferedPosition,
            speed: audioPlayer.speed,
            queueIndex:
                _hub.queue.currentIndex >= 0 &&
                    _hub.queue.currentIndex < _hub.queue.items.length
                ? _hub.queue.currentIndex
                : null,
            updateTime: now,
          ),
        );
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error updating playback state',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _isUpdatingState = false;
      if (_pendingPlaybackStateUpdate) {
        _pendingPlaybackStateUpdate = false;
        _updatePlaybackState();
      }
    }
  }

  void _handleProcessingStateChange(ProcessingState state) {
    try {
      if (state == ProcessingState.completed) {
        _completion.handleProcessingCompleted(_processingCompletedContext());
      } else if (state == ProcessingState.ready) {
        _completion.onProcessingStateReady(
          clearSleepTimerExpired: () => sleepTimerExpired = false,
        );
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error handling processing state change',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _backgroundAddSongsToQueue() async {
    // Fire and forget - this runs as a background task without blocking playback
    if (offlineMode.value) return;
    if (_hub.queue.items.isNotEmpty && _hub.queue.currentIndex < _hub.queue.items.length - 1) {
      return;
    }

    // Use microtask to avoid blocking the current operation
    unawaited(
      Future.microtask(() async {
        try {
          final baseSong = _getCurrentSongForRecommendations();
          if (baseSong == null) {
            return;
          }

          final ytid = baseSong['ytid']?.toString();
          if (ytid == null || ytid.isEmpty) return;

          // Fetch similar songs silently in the background
          await getSimilarSong(ytid).timeout(
            const Duration(seconds: 8),
            onTimeout: () {
              logger.log('Background song fetch timed out');
            },
          );

          if (nextRecommendedSong != null) {
            final songToAdd = nextRecommendedSong;
            nextRecommendedSong = null;
            if (songToAdd != null) {
              await _insertRecommendedSong(songToAdd);
            }
          }
        } catch (e, stackTrace) {
          logger.log(
            'Error in background song addition',
            error: e,
            stackTrace: stackTrace,
          );
        }
      }),
    );
  }

  Map? _getCurrentSongForRecommendations() {
    final currentMediaItem = mediaItem.valueOrNull;

    if (currentMediaItem == null || currentMediaItem.id.isEmpty) {
      logger.log('No current media item available');
      return null;
    }

    return mediaItemToMap(currentMediaItem);
  }

  void _addToHistory(Map song) {
    try {
      _hub.queue.history.insert(0, cloneMap(song));

      if (_hub.queue.history.length > AudioQueueState.maxHistorySize) {
        _hub.queue.history.removeRange(AudioQueueState.maxHistorySize, _hub.queue.history.length);
      }
    } catch (e, stackTrace) {
      logger.log('Error adding to history', error: e, stackTrace: stackTrace);
    }
  }

  // --- Queue (via hub) ---

  Future<void> addToQueue(Map song, {bool playNext = false}) async {
    try {
      if (!AudioQueueController.isValidSong(song)) {
        logger.log('Invalid song data for queue');
        return;
      }

      _hub.queueOps.insertManual(song, playNext: playNext);

      _updateQueueMediaItems();
      _cleanupOldPreloadedSongs();

      if (!audioPlayer.playing && _hub.queue.items.length == 1) {
        await _playFromQueue(0);
      }
    } catch (e, stackTrace) {
      logger.log('Error adding to queue', error: e, stackTrace: stackTrace);
    }
  }

  /// Play a song tapped outside the queue (search, lists). Replaces the queue
  /// with this track or jumps to it if already queued so skip/next stay aligned.
  Future<void> playSingleSong(Map song) async {
    try {
      final ytid = song['ytid']?.toString();
      if (ytid == null || ytid.isEmpty) {
        logger.log('Invalid song data for playSingleSong');
        return;
      }

      final existingIndex = _hub.queueOps.indexForYtid(
        ytid,
        AudioBrowseCatalog.songYtid,
      );
      if (existingIndex != null) {
        await _playFromQueue(existingIndex);
        return;
      }

      final snapshot = _captureQueuePlaybackState();
      _hub.queueOps.replaceWithSingle(song);
      _hydrateQueueEntryIds();
      _updateQueueMediaItems();
      final success = await _playFromQueue(0);
      if (!success) {
        _restoreQueuePlaybackState(snapshot);
        _hydrateQueueEntryIds();
        _updateQueueMediaItems();
        _updatePlaybackState();
        logger.log(
          'playSingleSong failed — restored previous queue',
          data: {'ytid': ytid, 'title': song['title']},
        );
        _showPlaybackStreamError();
      }
    } catch (e, stackTrace) {
      logger.log('Error in playSingleSong', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _insertRecommendedSong(Map song) async {
    try {
      if (song['ytid'] == null || song['ytid'].toString().isEmpty) {
        logger.log('Invalid recommended song data for queue');
        return;
      }

      final insertIndex = _hub.queue.items.length;
      final shouldPlayInsertedSong =
          playNextSongAutomatically.value &&
          !sleepTimerExpired &&
          _hub.queue.loadingIndex == -1 &&
          audioPlayer.processingState == ProcessingState.completed &&
          _hub.queue.items.isNotEmpty &&
          _hub.queue.currentIndex == _hub.queue.items.length - 1;
      final queueSong = _hub.queueOps.autoPickedEntry(song);
      _hub.queue.items.insert(insertIndex, queueSong);

      if (_hub.queue.currentIndex < 0) {
        _hub.queue.currentIndex = 0;
      }

      _updateQueueMediaItems();
      _cleanupOldPreloadedSongs();

      if (shouldPlayInsertedSong) {
        await _playFromQueue(insertIndex);
      } else if (!audioPlayer.playing && _hub.queue.items.length == 1) {
        await _playFromQueue(0);
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error inserting recommended song',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void _cleanupOldPreloadedSongs() {
    Future.microtask(() {
      try {
        _hub.cleanupStalePreloads();
      } catch (e, stackTrace) {
        logger.log(
          'Error cleaning up preloaded songs',
          error: e,
          stackTrace: stackTrace,
        );
      }
    });
  }

  Future<void> addPlaylistToQueue(
    List<Map> songs, {
    bool replace = false,
    int? startIndex,
    bool resetShuffle = true,
  }) async {
    try {
      final manuallyAddedSongs = replace ? _getUnplayedManualSongs() : <Map>[];
      if (replace) {
        _hub.queue.items.clear();
        _hub.queue.originalItems.clear();
        _hub.queue.currentIndex = 0;
        _hub.queue.loadingIndex = -1;
        _currentLoadingTransitionId = -1;
        _resetPreloadingState();
        if (resetShuffle) {
          shuffleNotifier.value = false;
          unawaited(Hive.box('settings').put('shuffleEnabled', false));
          await audioPlayer.setShuffleModeEnabled(false);
        }
      }

      int? targetQueueIndex;

      for (var i = 0; i < songs.length; i++) {
        final song = songs[i];
        if (song['ytid'] != null && song['ytid'].toString().isNotEmpty) {
          if (song['catalogOrigin'] == null &&
              song['resolvedSource'] == 'youtube') {
            song['catalogOrigin'] = 'youtube';
          }
          _hub.queue.items.add(_hub.queue.entryIds.createSong(song));

          if (replace && startIndex == i) {
            targetQueueIndex = _hub.queue.items.length - 1;
          }
        }
      }

      if (replace && manuallyAddedSongs.isNotEmpty) {
        // Always insert after the starting song index
        final insertIndex = (targetQueueIndex ?? 0) + 1;
        final safeInsertIndex = insertIndex > _hub.queue.items.length
            ? _hub.queue.items.length
            : insertIndex;
        _hub.queue.items.insertAll(safeInsertIndex, manuallyAddedSongs);
      }

      _hydrateQueueEntryIds();
      _updateQueueMediaItems();

      if (targetQueueIndex != null) {
        await _playFromQueue(targetQueueIndex);
      } else if (startIndex != null &&
          startIndex < _hub.queue.items.length &&
          !replace) {
        await _playFromQueue(startIndex);
      } else if (replace && _hub.queue.items.isNotEmpty) {
        await _playFromQueue(0);
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error adding playlist to queue',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> removeFromQueue(int index) async {
    try {
      final removedQueueEntryId = _hub.queueOps.removeAt(index);
      if (removedQueueEntryId == null) return;

      if (shuffleNotifier.value && _hub.queue.originalItems.isNotEmpty) {
        _hub.queue.originalItems.removeWhere(
          (s) => _hub.queue.entryIds.ensureId(s) == removedQueueEntryId,
        );
      }

      if (index == _hub.queue.loadingIndex) {
        _currentLoadingTransitionId = -1;
      }

      final wasCurrent = index == _hub.queue.currentIndex;
      _hub.queueOps.adjustIndicesAfterRemove(index);

      if (wasCurrent) {
        if (_hub.queue.items.isEmpty) {
          await stop();
        } else {
          if (_hub.queue.currentIndex >= _hub.queue.items.length) {
            _hub.queue.currentIndex = _hub.queue.items.length - 1;
          }
          await _playFromQueue(_hub.queue.currentIndex);
        }
      }

      _hydrateQueueEntryIds();
      _updateQueueMediaItems();
    } catch (e, stackTrace) {
      logger.log('Error removing from queue', error: e, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    await removeFromQueue(index);
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    try {
      if (!_hub.queueOps.reorder(oldIndex, newIndex)) return;
      _updateQueueMediaItems();
    } catch (e, stackTrace) {
      logger.log('Error reordering queue', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> reorderQueueById(String queueEntryId, int targetIndex) async {
    try {
      if (!_hub.queueOps.reorderById(queueEntryId, targetIndex)) return;
      _updateQueueMediaItems();
    } catch (e, stackTrace) {
      logger.log(
        'Error reordering queue by id',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void clearQueue() {
    try {
      final currentClone =
          _hub.queue.currentIndex >= 0 &&
              _hub.queue.currentIndex < _hub.queue.items.length
          ? cloneMap(_hub.queue.items[_hub.queue.currentIndex])
          : null;

      _hub.queueOps.clearKeepingCurrent(currentClone: currentClone);
      _currentLoadingTransitionId = -1;
      _resetPreloadingState();
      _updateQueueMediaItems();
      _updatePlaybackState();
    } catch (e, stackTrace) {
      logger.log('Error clearing queue', error: e, stackTrace: stackTrace);
    }
  }

  void _updateQueueMediaItems() {
    try {
      _hub.queue.entryIds.ensureIds(_hub.queue.items);

      final mediaItems = _buildQueueMediaItems();
      queue.add(mediaItems);

      _queueMapStream.add(List.unmodifiable(_hub.queue.items));
      queueItemCount.value = _hub.queue.items.length;

      if (_hub.queue.currentIndex >= 0 &&
          _hub.queue.currentIndex < mediaItems.length &&
          _currentLoadingTransitionId < 0) {
        _publishMediaItem(mediaItems[_hub.queue.currentIndex]);
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error updating queue media items',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void _emitOptimisticLoadingState({
    Map? song,
    int? queueIndex,
    bool includeMediaItem = false,
    String? mediaId,
    // A brand-new track resets to 0. A same-song source switch keeps the
    // resume position. Reporting the previous track's position to iOS makes
    // the lock screen scrubber glitch and jump before snapping to 0.
    bool freshTrack = true,
  }) {
    try {
      if (includeMediaItem && song != null) {
        var immediateMediaItem = mapToMediaItem(song);
        if (mediaId != null) {
          immediateMediaItem = immediateMediaItem.copyWith(id: mediaId);
        }
        Future.microtask(() {
          _publishMediaItem(immediateMediaItem);
        });
      }

      final optimisticPosition =
          freshTrack ? Duration.zero : audioPlayer.position;

      playbackState.add(
        PlaybackState(
          controls: [
            MediaControl.skipToPrevious,
            MediaControl.pause,
            MediaControl.stop,
            MediaControl.skipToNext,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          },
          processingState: AudioProcessingState.loading,
          playing: true,
          updatePosition: optimisticPosition,
          bufferedPosition:
              freshTrack ? Duration.zero : audioPlayer.bufferedPosition,
          speed: audioPlayer.speed,
          queueIndex:
              queueIndex ??
              (_hub.queue.currentIndex < _hub.queue.items.length
                  ? _hub.queue.currentIndex
                  : null),
          updateTime: DateTime.now(),
        ),
      );
    } catch (e, stackTrace) {
      logger.log(
        'Error emitting optimistic loading state',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void _rollbackFailedQueuePlay({
    required int previousQueueIndex,
    required MediaItem? previousMediaItem,
    required bool resumePlayback,
  }) {
    if (_hub.queue.items.isEmpty) {
      _hub.queue.currentIndex = -1;
    }
    // Keep the track the user picked — never rewind UI to the previous song.
    final currentIndex = _hub.queue.currentIndex;
    if (currentIndex >= 0 && currentIndex < _hub.queue.items.length) {
      _publishMediaItem(
        _getMediaItemForQueue(_hub.queue.items[currentIndex]),
        force: true,
      );
    } else if (previousMediaItem != null && _hub.queue.items.isNotEmpty) {
      _hub.queue.currentIndex = previousQueueIndex.clamp(
        0,
        _hub.queue.items.length - 1,
      );
      _publishMediaItem(previousMediaItem, force: true);
    }
    unawaited(_playback.recoverPlayerAfterLoadFailure());
    _updatePlaybackState();
  }

  ({
    List<Map> items,
    List<Map> originals,
    List<Map> history,
    int currentIndex,
    MediaItem? mediaItem,
  }) _captureQueuePlaybackState() {
    return (
      items: cloneMaps(_hub.queue.items),
      originals: cloneMaps(_hub.queue.originalItems),
      history: cloneMaps(_hub.queue.history),
      currentIndex: _hub.queue.currentIndex,
      mediaItem: mediaItem.valueOrNull,
    );
  }

  void _restoreQueuePlaybackState(
    ({
      List<Map> items,
      List<Map> originals,
      List<Map> history,
      int currentIndex,
      MediaItem? mediaItem,
    }) snapshot,
  ) {
    _hub.queue.items
      ..clear()
      ..addAll(cloneMaps(snapshot.items));
    _hub.queue.originalItems
      ..clear()
      ..addAll(cloneMaps(snapshot.originals));
    _hub.queue.history
      ..clear()
      ..addAll(cloneMaps(snapshot.history));
    _hub.queue.currentIndex = snapshot.items.isEmpty
        ? -1
        : snapshot.currentIndex.clamp(0, snapshot.items.length - 1);
    if (snapshot.mediaItem != null) {
      _publishMediaItem(snapshot.mediaItem!, force: true);
    }
  }

  // --- Playback load ---

  Future<bool> _playFromQueue(int index) async {
    if (index < 0 || index >= _hub.queue.items.length) {
      logger.log('Invalid queue index: $index');
      return false;
    }

    _playback.gaplessSourceActive = false;

    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
    } catch (_) {}

    // If already loading any song, skip the request
    // UNLESS we're in the middle of handling a completion event (allow one load attempt)
    if (_completion.shouldSkipPlayFromQueueAlreadyLoading(
      _hub.queue.loadingIndex,
      index,
      loadingKey: _hub.queue.loadingKey,
      requestedKey: AudioQueueState.songKey(_hub.queue.songAt(index)),
    )) {
      _logPlayer('playFromQueue skipped — already loading this song');
      return false;
    }

    _completion.tryMarkCompletionLoadStarted(_hub.queue.loadingIndex);
    if (_completion.shouldSkipDuplicateCompletionLoad(_hub.queue.loadingIndex)) {
      _logPlayer(
        'playFromQueue skipped — completion load already started',
        extra: {'loadingIndex': _hub.queue.loadingIndex, 'requested': index},
      );
      return false;
    }

    // Drop in-flight YouTube preloads so a skip does not compete with them.
    _resetPreloadingState();

    // Start new transition
    _songTransitionCounter++;
    final currentTransitionId = _songTransitionCounter;
    _hub.queue.markLoading(index, _hub.queue.songAt(index));
    _currentLoadingTransitionId = currentTransitionId;

    final wasPlayingBeforeLoad = audioPlayer.playing;
    final previousQueueIndex = _hub.queue.currentIndex;
    final previousMediaItem = mediaItem.valueOrNull;
    var succeeded = false;

    try {
      _hub.queue.currentIndex = index;

      final currentSong = _hub.queue.items[_hub.queue.currentIndex];
      _logPlayer(
        'playFromQueue → ${currentSong['title']}',
        extra: {
          'ytid': currentSong['ytid'],
          'offline': currentSong['isOffline'] == true,
          'source': currentSong['resolvedSource'] ?? currentSong['source'] ?? '-',
        },
      );
      final currentMediaItem = _getMediaItemForQueue(currentSong);
      final uniqueId = currentMediaItem.id;

      final success = await playSong(
        _hub.queue.items[index],
        mediaId: uniqueId,
        transitionId: currentTransitionId,
      );

      if (currentTransitionId != _currentLoadingTransitionId) {
        return false;
      }

      if (success) {
        succeeded = true;
        _completion.clearConsecutiveErrors();
        _preloadUpcomingSongs();
        if (playNextSongAutomatically.value) {
          unawaited(_backgroundAddSongsToQueue());
        }
      } else {
        _rollbackFailedQueuePlay(
          previousQueueIndex: previousQueueIndex,
          previousMediaItem: previousMediaItem,
          resumePlayback: wasPlayingBeforeLoad,
        );
        final failedYtid = _hub.queue.items[_hub.queue.currentIndex]['ytid']
            ?.toString();
        if (failedYtid != null && failedYtid.isNotEmpty) {
          _hub.queue.items[_hub.queue.currentIndex].remove('_preloadedStreamUrl');
          _hub.preloadCache.drop(failedYtid);
          unawaited(invalidateSongStreamCache(failedYtid));
        }
        _completion.handlePlaybackError(
          _playbackErrorContext(),
          advance: false,
        );
        _showPlaybackStreamError();
      }
    } catch (e, stackTrace) {
      logger.log('Error playing from queue', error: e, stackTrace: stackTrace);
      if (currentTransitionId == _currentLoadingTransitionId) {
        _rollbackFailedQueuePlay(
          previousQueueIndex: previousQueueIndex,
          previousMediaItem: previousMediaItem,
          resumePlayback: wasPlayingBeforeLoad,
        );
        final idx = _hub.queue.currentIndex;
        if (idx >= 0 && idx < _hub.queue.items.length) {
          final failedYtid = _hub.queue.items[idx]['ytid']?.toString();
          if (failedYtid != null && failedYtid.isNotEmpty) {
            _hub.queue.items[idx].remove('_preloadedStreamUrl');
            _hub.preloadCache.drop(failedYtid);
            unawaited(invalidateSongStreamCache(failedYtid));
          }
        }
      }
      _completion.handlePlaybackError(
        _playbackErrorContext(),
        advance: false,
      );
      _showPlaybackStreamError();
    } finally {
      if (currentTransitionId == _currentLoadingTransitionId) {
        _hub.queue.loadingIndex = -1;
        _currentLoadingTransitionId = -1;
      }
    }
    return succeeded;
  }

  // --- Preload (via hub) ---

  void _preloadUpcomingSongs() {
    if (offlineMode.value || _currentLoadingTransitionId != -1) return;

    Future.microtask(() async {
      try {
        if (_currentLoadingTransitionId != -1) return;
        final songs = _hub.upcomingPreloadCandidates(
          offlineModeEnabled: offlineMode.value,
        );
        await _hub.preload.preloadSequentially(
          songs,
          isLoadInProgress: () => _currentLoadingTransitionId != -1,
          preloadOne: (song) => _hub.preload.preloadSingle(
            song,
            offlineModeEnabled: offlineMode.value,
            isLoadInProgress: () => _currentLoadingTransitionId != -1,
          ),
        );
      } catch (e, stackTrace) {
        logger.log(
          'Error in _preloadUpcomingSongs',
          error: e,
          stackTrace: stackTrace,
        );
      }
    });
  }

  Stream<List<Map>> get queueAsMapStream => _queueMapStream.stream;
  int get currentQueueIndex => _hub.queue.currentIndex;
  Map? get currentSong =>
      _hub.queue.currentIndex >= 0 && _hub.queue.currentIndex < _hub.queue.items.length
      ? _hub.queue.items[_hub.queue.currentIndex]
      : null;

  bool get hasNext =>
      _hub.queue.currentIndex < _hub.queue.items.length - 1 ||
      repeatNotifier.value == AudioServiceRepeatMode.all;

  bool get hasPrevious => _hub.queue.currentIndex > 0 || _hub.queue.history.isNotEmpty;

  String? _songYtid(Map song) => AudioBrowseCatalog.songYtid(song);

  Map? _findSongByMediaId(String mediaId) {
    return AudioBrowseCatalog.findByMediaId(
      mediaId,
      currentSong: currentSong,
      queueItems: _hub.queue.items,
      liked: userLikedSongsList.value,
      offline: userOfflineSongs.value,
      recent: userRecentlyPlayed.value,
    );
  }

  Map? _latestResumableSong() {
    return AudioBrowseCatalog.latestResumableSong(
      currentSong: currentSong,
      activeMediaItem: mediaItem.valueOrNull,
      recent: userRecentlyPlayed.value,
      offline: userOfflineSongs.value,
      liked: userLikedSongsList.value,
      queueItems: _hub.queue.items,
    );
  }

  MediaItem? _mediaItemForResumption(Map song) =>
      AudioBrowseCatalog.mediaItemForResumption(song);

  Future<void> _playResumableSong(Map song) async {
    final normalised = AudioBrowseCatalog.normaliseResumableSong(song);
    if (normalised == null) return;

    await playPlaylistSong(
      playlist: {
        'title': 'Musify',
        'source': 'system-recent',
        'list': [normalised],
      },
      songIndex: 0,
    );
  }

  // --- Browse / CarPlay (BaseAudioHandler) ---
  @override
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    if (parentMediaId == AudioService.recentRootId) {
      final recentSong = _latestResumableSong();
      final recentItem = recentSong == null
          ? null
          : _mediaItemForResumption(recentSong);
      return recentItem == null ? [] : [recentItem];
    }

    if (parentMediaId == AudioService.browsableRootId) {
      return AudioBrowseCatalog.browsableRootChildren();
    }

    switch (parentMediaId) {
      case AudioBrowseCatalog.rootQueue:
        return _hub.queue.items.map(_getMediaItemForQueue).toList();
      case AudioBrowseCatalog.rootLiked:
        return userLikedSongsList.value
            .whereType<Map>()
            .map((s) => mapToMediaItem(s).copyWith(playable: true))
            .toList();
      case AudioBrowseCatalog.rootOffline:
        return userOfflineSongs.value
            .whereType<Map>()
            .map((s) => mapToMediaItem(s).copyWith(playable: true))
            .toList();
      case AudioBrowseCatalog.rootRecent:
        return userRecentlyPlayed.value
            .whereType<Map>()
            .map((s) => mapToMediaItem(s).copyWith(playable: true))
            .toList();
      default:
        return [];
    }
  }

  @override
  Future<void> playFromSearch(
    String query, [
    Map<String, dynamic>? extras,
  ]) async {
    if (query.trim().isEmpty) {
      // "Play music" with no specifics
      if (_hub.queue.items.isNotEmpty) {
        await play();
        return;
      }
      final recentSong = _latestResumableSong();
      if (recentSong != null) await _playResumableSong(recentSong);
      return;
    }

    final q = query.trim().toLowerCase();
    final candidates = [
      ..._hub.queue.items,
      ...userLikedSongsList.value.whereType<Map>(),
      ...userOfflineSongs.value.whereType<Map>(),
      ...userRecentlyPlayed.value.whereType<Map>(),
    ];

    final match = candidates.firstWhere((s) {
      final title = s['title']?.toString().toLowerCase() ?? '';
      final artist = s['artist']?.toString().toLowerCase() ?? '';
      return title.contains(q) || artist.contains(q);
    }, orElse: () => const {});

    if (match.isNotEmpty) {
      await _playResumableSong(match);
      return;
    }

    try {
      final results = await fetchSongsList(query.trim());
      if (results.isNotEmpty && results.first is Map) {
        await playSingleSong(Map<String, dynamic>.from(results.first as Map));
        return;
      }
    } catch (e, st) {
      logger.log('playFromSearch network fallback failed', error: e, stackTrace: st);
    }

    logger.log('playFromSearch: no match for "$query"');
  }

  @override
  Future<MediaItem?> getMediaItem(String mediaId) async {
    final song = _findSongByMediaId(mediaId);
    return song == null ? null : _mediaItemForResumption(song);
  }

  @override
  Future<void> prepareFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    final item = await getMediaItem(mediaId);
    if (item == null) return;

    final song = _findSongByMediaId(mediaId);
    if (song != null) {
      final queueSong = _hub.queue.entryIds.createSong(cloneMap(song));
      _hub.queue.items
        ..clear()
        ..add(queueSong);
      _hub.queue.originalItems
        ..clear()
        ..add(cloneMap(queueSong));
      _hub.queue.currentIndex = 0;
      _hydrateQueueEntryIds();
    }

    _publishMediaItem(item, force: true);
    queue.add([item]);
    playbackState.add(
      PlaybackState(
        controls: _controls(false),
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        processingState: AudioProcessingState.ready,
        queueIndex: 0,
        updateTime: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    final song = _findSongByMediaId(mediaId);
    if (song == null) {
      logger.log('No resumable song found for media id: $mediaId');
      return;
    }
    await _playResumableSong(song);
  }

  @override
  Future<void> onTaskRemoved() async {
    try {
      await stop();
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (e, stackTrace) {
      logger.log('Error in onTaskRemoved', error: e, stackTrace: stackTrace);
    }
    await super.onTaskRemoved();
  }

  @override
  Future<void> play() async {
    try {
      sleepTimerExpired = false;
      try {
        final session = await AudioSession.instance;
        await session.setActive(true);
      } catch (_) {}
      if (audioPlayer.audioSource == null) {
        final recentSong = _latestResumableSong();
        if (recentSong != null) {
          await _playResumableSong(recentSong);
          return;
        }
      }
      // Do NOT await play(): its future only completes when playback pauses/
      // stops/finishes (just_audio semantics), which would defer the resume
      // below until the song ended - losing the whole session.
      unawaited(
        audioPlayer.play().catchError((Object e, StackTrace stackTrace) async {
          logger.log(
            'Error starting playback',
            error: e,
            stackTrace: stackTrace,
          );
          final ytid = currentSong?['ytid']?.toString() ??
              mediaItem.valueOrNull?.extras?['ytid']?.toString();
          if (ytid != null && ytid.isNotEmpty) {
            await invalidateSongStreamCache(ytid);
            _hub.preloadCache.streamUrls.remove(ytid);
          }
          _playback.lastError = e.toString();
        }),
      );
      _updatePlaybackState();
    } catch (e, stackTrace) {
      logger.log('Error in play()', error: e, stackTrace: stackTrace);
      _playback.lastError = e.toString();
    }
  }

  /// iOS suspends AVPlayer / deactivates the session when the app is
  /// backgrounded. UI can still show playing=true with a drifting position.
  Future<void> resyncAfterForeground() async {
    _logPlayer(
      'App resumed — restoring audio session',
      extra: {
        'uiPlaying': playbackState.valueOrNull?.playing,
        'wasInterrupted': _wasPlayingBeforeInterruption,
      },
    );
    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
    } catch (e, st) {
      logger.log('Failed to reactivate audio session', error: e, stackTrace: st);
    }

    // A song load is already swapping sources — don't fight it.
    if (_currentLoadingTransitionId >= 0) {
      _logPlayer('Resume: load in progress, not kicking player');
      return;
    }

    if (audioPlayer.processingState == ProcessingState.completed) {
      _logPlayer('Resume: player completed — advancing queue');
      _handleProcessingStateChange(ProcessingState.completed);
      return;
    }

    final uiThinksPlaying = playbackState.valueOrNull?.playing == true;
    final shouldPlay =
        uiThinksPlaying ||
        audioPlayer.playing ||
        _wasPlayingBeforeInterruption;
    if (!shouldPlay || audioPlayer.audioSource == null) {
      _updatePlaybackState();
      return;
    }

    try {
      // Only resume when AVPlayer is actually paused. Re-issuing play() while
      // already playing can glitch lock-screen position and cause brief overlap.
      if (!audioPlayer.playing) {
        logger.log('Resume: AVPlayer paused — resuming playback');
        await play();
      }
    } catch (e, st) {
      logger.log('Resume playback failed', error: e, stackTrace: st);
    }
    _updatePlaybackState();
  }

  Future<void> _ensureActuallyPlaying(int? transitionId) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (_isStaleTransition(transitionId)) return;
    if (audioPlayer.playing) return;
    final state = audioPlayer.processingState;
    if (state == ProcessingState.loading ||
        state == ProcessingState.buffering) {
      return;
    }
    if (state == ProcessingState.completed) {
      try {
        await audioPlayer.seek(Duration.zero);
      } catch (_) {}
    }
    if (audioPlayer.audioSource == null) return;
    _logPlayer('Playback idle after source change; issuing one play()');
    // A gentle play() resumes from the current position; it does not seek to 0.
    // Deliberately NOT calling session.setActive(true) here — the session is
    // already active from the load, and re-activating resets the pipeline.
    unawaited(
      audioPlayer.play().catchError((Object e, StackTrace st) {
        logger.log('Retry play() failed', error: e, stackTrace: st);
      }),
    );
  }

  @override
  Future<void> pause() async {
    try {
      await audioPlayer.pause();
      _updatePlaybackState();
    } catch (e, stackTrace) {
      logger.log('Error in pause()', error: e, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> stop() async {
    _debounceTimer?.cancel();
    _sleepTimer?.cancel();
    _sleepTimer = null;
    sleepTimerExpired = false;
    sleepTimerEndOfSong = false;
    sleepTimerNotifier.value = null;
    _completion.reset();
    _hub.queue.loadingIndex = -1;
    _currentLoadingTransitionId = -1;
    _playback.resetInstallState();
    _clearPublishedMediaState();
    try {
      await audioPlayer.stop();
      _resetPreloadingState();
    } catch (e, stackTrace) {
      logger.log('Error in stop()', error: e, stackTrace: stackTrace);
    }
    _updatePlaybackState();
    await super.stop();
  }

  /// Returns unplayed manually added songs after the current queue index.
  List<Map> _getUnplayedManualSongs() {
    return _hub.queue.items
        .skip(_hub.queue.currentIndex >= 0 ? _hub.queue.currentIndex + 1 : 0)
        .where(
          (song) =>
              song['isManuallyAdded'] == true && song['isAutoPicked'] != true,
        )
        .toList();
  }

  void _resetPreloadingState() {
    _hub.resetPreloads();
  }

  @override
  Future<void> seek(Duration position) async {
    final effectiveDuration =
        mediaItem.valueOrNull?.duration ?? audioPlayer.duration;
    var target = position;
    if (target < Duration.zero) {
      target = Duration.zero;
    } else if (effectiveDuration != null &&
        effectiveDuration > const Duration(seconds: 1)) {
      final maxSeek = effectiveDuration - const Duration(milliseconds: 500);
      if (target > maxSeek) {
        target = maxSeek;
      }
    }

    if (_isSeeking) {
      _pendingSeekPosition = target;
      return;
    }

    _isSeeking = true;
    _pendingSeekPosition = null;

    try {
      final wasPlaying = audioPlayer.playing;

      // Perform seek with a 2.5 second timeout so a dropped native AVPlayer callback never hangs the isolate
      await audioPlayer.seek(target).timeout(
        const Duration(milliseconds: 2500),
        onTimeout: () {
          logger.log('audioPlayer.seek timed out on iOS AVPlayer');
        },
      );

      // Verify that if audio was playing, AVPlayer continues playing after seek
      if (wasPlaying && !audioPlayer.playing) {
        await audioPlayer.play();
      }

      _updatePlaybackState();
    } catch (e, stackTrace) {
      logger.log('Error in seek()', error: e, stackTrace: stackTrace);
    } finally {
      _isSeeking = false;
      final nextSeek = _pendingSeekPosition;
      _pendingSeekPosition = null;
      if (nextSeek != null) {
        unawaited(seek(nextSeek));
      }
    }
  }

  @override
  Future<void> fastForward() {
    final target = audioPlayer.position + const Duration(seconds: 15);
    final trackDuration = audioPlayer.duration;
    final clamped = (trackDuration != null && target > trackDuration)
        ? trackDuration
        : target;
    return seek(clamped);
  }

  @override
  Future<void> rewind() {
    final target = audioPlayer.position - const Duration(seconds: 15);
    final clamped = target < Duration.zero ? Duration.zero : target;
    return seek(clamped);
  }

  /// Check if the given transitionId is stale (outdated by a newer request).
  bool _isStaleTransition(int? transitionId) {
    return transitionId != null && transitionId != _currentLoadingTransitionId;
  }

  /// Clears per-track source overrides so global preferredSource applies again.
  void clearPinnedSources() {
    for (final song in _hub.queue.items) {
      song.remove('forceSource');
    }
    for (final song in _hub.queue.originalItems) {
      song.remove('forceSource');
    }
    logger.log('Cleared pinned forceSource on queue entries');
  }

  Future<bool> playSong(
    Map song, {
    String? mediaId,
    int? transitionId,
    Duration? resumeAt,
  }) async {
    final ownsTransition = transitionId == null;
    final effectiveTransitionId = transitionId ?? ++_songTransitionCounter;
    if (ownsTransition) {
      _currentLoadingTransitionId = effectiveTransitionId;
      _hub.queue.markLoading(
        _hub.queue.items.indexWhere(
          (candidate) =>
              candidate['queueEntryId'] == song['queueEntryId'] ||
              candidate['ytid']?.toString() == song['ytid']?.toString(),
        ),
        song,
      );
    }

    try {
      final songData = cloneMap(song);

      if (songData['ytid'] == null || songData['ytid'].toString().isEmpty) {
        logger.log('Invalid song data: missing ytid');
        return false;
      }

      _resetPreloadingState();
      _playback.lastError = null;

      // Detach AVPlayer before any await — pause leaves googlevideo attached
      // and the next setAudioSources fails with iOS -1004.
      if (resumeAt == null) {
        await _playback.detachCurrentStream();
      }

      // INSTANT UI FEEDBACK: emit loading state before any await
      _emitOptimisticLoadingState(
        song: songData,
        includeMediaItem: true,
        mediaId: mediaId,
        // A source switch resumes the same song at its current position.
        freshTrack: resumeAt == null,
      );

      final playback = await _playback.resolvePlaybackSource(
        songData,
        offlineModeEnabled: offlineMode.value,
        preloadedUrls: _hub.preloadCache.streamUrls,
      ).timeout(
        const Duration(seconds: 36),
        onTimeout: () {
          logger.log(
            'Playback source resolution timed out for ${songData['ytid']}',
          );
          return null;
        },
      );

      // Abort if a newer song was requested while we were fetching the stream URL.
      // This is the primary guard against the race condition where a slow streaming
      // load overrides a song the user already switched to.
      if (_isStaleTransition(effectiveTransitionId)) {
        logger.log(
          'Song load superseded by newer request, aborting: ${songData['ytid']}',
        );
        return false;
      }

      if (playback == null) {
        _playback.lastError = 'Failed to get song URL';
        return false;
      }

      // Persist the resolved source on the queue entry for this canonical
      // ytid. The URL is intentionally not part of the song identity; only
      // the source/quality metadata follows the track between services.
      final queueSong = _hub.queue.items.cast<Map?>().firstWhere(
        (candidate) =>
            candidate?['queueEntryId'] == song['queueEntryId'] ||
            (song['queueEntryId'] == null &&
                candidate?['ytid']?.toString() == songData['ytid']?.toString()),
        orElse: () => null,
      );
      if (queueSong != null) {
        queueSong
          ..['isOffline'] = playback.isOffline
          ..['resolvedSource'] = songData['resolvedSource']
          ..['resolvedBitrate'] = songData['resolvedBitrate']
          ..['resolvedFormat'] = songData['resolvedFormat']
          ..['duration'] = songData['duration'] ?? queueSong['duration'];
        _updateQueueMediaItems();
      }
      songData['isOffline'] = playback.isOffline;

      if (songData['resolvedSource'] == 'youtube') {
        unawaited(
          ensureYoutubeCatalogDuration(songData).then((_) {
            if (queueSong != null && songData['duration'] != null) {
              queueSong['duration'] = songData['duration'];
            }
          }),
        );
      }

      // Re-emit mediaItem with the resolved source info so the UI
      // (source icon, download button) reflects the actual playback source.
      final resolvedMediaItem = mapToMediaItem(songData).copyWith(
        id: _hub.queue.entryIds.ensureId(songData),
      );
      _publishMediaItem(resolvedMediaItem);

      final audioSource = await AudioPlaybackInstall.buildSource(
        songData,
        playback.songUrl,
        playback.isOffline,
      );

      // Check again after building the audio source (SponsorBlock fetch can also be slow).
      if (_isStaleTransition(effectiveTransitionId)) {
        logger.log(
          'Song load superseded after building audio source, aborting: ${songData['ytid']}',
        );
        return false;
      }

      if (audioSource == null) {
        logger.log('Failed to build audio source for ${songData['ytid']}');
        _playback.lastError = 'Failed to build audio source';
        return false;
      }

      return await _installPlayback(
        song: songData,
        audioSource: audioSource,
        songUrl: playback.songUrl,
        isOffline: playback.isOffline,
        mediaId: mediaId,
        transitionId: effectiveTransitionId,
        resumeAt: resumeAt,
      );
    } catch (e, stackTrace) {
      logger.log('Error playing song', error: e, stackTrace: stackTrace);
      _playback.lastError = e.toString();
      return false;
    } finally {
      // Do not clear _isUpdatingState here — only _updatePlaybackState owns it.
      if (ownsTransition &&
          _currentLoadingTransitionId == effectiveTransitionId) {
        _hub.queue.loadingIndex = -1;
        _currentLoadingTransitionId = -1;
      }
    }
  }

  /// Re-resolves the current canonical track using one source. The ytid and
  /// queue entry stay unchanged, so switching between providers cannot create
  /// a duplicate track or attach the wrong artwork/history.
  ///
  /// [source] is 'youtube', 'jiosaavn', or 'offline' (play the local file).
  /// Returns the source that actually played (which may differ from the
  /// request when the track isn't on the requested provider), or null on
  /// failure. The chosen source is persisted onto the queue entry so pausing,
  /// resuming, or re-selecting the track keeps the user's choice.
  Future<String?> switchSource(String source) async {
    if (source != 'youtube' && source != 'jiosaavn' && source != 'offline') {
      return null;
    }
    final song = currentSong;
    if (song == null || _songYtid(song) == null) return null;

    final ytid = _songYtid(song)!;
    if (source == 'offline' && !hasPlayableOfflineFile(ytid)) {
      logger.log('Cannot switch to offline — no downloaded file for $ytid');
      return null;
    }
    final previousSource = song['resolvedSource']?.toString() ?? 'youtube';
    if (previousSource == source) {
      logger.log('Source switch no-op, already $source');
      return source;
    }

    if (_playback.sourceSwitchInFlight) {
      logger.log('Source switch already in progress, ignoring');
      return null;
    }
    _playback.sourceSwitchInFlight = true;
    logger.log(
      'Source switch $previousSource → $source',
      data: {'ytid': ytid, 'title': song['title']},
    );

    final resumePosition = audioPlayer.position;
    final shouldResume = audioPlayer.playing ||
        audioPlayer.processingState == ProcessingState.ready ||
        audioPlayer.processingState == ProcessingState.buffering ||
        audioPlayer.processingState == ProcessingState.loading;

    final transitionId = ++_songTransitionCounter;
    _hub.queue.markLoading(_hub.queue.currentIndex, _hub.queue.currentSong);
    _currentLoadingTransitionId = transitionId;
    final request = cloneMap(song)..remove('resolvedSource');
    request.remove('_preloadedStreamUrl');
    _hub.preload.cache.drop(ytid);
    if (source == 'offline') {
      request.remove('forceSource');
    } else {
      request
        ..['forceSource'] = source
        ..remove('isOffline')
        ..remove('audioPath');
    }
    final mediaId = _getMediaItemForQueue(song).id;

    try {
      try {
        if (audioPlayer.playing) {
          await audioPlayer.pause();
        }
      } catch (e, st) {
        logger.log('Pause before source switch failed', error: e, stackTrace: st);
      }

      final success = await playSong(
        request,
        mediaId: mediaId,
        transitionId: transitionId,
        resumeAt: resumePosition > Duration.zero ? resumePosition : null,
      );

      if (_isStaleTransition(transitionId)) {
        return source;
      }

      if (!success) {
        logger.log(
          'Source $source not available for ${song['title']}',
          data: {'hasSource': audioPlayer.audioSource != null},
        );
        if (audioPlayer.audioSource == null) {
          logger.log('Player empty after failed switch — reloading current track');
          unawaited(_playFromQueue(_hub.queue.currentIndex));
        } else if (shouldResume) {
          unawaited(
            audioPlayer.play().catchError((Object e, StackTrace st) {
              logger.log(
                'Resume after failed source switch failed',
                error: e,
                stackTrace: st,
              );
            }),
          );
        }
        _updatePlaybackState();
        return null;
      }

      final queueSong = _hub.queue.items.cast<Map?>().firstWhere(
        (candidate) =>
            candidate?['queueEntryId'] == song['queueEntryId'] ||
            (song['queueEntryId'] == null &&
                candidate?['ytid']?.toString() == ytid),
        orElse: () => null,
      );

      String? actualSource = source;
      if (queueSong != null) {
        actualSource = queueSong['resolvedSource']?.toString() ??
            (queueSong['isOffline'] == true ? 'offline' : source);
        if (actualSource == 'offline') {
          queueSong.remove('forceSource');
          queueSong['isOffline'] = true;
        } else {
          queueSong['forceSource'] = actualSource;
          queueSong['isOffline'] = false;
        }
        _updateQueueMediaItems();
      }

      _updatePlaybackState();
      return actualSource;
    } catch (e, st) {
      logger.log('Error switching source to $source', error: e, stackTrace: st);
      if (shouldResume && audioPlayer.audioSource != null) {
        unawaited(audioPlayer.play().catchError((_) {}));
      }
      _updatePlaybackState();
      return null;
    } finally {
      _playback.sourceSwitchInFlight = false;
      if (_currentLoadingTransitionId == transitionId) {
        _hub.queue.loadingIndex = -1;
        _currentLoadingTransitionId = -1;
      }
    }
  }

  Future<void> playNext(Map song) async {
    await addToQueue(song, playNext: true);
  }

  Future<void> playPlaylistSong({
    Map<dynamic, dynamic>? playlist,
    required int songIndex,
  }) async {
    try {
      if (playlist != null && playlist['list'] != null) {
        await addPlaylistToQueue(
          List<Map>.from(playlist['list']),
          replace: true,
          startIndex: songIndex,
        );
      }
    } catch (e, stackTrace) {
      logger.log('Error playing playlist', error: e, stackTrace: stackTrace);
    }
  }





  Future<void> skipToSong(int newIndex) async {
    try {
      if (newIndex < 0 || newIndex >= _hub.queue.items.length) {
        logger.log('Invalid song index: $newIndex');
        return;
      }
      await _playFromQueue(newIndex);
    } catch (e, stackTrace) {
      logger.log('Error skipping to song', error: e, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) => skipToSong(index);

  @override
  // --- Transport ---

  Future<void> skipToNext() async {
    try {
      if (_hub.queue.currentIndex < _hub.queue.items.length - 1) {
        await _playFromQueue(_hub.queue.currentIndex + 1);
      } else if (repeatNotifier.value == AudioServiceRepeatMode.all &&
          _hub.queue.items.isNotEmpty) {
        await _playFromQueue(0);
      } else if (playNextSongAutomatically.value) {
        final baseSong = _getCurrentSongForRecommendations();
        if (baseSong != null) {
          final ytid = baseSong['ytid']?.toString();
          if (ytid != null && ytid.isNotEmpty) {
            await getSimilarSong(ytid).timeout(
              const Duration(seconds: 6),
              onTimeout: () {
                logger.log('Auto-play similar song fetch timed out');
              },
            );
            if (nextRecommendedSong != null) {
              final songToAdd = nextRecommendedSong;
              nextRecommendedSong = null;
              if (songToAdd != null) {
                await _insertRecommendedSong(songToAdd);
                if (_hub.queue.currentIndex < _hub.queue.items.length - 1) {
                  await _playFromQueue(_hub.queue.currentIndex + 1);
                }
              }
            } else {
              logger.log(
                'Auto-play: no similar song found for $ytid',
              );
            }
          }
        } else {
          logger.log('Auto-play: no base song for recommendations');
        }
      }

      _cleanupOldPreloadedSongs();
    } catch (e, stackTrace) {
      logger.log(
        'Error skipping to next song',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> skipToPrevious() async {
    try {
      if (_hub.queue.currentIndex > 0) {
        await _playFromQueue(_hub.queue.currentIndex - 1);
      } else if (_hub.queue.history.isNotEmpty) {
        final lastSong = cloneMap(_hub.queue.history.removeLast());
        _hub.queue.items.insert(0, lastSong);
        _hub.queue.currentIndex = 0;
        _updateQueueMediaItems();
        await _playFromQueue(0);
      }

      _cleanupOldPreloadedSongs();
    } catch (e, stackTrace) {
      logger.log(
        'Error skipping to previous song',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> playAgain() async {
    try {
      await seek(Duration.zero);
      unawaited(
        audioPlayer.play().catchError((Object e, StackTrace stackTrace) {
          logger.log(
            'Error restarting playback',
            error: e,
            stackTrace: stackTrace,
          );
        }),
      );
      final song = currentSong;
      if (song != null) {
        unawaited(updateRecentlyPlayed(song['ytid'], songFallback: song));
      }
    } catch (e, stackTrace) {
      logger.log('Error playing again', error: e, stackTrace: stackTrace);
    }
  }

  Map<Map, String> _buildIdMap(List<Map> songs) {
    return {for (final song in songs) song: _hub.queue.entryIds.ensureId(song)};
  }

  void _enableShuffle(
    List<Map> unplayedManualSongs,
    Set<String> manualSongIds,
  ) {
    _hub.queue.originalItems
      ..clear()
      ..addAll(cloneMaps(_hub.queue.items));

    final currentSong = _hub.queue.items[_hub.queue.currentIndex];
    final currentQueueEntryId = _hub.queue.entryIds.ensureId(currentSong);

    final queueIdMap = _buildIdMap(_hub.queue.items);
    _hub.queue.items
      ..removeWhere((song) => manualSongIds.contains(queueIdMap[song]))
      ..shuffle();

    final newCurrentIndex = _hub.queue.items.indexWhere(
      (song) => _hub.queue.entryIds.ensureId(song) == currentQueueEntryId,
    );

    if (newCurrentIndex != -1 && newCurrentIndex != 0) {
      _hub.queue.items
        ..removeAt(newCurrentIndex)
        ..insert(0, currentSong);
    }

    _hub.queue.items.insertAll(_hub.queue.items.isNotEmpty ? 1 : 0, unplayedManualSongs);

    _hub.queue.currentIndex = 0;
    _updateQueueMediaItems();
  }

  void _disableShuffle(
    List<Map> unplayedManualSongs,
    Set<String> manualSongIds,
  ) {
    if (_hub.queue.originalItems.isEmpty) return;

    final currentSong = _hub.queue.items[_hub.queue.currentIndex];
    final currentQueueEntryId = _hub.queue.entryIds.ensureId(currentSong);

    final restoredQueue = cloneMaps(_hub.queue.originalItems);
    final restoredQueueIdMap = _buildIdMap(restoredQueue);
    restoredQueue.removeWhere(
      (song) => manualSongIds.contains(restoredQueueIdMap[song]),
    );

    _hub.queue.items
      ..clear()
      ..addAll(restoredQueue);

    _hub.queue.currentIndex = _hub.queue.items.indexWhere(
      (song) => _hub.queue.entryIds.ensureId(song) == currentQueueEntryId,
    );

    if (_hub.queue.currentIndex == -1) {
      _hub.queue.currentIndex = 0;
    }

    final insertIndex = _hub.queue.currentIndex + 1;
    _hub.queue.items.insertAll(insertIndex, unplayedManualSongs);

    _hub.queue.originalItems.clear();
    _updateQueueMediaItems();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    try {
      final shuffleEnabled = shuffleMode != AudioServiceShuffleMode.none;
      final wasShuffled = shuffleNotifier.value;

      shuffleNotifier.value = shuffleEnabled;
      unawaited(Hive.box('settings').put('shuffleEnabled', shuffleEnabled));
      await audioPlayer.setShuffleModeEnabled(shuffleEnabled);

      if (_hub.queue.items.isEmpty) return;

      if (shuffleEnabled && !wasShuffled) {
        _hydrateQueueEntryIds();
        final unplayedManualSongs = _getUnplayedManualSongs();
        final manualSongIds = unplayedManualSongs
            .map(_hub.queue.entryIds.ensureId)
            .toSet();
        _enableShuffle(unplayedManualSongs, manualSongIds);
      } else if (!shuffleEnabled && wasShuffled) {
        _hydrateQueueEntryIds();
        final unplayedManualSongs = _getUnplayedManualSongs();
        final manualSongIds = unplayedManualSongs
            .map(_hub.queue.entryIds.ensureId)
            .toSet();
        _disableShuffle(unplayedManualSongs, manualSongIds);
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error setting shuffle mode',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    try {
      repeatNotifier.value = repeatMode;
      unawaited(Hive.box('settings').put('repeatMode', repeatMode.index));

      // Always set loop mode to off - completion coordinator advances the queue.
      // This ensures ProcessingState.completed is always fired for proper song transitions
      await audioPlayer.setLoopMode(LoopMode.off);
    } catch (e, stackTrace) {
      logger.log('Error setting repeat mode', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> setSleepTimer(Duration duration) async {
    try {
      _sleepTimer?.cancel();
      sleepTimerExpired = false;
      sleepTimerNotifier.value = duration;

      _sleepTimer = Timer(duration, () async {
        sleepTimerExpired = true;
        await stop();
        sleepTimerNotifier.value = null;
      });
    } catch (e, stackTrace) {
      logger.log('Error setting sleep timer', error: e, stackTrace: stackTrace);
    }
  }

  void cancelSleepTimer() {
    try {
      _sleepTimer?.cancel();
      _sleepTimer = null;
      sleepTimerExpired = false;
      sleepTimerEndOfSong = false;
      sleepTimerNotifier.value = null;
    } catch (e, stackTrace) {
      logger.log(
        'Error canceling sleep timer',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> setSleepTimerEndOfSong() async {
    try {
      _sleepTimer?.cancel();
      sleepTimerExpired = false;
      sleepTimerEndOfSong = true;
      sleepTimerNotifier.value = const Duration(milliseconds: -1);
    } catch (e, stackTrace) {
      logger.log(
        'Error setting sleep timer end of song',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    try {
      switch (name) {
        case 'clearQueue':
          clearQueue();
          break;
        case 'addToQueue':
          if (extras?['song'] != null) {
            await addToQueue(
              extras!['song'] as Map,
              playNext: extras['playNext'] ?? false,
            );
          }
          break;
        case 'removeFromQueue':
          if (extras?['index'] != null) {
            await removeFromQueue(extras!['index'] as int);
          }
          break;
        case 'reorderQueue':
          if (extras?['oldIndex'] != null && extras?['newIndex'] != null) {
            await reorderQueue(
              extras!['oldIndex'] as int,
              extras['newIndex'] as int,
            );
          }
          break;
        default:
          await super.customAction(name, extras);
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error in customAction: $name',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}