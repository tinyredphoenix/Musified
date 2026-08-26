/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Musify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Musify, including how to contribute,
 *     please visit: https://github.com/gokadzev/Musify
 */

import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:musify/main.dart';
import 'package:musify/models/full_player_state.dart';
import 'package:musify/models/position_data.dart';
import 'package:musify/services/common_services.dart';

import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/map_utils.dart';
import 'package:musify/utilities/mediaitem.dart';
import 'package:musify/utilities/queue_entry_utils.dart';
import 'package:rxdart/rxdart.dart';

class MusifyAudioHandler extends BaseAudioHandler {
  MusifyAudioHandler() {
    audioPlayer = AudioPlayer();
    _setupEventSubscriptions();
    _updatePlaybackState();
    _initialize();
  }

  late final AudioPlayer audioPlayer;

  Timer? _sleepTimer;
  Timer? _debounceTimer;
  bool sleepTimerExpired = false;
  bool sleepTimerEndOfSong = false;

  final List<Map> _queueList = [];
  final List<Map> _originalQueueList = [];
  final List<Map> _historyList = [];
  final BehaviorSubject<List<Map>> _queueMapStream =
      BehaviorSubject<List<Map>>.seeded([]);
  final QueueEntryIdManager _queueEntryIds = QueueEntryIdManager();
  int _currentQueueIndex = 0;
  int _currentLoadingIndex = -1;
  int _currentLoadingTransitionId = -1;
  // Duration events are not tagged with their source by just_audio. Keep the
  // transition that installed the active source so a late event from the
  // previous track cannot overwrite the new MediaItem duration.
  int? _installedSourceTransitionId;
  bool _isUpdatingState = false;
  bool _pendingPlaybackStateUpdate = false;
  int _songTransitionCounter = 0;

  bool _isSeeking = false;
  Duration? _pendingSeekPosition;
  bool _wasPlayingBeforeInterruption = false;

  bool _completionEventPending = false;
  bool _completionHandlerLoadStarted = false;
  bool _sourceSwitchInFlight = false;
  bool _handlingNativeAdvance = false;

  String? _lastError;
  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 3;

  static const int _maxHistorySize = 50;
  // Resolve only the next item, and never compete with the foreground load.
  // Multiple manifest requests were saturating the connection and making a
  // user-initiated tap wait behind two background YouTube requests.
  static const int _queueLookahead = 1;
  static const int _maxConcurrentPreloads = 1;
  static const Duration _errorRetryDelay = Duration(seconds: 1);
  static const Duration _songTransitionTimeout = Duration(seconds: 6);
  static const Duration _debounceInterval = Duration(milliseconds: 80);
  static const Duration _positionDataThreshold = Duration(milliseconds: 250);
  static const Duration _playbackStateHeartbeat = Duration(seconds: 1);

  static const String _recentMediaIdPrefix = 'recent:';

  int _activePreloadCount = 0;
  final Set<String> _preloadingYtIds = <String>{};
  final Set<String> _preloadedYtIds = <String>{};

  late final Stream<PositionData> _positionDataStream =
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
        audioPlayer.positionStream,
        audioPlayer.bufferedPositionStream,
        audioPlayer.durationStream,
        (position, bufferedPosition, duration) =>
            PositionData(position, bufferedPosition, duration ?? Duration.zero),
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
      Rx.combineLatest3(
        playbackStateStream,
        queue.distinct(),
        positionDataStream,
        (PlaybackState state, List<MediaItem> queueItems, PositionData pos) =>
            FullPlayerState(
              playbackState: state,
              queue: queueItems,
              position: pos,
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
    final hasMultipleTracks = _queueList.length > 1;
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
    _subscriptions.add(
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
    );

    _subscriptions.add(
      audioPlayer.processingStateStream.distinct().listen(
        _handleProcessingStateChange,
        onError: (error, stackTrace) {
          _logStreamError('Processing state stream error', error, stackTrace);
        },
      ),
    );

    _subscriptions.add(
      audioPlayer.positionStream
          .throttleTime(const Duration(milliseconds: 250))
          .listen(
            _handleNearEndSkip,
            onError: (error, stackTrace) {
              _logStreamError('Position stream error', error, stackTrace);
            },
          ),
    );

    _subscriptions.add(
      audioPlayer.durationStream.listen(
        (duration) {
          final transitionInProgress = _currentLoadingTransitionId >= 0;
          final sourceBelongsToCurrentTransition =
              !transitionInProgress ||
              _installedSourceTransitionId == _currentLoadingTransitionId;
          if (sourceBelongsToCurrentTransition &&
              _currentQueueIndex < _queueList.length &&
              duration != null) {
            _updateCurrentMediaItemWithDuration(duration);
          }
        },
        onError: (error, stackTrace) {
          _logStreamError('Duration stream error', error, stackTrace);
        },
      ),
    );

    _subscriptions.add(
      audioPlayer.playerStateStream
          .distinct()
          .throttleTime(const Duration(milliseconds: 100))
          .listen(
            (state) {
              if (state.processingState == ProcessingState.idle &&
                  !state.playing &&
                  _lastError != null) {
                Future.microtask(_handlePlaybackError);
              }
              _debouncedStateUpdate();
            },
            onError: (error, stackTrace) {
              _logStreamError('Player state stream error', error, stackTrace);
            },
          ),
    );

    _subscriptions.add(
      Rx.combineLatest2(
            audioPlayer.currentIndexStream.distinct(),
            audioPlayer.sequenceStateStream.distinct(),
            (index, sequence) => {'index': index, 'sequence': sequence},
          )
          .throttleTime(const Duration(milliseconds: 100))
          .listen(
            (data) {
              _debouncedStateUpdate();
              final index = data['index'] as int?;
              if (index != null && index > 0) {
                unawaited(_onNativeQueueAdvanced(index));
              }
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
    _queueEntryIds
      ..ensureIds(_queueList)
      ..ensureIds(_originalQueueList);
  }

  MediaItem _getMediaItemForQueue(Map song) {
    return mapToMediaItem(song).copyWith(id: _queueEntryIds.ensureId(song));
  }

  List<MediaItem> _buildQueueMediaItems() =>
      _queueList.map(_getMediaItemForQueue).toList(growable: false);

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
      final queueIndex = _currentQueueIndex;
      if (queueIndex < 0 || queueIndex >= _queueList.length) return;

      final currentSong = _queueList[queueIndex];
      final currentMediaItem = _getMediaItemForQueue(currentSong);
      final currentSongYtid = currentSong['ytid']?.toString();
      final currentItem = mediaItem.valueOrNull;
      final isMatchingCurrentItem = _isCurrentMediaItemMatchingSong(
        currentItem,
        currentMediaItem,
        currentSongYtid,
      );

      if (currentItem != null &&
          isMatchingCurrentItem &&
          _shouldUpdateDuration(currentItem.duration, duration)) {
        mediaItem.add(currentItem.copyWith(duration: duration));
      } else if (!isMatchingCurrentItem) {
        mediaItem.add(currentMediaItem.copyWith(duration: duration));
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
          if (event.begin) {
            if (event.type == AudioInterruptionType.duck) {
              unawaited(audioPlayer.setVolume(0.5));
            } else {
              _wasPlayingBeforeInterruption = audioPlayer.playing;
              if (_wasPlayingBeforeInterruption) {
                unawaited(pause());
              }
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

      // Always set loop mode to off - we handle all repeating through _handleSongCompletion
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
      final currentPosition = audioPlayer.position;
      final isPlaying = audioPlayer.playing;
      final currentState = playbackState.valueOrNull;
      final newProcessingState =
          _processingStateMap[audioPlayer.processingState] ??
          AudioProcessingState.idle;
      final bufferedPosition = audioPlayer.bufferedPosition;

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
          currentState.queueIndex != _currentQueueIndex ||
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
                _currentQueueIndex >= 0 &&
                    _currentQueueIndex < _queueList.length
                ? _currentQueueIndex
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
        if (sleepTimerEndOfSong) {
          sleepTimerExpired = true;
          sleepTimerEndOfSong = false;
          stop();
          sleepTimerNotifier.value = null;
          return;
        }

        if (!sleepTimerExpired && !_completionEventPending) {
          if (_nativeHasSuccessor) {
            logger.log('Track ended — native AV queue will auto-advance');
            return;
          }
          _completionEventPending = true;
          logger.log('Track completed — Dart advancing queue');
          unawaited(_runSongCompletion());
        }
      } else if (state == ProcessingState.ready) {
        _completionEventPending = false;
        _completionHandlerLoadStarted = false;
        sleepTimerExpired = false;
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error handling processing state change',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  bool get _nativeHasSuccessor {
    final seq = audioPlayer.sequence;
    if (seq.length < 2) return false;
    final index = audioPlayer.currentIndex ?? 0;
    return index < seq.length - 1;
  }

  void _handleNearEndSkip(Duration position) {
    if (_completionEventPending || sleepTimerExpired) return;
    if (_nativeHasSuccessor || _handlingNativeAdvance) return;
    if (!audioPlayer.playing) return;
    if (audioPlayer.processingState == ProcessingState.completed) return;
    final duration = audioPlayer.duration;
    if (duration == null || duration < const Duration(seconds: 5)) return;
    final remaining = duration - position;
    if (remaining > const Duration(milliseconds: 450) || remaining.isNegative) {
      return;
    }
    logger.log(
      'Near end of track (${remaining.inMilliseconds}ms left) — advancing',
    );
    _handleProcessingStateChange(ProcessingState.completed);
  }

  Future<void> _runSongCompletion() async {
    try {
      if (!sleepTimerExpired && _completionEventPending) {
        await _handleSongCompletion();
      }
    } finally {
      if (_completionEventPending) {
        _completionEventPending = false;
        _completionHandlerLoadStarted = false;
      }
    }
  }

  /// Spotify / Apple Music / YT Music keep the next item in the native
  /// AVQueuePlayer. When the current file ends, iOS starts the successor
  /// without waiting for Dart (which is often frozen while the phone is locked).
  Future<void> _onNativeQueueAdvanced(int nativeIndex) async {
    if (_handlingNativeAdvance || nativeIndex < 1) return;
    _handlingNativeAdvance = true;
    try {
      final newIndex = _currentQueueIndex + 1;
      if (newIndex >= _queueList.length) {
        if (repeatNotifier.value == AudioServiceRepeatMode.all &&
            _queueList.isNotEmpty) {
          _handlingNativeAdvance = false;
          await _playFromQueue(0);
          return;
        }
        return;
      }
      if (_currentQueueIndex >= 0 && _currentQueueIndex < _queueList.length) {
        _addToHistory(_queueList[_currentQueueIndex]);
      }
      _currentQueueIndex = newIndex;
      final song = _queueList[newIndex];
      mediaItem.add(_getMediaItemForQueue(song));
      logger.log('Native AV queue advanced → ${song['title']}');
      try {
        while (audioPlayer.sequence.length > 1 &&
            (audioPlayer.currentIndex ?? 0) > 0) {
          await audioPlayer.removeAudioSourceAt(0);
        }
      } catch (e) {
        logger.log('Native queue compact failed', error: e);
      }
      _completionEventPending = false;
      _completionHandlerLoadStarted = false;
      _updatePlaybackState();
      unawaited(
        updateRecentlyPlayed(song['ytid'], songFallback: song),
      );
      unawaited(_armNativeSuccessor());
    } catch (e, st) {
      logger.log('Native auto-advance failed', error: e, stackTrace: st);
    } finally {
      _handlingNativeAdvance = false;
    }
  }

  Future<void> _armNativeSuccessor() async {
    if (repeatNotifier.value == AudioServiceRepeatMode.one) return;
    if (audioPlayer.sequence.isEmpty) return;

    var nextIndex = _currentQueueIndex + 1;
    if (nextIndex >= _queueList.length) {
      if (repeatNotifier.value == AudioServiceRepeatMode.all &&
          _queueList.isNotEmpty) {
        nextIndex = 0;
      } else {
        return;
      }
    }
    if (nextIndex == _currentQueueIndex) return;

    try {
      while (audioPlayer.sequence.length > 1) {
        await audioPlayer.removeAudioSourceAt(
          audioPlayer.sequence.length - 1,
        );
      }
      final song = cloneMap(_queueList[nextIndex]);
      final playback = await _resolvePlaybackSource(song);
      if (playback == null) return;
      final source = await buildAudioSource(
        song,
        playback.songUrl,
        playback.isOffline,
      );
      if (source == null) return;
      await audioPlayer.addAudioSource(source);
      logger.log('Armed native successor: ${song['title']}');
    } catch (e, st) {
      logger.log('Failed to arm native successor', error: e, stackTrace: st);
    }
  }

  bool _canRetryPlayback() =>
      hasNext ||
      (repeatNotifier.value == AudioServiceRepeatMode.all &&
          _queueList.isNotEmpty) ||
      playNextSongAutomatically.value;

  void _handlePlaybackError({bool advance = true}) {
    _consecutiveErrors++;
    logger.log(
      'Playback error occurred. Consecutive errors: $_consecutiveErrors',
      error: _lastError,
    );

    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      logger.log('Max consecutive errors reached. Stopping playback.');
      stop();
      return;
    }

    // A failed user selection must not silently jump to another queue item.
    // That behavior made a slow/invalid stream look like the wrong song was
    // playing. Automatic advancement remains enabled for genuine player
    // failures reported by just_audio during an active queue.
    if (advance && _canRetryPlayback()) {
      Future.delayed(_errorRetryDelay, skipToNext);
    } else {
      _lastError = null;
    }
  }

  Future<void> _handleSongCompletion() async {
    try {
      if (_currentQueueIndex >= 0 && _currentQueueIndex < _queueList.length) {
        _addToHistory(_queueList[_currentQueueIndex]);
      }

      // Determine what to play next based on queue position and repeat mode
      if (repeatNotifier.value == AudioServiceRepeatMode.one) {
        // Repeat single song - play current song again
        await playAgain();
      } else {
        // For all other cases (next song, repeat all, auto-play), skipToNext handles it
        await skipToNext();
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error handling song completion',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _backgroundAddSongsToQueue() async {
    // Fire and forget - this runs as a background task without blocking playback
    if (offlineMode.value) return;

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
      _historyList.insert(0, cloneMap(song));

      if (_historyList.length > _maxHistorySize) {
        _historyList.removeRange(_maxHistorySize, _historyList.length);
      }
    } catch (e, stackTrace) {
      logger.log('Error adding to history', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> addToQueue(Map song, {bool playNext = false}) async {
    try {
      if (song['ytid'] == null || song['ytid'].toString().isEmpty) {
        logger.log('Invalid song data for queue');
        return;
      }

      int insertIndex;

      if (playNext) {
        insertIndex = _currentQueueIndex + 1;
        if (insertIndex < 0) insertIndex = 0;
        if (insertIndex > _queueList.length) {
          insertIndex = _queueList.length;
        }
      } else {
        insertIndex = _queueList.length;
      }

      final queueSong = _queueEntryIds.createSong(song);
      queueSong['isManuallyAdded'] = true;
      _queueList.insert(insertIndex, queueSong);

      if (_currentQueueIndex < 0) {
        _currentQueueIndex = 0;
      }

      _updateQueueMediaItems();
      _cleanupOldPreloadedSongs();

      if (!audioPlayer.playing && _queueList.length == 1) {
        await _playFromQueue(0);
      }
    } catch (e, stackTrace) {
      logger.log('Error adding to queue', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _insertRecommendedSong(Map song) async {
    try {
      if (song['ytid'] == null || song['ytid'].toString().isEmpty) {
        logger.log('Invalid recommended song data for queue');
        return;
      }

      final insertIndex = _queueList.length;
      final shouldPlayInsertedSong =
          playNextSongAutomatically.value &&
          !sleepTimerExpired &&
          _currentLoadingIndex == -1 &&
          audioPlayer.processingState == ProcessingState.completed &&
          _queueList.isNotEmpty &&
          _currentQueueIndex == _queueList.length - 1;
      final queueSong = _queueEntryIds.createSong(song);
      queueSong['isAutoPicked'] = true;
      _queueList.insert(insertIndex, queueSong);

      if (_currentQueueIndex < 0) {
        _currentQueueIndex = 0;
      }

      _updateQueueMediaItems();
      _cleanupOldPreloadedSongs();

      if (shouldPlayInsertedSong) {
        await _playFromQueue(insertIndex);
      } else if (!audioPlayer.playing && _queueList.length == 1) {
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
    Future.microtask(() async {
      try {
        final queueYtIds = _queueList
            .map((song) => song['ytid']?.toString())
            .where((ytid) => ytid != null)
            .toSet();

        final oldPreloadedSongs = _preloadedYtIds
            .where((ytid) => !queueYtIds.contains(ytid))
            .toList();

        for (final ytid in oldPreloadedSongs) {
          _preloadedYtIds.remove(ytid);
        }

        final stalePreloadingEntries = _preloadingYtIds
            .where((ytid) => !queueYtIds.contains(ytid))
            .toList();

        for (final ytid in stalePreloadingEntries) {
          _preloadingYtIds.remove(ytid);
        }

        if (oldPreloadedSongs.isNotEmpty || stalePreloadingEntries.isNotEmpty) {
          logger.log(
            'Cleaned up ${oldPreloadedSongs.length + stalePreloadingEntries.length} old preload entries',
          );
        }
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
        _queueList.clear();
        _originalQueueList.clear();
        _currentQueueIndex = 0;
        _currentLoadingIndex = -1;
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
          _queueList.add(_queueEntryIds.createSong(song));

          if (replace && startIndex == i) {
            targetQueueIndex = _queueList.length - 1;
          }
        }
      }

      if (replace && manuallyAddedSongs.isNotEmpty) {
        // Always insert after the starting song index
        final insertIndex = (targetQueueIndex ?? 0) + 1;
        final safeInsertIndex = insertIndex > _queueList.length
            ? _queueList.length
            : insertIndex;
        _queueList.insertAll(safeInsertIndex, manuallyAddedSongs);
      }

      _hydrateQueueEntryIds();
      _updateQueueMediaItems();

      if (targetQueueIndex != null) {
        await _playFromQueue(targetQueueIndex);
      } else if (startIndex != null &&
          startIndex < _queueList.length &&
          !replace) {
        await _playFromQueue(startIndex);
      } else if (replace && _queueList.isNotEmpty) {
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
      if (index < 0 || index >= _queueList.length) return;

      final removedSong = _queueList[index];
      final removedQueueEntryId = _queueEntryIds.ensureId(removedSong);
      _queueList.removeAt(index);

      if (shuffleNotifier.value && _originalQueueList.isNotEmpty) {
        _originalQueueList.removeWhere(
          (s) => _queueEntryIds.ensureId(s) == removedQueueEntryId,
        );
      }

      if (index == _currentLoadingIndex) {
        _currentLoadingIndex = -1;
        _currentLoadingTransitionId = -1;
      } else if (index < _currentLoadingIndex) {
        _currentLoadingIndex--;
      }

      if (index < _currentQueueIndex) {
        _currentQueueIndex--;
      } else if (index == _currentQueueIndex) {
        if (_queueList.isEmpty) {
          await stop();
        } else {
          if (_currentQueueIndex >= _queueList.length) {
            _currentQueueIndex = _queueList.length - 1;
          }
          await _playFromQueue(_currentQueueIndex);
        }
      }

      _hydrateQueueEntryIds();
      _updateQueueMediaItems();
    } catch (e, stackTrace) {
      logger.log('Error removing from queue', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    try {
      _queueEntryIds.ensureIds(_queueList);

      if (oldIndex < 0 ||
          oldIndex >= _queueList.length ||
          newIndex < 0 ||
          newIndex > _queueList.length - 1) {
        return;
      }

      final song = _queueList.removeAt(oldIndex);
      _queueList.insert(newIndex, song);

      if (oldIndex == _currentQueueIndex) {
        _currentQueueIndex = newIndex;
      } else if (oldIndex < _currentQueueIndex &&
          newIndex >= _currentQueueIndex) {
        _currentQueueIndex--;
      } else if (oldIndex > _currentQueueIndex &&
          newIndex <= _currentQueueIndex) {
        _currentQueueIndex++;
      }

      // Also update _currentLoadingIndex if the currently-loading song is being reordered
      if (oldIndex == _currentLoadingIndex) {
        _currentLoadingIndex = newIndex;
      } else if (oldIndex < _currentLoadingIndex &&
          newIndex >= _currentLoadingIndex) {
        _currentLoadingIndex--;
      } else if (oldIndex > _currentLoadingIndex &&
          newIndex <= _currentLoadingIndex) {
        _currentLoadingIndex++;
      }

      _updateQueueMediaItems();
    } catch (e, stackTrace) {
      logger.log('Error reordering queue', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> reorderQueueById(String queueEntryId, int targetIndex) async {
    try {
      _queueEntryIds.ensureIds(_queueList);

      final oldIndex = _queueList.indexWhere(
        (s) => _queueEntryIds.ensureId(s) == queueEntryId,
      );
      if (oldIndex == -1) return;

      // Clamp target index to valid range (allow insert at end)
      if (targetIndex < 0) targetIndex = 0;
      if (targetIndex > _queueList.length) targetIndex = _queueList.length;

      final song = _queueList.removeAt(oldIndex);
      var newIndex = targetIndex;
      if (oldIndex < newIndex) newIndex--;
      if (newIndex < 0) newIndex = 0;
      if (newIndex > _queueList.length) newIndex = _queueList.length;
      _queueList.insert(newIndex, song);

      if (oldIndex == _currentQueueIndex) {
        _currentQueueIndex = newIndex;
      } else if (oldIndex < _currentQueueIndex &&
          newIndex >= _currentQueueIndex) {
        _currentQueueIndex--;
      } else if (oldIndex > _currentQueueIndex &&
          newIndex <= _currentQueueIndex) {
        _currentQueueIndex++;
      }

      if (oldIndex == _currentLoadingIndex) {
        _currentLoadingIndex = newIndex;
      } else if (oldIndex < _currentLoadingIndex &&
          newIndex >= _currentLoadingIndex) {
        _currentLoadingIndex--;
      } else if (oldIndex > _currentLoadingIndex &&
          newIndex <= _currentLoadingIndex) {
        _currentLoadingIndex++;
      }

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
      final currentSong =
          _currentQueueIndex >= 0 && _currentQueueIndex < _queueList.length
          ? cloneMap(_queueList[_currentQueueIndex])
          : null;

      _queueList.clear();
      _originalQueueList.clear();

      if (currentSong != null) {
        final kept = _queueEntryIds.createSong(currentSong);
        _queueList.add(kept);
        _originalQueueList.add(cloneMap(kept));
      }

      _historyList.clear();

      _currentQueueIndex = 0;
      _currentLoadingIndex = -1;
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
      _queueEntryIds.ensureIds(_queueList);

      final mediaItems = _buildQueueMediaItems();
      queue.add(mediaItems);

      _queueMapStream.add(List.unmodifiable(_queueList));

      if (_currentQueueIndex < mediaItems.length) {
        final currentMediaItem = mediaItems[_currentQueueIndex];
        mediaItem.add(currentMediaItem);
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
  }) {
    try {
      if (includeMediaItem && song != null) {
        var immediateMediaItem = mapToMediaItem(song);
        if (mediaId != null) {
          immediateMediaItem = immediateMediaItem.copyWith(id: mediaId);
        }
        Future.microtask(() {
          mediaItem.add(immediateMediaItem);
        });
      }

      // Keep playing=true and current position so a mid-stream source switch
      // does not flash a paused/zeroed mini-player while the new URL loads.
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
          updatePosition: audioPlayer.position,
          bufferedPosition: audioPlayer.bufferedPosition,
          speed: audioPlayer.speed,
          queueIndex:
              queueIndex ??
              (_currentQueueIndex < _queueList.length
                  ? _currentQueueIndex
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

  Future<void> _playFromQueue(int index) async {
    if (index < 0 || index >= _queueList.length) {
      logger.log('Invalid queue index: $index');
      return;
    }

    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
    } catch (_) {}

    // If already loading any song, skip the request
    // UNLESS we're in the middle of handling a completion event (allow one load attempt)
    if (_currentLoadingIndex == index && !_completionEventPending) {
      return;
    }

    if (_currentLoadingIndex >= 0 &&
        _completionEventPending &&
        !_completionHandlerLoadStarted) {
      _completionHandlerLoadStarted = true;
    } else if (_currentLoadingIndex >= 0 &&
        _completionEventPending &&
        _completionHandlerLoadStarted) {
      return;
    }

    // Start new transition
    _songTransitionCounter++;
    final currentTransitionId = _songTransitionCounter;
    _currentLoadingIndex = index;
    _currentLoadingTransitionId = currentTransitionId;

    try {
      final previousQueueIndex = _currentQueueIndex;
      final previousMediaItem = mediaItem.valueOrNull;
      _currentQueueIndex = index;

      final currentSong = _queueList[_currentQueueIndex];
      final currentMediaItem = _getMediaItemForQueue(currentSong);
      final uniqueId = currentMediaItem.id;

      await Future.microtask(() {
        mediaItem.add(currentMediaItem);
      });

      _emitOptimisticLoadingState(
        queueIndex: _currentQueueIndex,
        mediaId: uniqueId,
      );

      final success = await playSong(
        _queueList[index],
        mediaId: uniqueId,
        transitionId: currentTransitionId,
      );

      // Only process result if this is still the current transition
      if (currentTransitionId == _currentLoadingTransitionId) {
        if (success) {
          _consecutiveErrors = 0;
          _preloadUpcomingSongs();
          // Trigger background song addition if auto-play is enabled
          if (playNextSongAutomatically.value) {
            unawaited(_backgroundAddSongsToQueue());
          }
        } else {
          _currentQueueIndex = previousQueueIndex;
          if (previousMediaItem != null) {
            mediaItem.add(previousMediaItem);
          }
          _updatePlaybackState();
          _handlePlaybackError(advance: false);
        }
      }
    } catch (e, stackTrace) {
      logger.log('Error playing from queue', error: e, stackTrace: stackTrace);
      _handlePlaybackError(advance: false);
    } finally {
      // Only reset if this is still the transition that started it
      if (currentTransitionId == _currentLoadingTransitionId) {
        _currentLoadingIndex = -1;
        _currentLoadingTransitionId = -1;
      }
    }
  }

  void _preloadUpcomingSongs() {
    // Don't attempt to preload while offline mode is enabled
    if (offlineMode.value || _currentLoadingTransitionId != -1) return;

    Future.microtask(() async {
      try {
        if (_currentLoadingTransitionId != -1) return;
        final songsToPreload = <Map>[];

        for (var i = 1; i <= _queueLookahead; i++) {
          final nextIndex = _currentQueueIndex + i;
          if (nextIndex < _queueList.length) {
            final nextSong = _queueList[nextIndex];
            final ytid = nextSong['ytid'];

            if (ytid != null &&
                !isSongAlreadyOffline(ytid) &&
                !_preloadedYtIds.contains(ytid) &&
                !_preloadingYtIds.contains(ytid)) {
              songsToPreload.add(nextSong);
            }
          }
        }

        await _preloadSongsSequentially(songsToPreload);
      } catch (e, stackTrace) {
        logger.log(
          'Error in _preloadUpcomingSongs',
          error: e,
          stackTrace: stackTrace,
        );
      }
    });
  }

  Future<void> _preloadSongsSequentially(List<Map> songsToPreload) async {
    for (final song in songsToPreload) {
      if (_currentLoadingTransitionId != -1) return;
      while (_activePreloadCount >= _maxConcurrentPreloads) {
        if (_currentLoadingTransitionId != -1) return;
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final ytid = song['ytid'];
      if (ytid == null || _preloadingYtIds.contains(ytid)) {
        continue;
      }

      unawaited(_preloadSingleSongControlled(song));
    }
  }

  Future<void> _preloadSingleSongControlled(Map nextSong) async {
    final ytid = nextSong['ytid'];
    if (ytid == null || _currentLoadingTransitionId != -1) return;

    _preloadingYtIds.add(ytid);
    _activePreloadCount++;
    String? preloadUrl;

    try {
      // Don't attempt to fetch remote streams while offline mode is enabled
      if (offlineMode.value) {
        logger.log('Offline mode enabled; skipping preload for $ytid');
        preloadUrl = null;
      } else {
        // fetchSongStreamUrl handles caching, freshness checks, and validation
        preloadUrl =
            await fetchSongStreamUrl(
              nextSong,
              nextSong['isLive'] ?? false,
            ).timeout(
              const Duration(seconds: 8),
              onTimeout: () {
                logger.log('Preload timeout for song $ytid');
                return null;
              },
            );
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error preloading song $ytid',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _preloadingYtIds.remove(ytid);
      if (_activePreloadCount > 0) {
        _activePreloadCount--;
      }
      if (preloadUrl != null && preloadUrl.isNotEmpty) {
        _preloadedYtIds.add(ytid);
      }
    }
  }

  Stream<List<Map>> get queueAsMapStream => _queueMapStream.stream;
  int get currentQueueIndex => _currentQueueIndex;
  Map? get currentSong =>
      _currentQueueIndex >= 0 && _currentQueueIndex < _queueList.length
      ? _queueList[_currentQueueIndex]
      : null;

  bool get hasNext =>
      _currentQueueIndex < _queueList.length - 1 ||
      repeatNotifier.value == AudioServiceRepeatMode.all;

  bool get hasPrevious => _currentQueueIndex > 0 || _historyList.isNotEmpty;

  String _recentMediaId(String ytid) => '$_recentMediaIdPrefix$ytid';

  String? _ytidFromMediaId(String mediaId) {
    if (mediaId.startsWith(_recentMediaIdPrefix)) {
      return mediaId.substring(_recentMediaIdPrefix.length);
    }
    return mediaId.isEmpty ? null : mediaId;
  }

  String? _songYtid(Map song) {
    final ytid = song['ytid']?.toString();
    return ytid == null || ytid.isEmpty ? null : ytid;
  }

  Map? _firstPlayableSong(Iterable songs) {
    for (final song in songs.whereType<Map>()) {
      if (_songYtid(song) != null) {
        return song;
      }
    }
    return null;
  }

  Map? _findSongInList(Iterable songs, String ytid) {
    for (final song in songs.whereType<Map>()) {
      if (_songYtid(song) == ytid) {
        return song;
      }
    }
    return null;
  }

  Map? _findSongByYtid(String? ytid) {
    if (ytid == null || ytid.isEmpty) return null;

    final activeSong = currentSong;
    if (activeSong?['ytid']?.toString() == ytid) {
      return activeSong;
    }

    for (final source in [
      _queueList,
      userRecentlyPlayed.value,
      userOfflineSongs.value,
      userLikedSongsList.value,
    ]) {
      final song = _findSongInList(source, ytid);
      if (song != null) return song;
    }

    return null;
  }

  Map? _latestResumableSong() {
    final activeSong = currentSong;
    if (activeSong != null && _songYtid(activeSong) != null) {
      return activeSong;
    }

    final activeMediaItem = mediaItem.valueOrNull;
    final activeYtid = activeMediaItem?.extras?['ytid']?.toString();
    final activeMediaSong = _findSongByYtid(activeYtid);
    if (activeMediaSong != null) return activeMediaSong;
    if (activeYtid != null &&
        activeYtid.isNotEmpty &&
        activeMediaItem != null) {
      return mediaItemToMap(activeMediaItem);
    }

    return _firstPlayableSong(userRecentlyPlayed.value) ??
        _firstPlayableSong(userOfflineSongs.value) ??
        _firstPlayableSong(userLikedSongsList.value);
  }

  Map<String, dynamic>? _normaliseResumableSong(Map song) {
    final ytid = _songYtid(song);
    if (ytid == null) return null;

    final normalised = cloneMap(song);
    normalised['id'] = ytid;
    normalised['ytid'] = ytid;
    normalised['highResImage'] ??=
        normalised['image'] ?? normalised['lowResImage'] ?? '';
    normalised['lowResImage'] ??= normalised['highResImage'];
    normalised['isLive'] ??= false;
    return normalised;
  }

  MediaItem? _mediaItemForResumption(Map song) {
    final normalisedSong = _normaliseResumableSong(song);
    if (normalisedSong == null) return null;

    final ytid = normalisedSong['ytid'].toString();
    final artist = normalisedSong['artist']?.toString().trim() ?? '';
    return mapToMediaItem(normalisedSong).copyWith(
      id: _recentMediaId(ytid),
      displayTitle: normalisedSong['title']?.toString(),
      displaySubtitle: artist.isEmpty ? 'Musify' : artist,
    );
  }

  Future<void> _playResumableSong(Map song) async {
    final normalisedSong = _normaliseResumableSong(song);
    if (normalisedSong == null) return;

    await playPlaylistSong(
      playlist: {
        'title': 'Musify',
        'source': 'system-recent',
        'list': [normalisedSong],
      },
      songIndex: 0,
    );
  }

  static const _rootLiked = 'liked_songs';
  static const _rootOffline = 'offline_songs';
  static const _rootRecent = 'recently_played';
  static const _rootQueue = 'current_queue';

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
      return [
        const MediaItem(
          id: _rootQueue,
          title: 'Now Playing Queue',
          playable: false,
          extras: {'isBrowsable': true},
        ),
        const MediaItem(
          id: _rootLiked,
          title: 'Liked Songs',
          playable: false,
          extras: {'isBrowsable': true},
        ),
        const MediaItem(
          id: _rootOffline,
          title: 'Downloaded',
          playable: false,
          extras: {'isBrowsable': true},
        ),
        const MediaItem(
          id: _rootRecent,
          title: 'Recently Played',
          playable: false,
          extras: {'isBrowsable': true},
        ),
      ];
    }

    switch (parentMediaId) {
      case _rootQueue:
        return _queueList.map(_getMediaItemForQueue).toList();
      case _rootLiked:
        return userLikedSongsList.value
            .whereType<Map>()
            .map((s) => mapToMediaItem(s).copyWith(playable: true))
            .toList();
      case _rootOffline:
        return userOfflineSongs.value
            .whereType<Map>()
            .map((s) => mapToMediaItem(s).copyWith(playable: true))
            .toList();
      case _rootRecent:
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
      if (_queueList.isNotEmpty) {
        await play();
        return;
      }
      final recentSong = _latestResumableSong();
      if (recentSong != null) await _playResumableSong(recentSong);
      return;
    }

    final q = query.trim().toLowerCase();
    final candidates = [
      ..._queueList,
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
    } else {
      logger.log('playFromSearch: no local match for "$query"');
    }
  }

  @override
  Future<MediaItem?> getMediaItem(String mediaId) async {
    final song = _findSongByYtid(_ytidFromMediaId(mediaId));
    return song == null ? null : _mediaItemForResumption(song);
  }

  @override
  Future<void> prepareFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    final item = await getMediaItem(mediaId);
    if (item == null) return;

    mediaItem.add(item);
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
    final song = _findSongByYtid(_ytidFromMediaId(mediaId));
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
        audioPlayer.play().catchError((Object e, StackTrace stackTrace) {
          logger.log(
            'Error starting playback',
            error: e,
            stackTrace: stackTrace,
          );
          _lastError = e.toString();
        }),
      );
    } catch (e, stackTrace) {
      logger.log('Error in play()', error: e, stackTrace: stackTrace);
      _lastError = e.toString();
    }
  }

  /// iOS suspends AVPlayer / deactivates the session when the app is
  /// backgrounded. UI can still show playing=true with a drifting position.
  Future<void> resyncAfterForeground() async {
    logger.log('App resumed — restoring audio session');
    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
    } catch (e, st) {
      logger.log('Failed to reactivate audio session', error: e, stackTrace: st);
    }

    final uiThinksPlaying = playbackState.valueOrNull?.playing == true;
    if (!uiThinksPlaying && !audioPlayer.playing) {
      _updatePlaybackState();
      return;
    }

    try {
      if (!audioPlayer.playing && audioPlayer.audioSource != null) {
        logger.log('UI said playing but AVPlayer was paused — resuming');
        await play();
      } else if (audioPlayer.playing) {
        unawaited(audioPlayer.play());
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
    logger.log('Playback did not start after source change; retrying');
    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
    } catch (_) {}
    if (_isStaleTransition(transitionId) || audioPlayer.audioSource == null) {
      return;
    }
    if (audioPlayer.playing) return;
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
    _completionEventPending = false;
    _currentLoadingIndex = -1;
    _currentLoadingTransitionId = -1;
    _lastError = null;
    _consecutiveErrors = 0;
    try {
      await audioPlayer.stop();
      _resetPreloadingState();
    } catch (e, stackTrace) {
      logger.log('Error in stop()', error: e, stackTrace: stackTrace);
    }
    await super.stop();
  }

  /// Returns unplayed manually added songs after the current queue index.
  List<Map> _getUnplayedManualSongs() {
    return _queueList
        .skip(_currentQueueIndex >= 0 ? _currentQueueIndex + 1 : 0)
        .where(
          (song) =>
              song['isManuallyAdded'] == true && song['isAutoPicked'] != true,
        )
        .toList();
  }

  void _resetPreloadingState() {
    _activePreloadCount = 0;
    _preloadingYtIds.clear();
    _preloadedYtIds.clear();
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

  Future<bool> _resolveOfflineAndSetPaths(Map songData) async {
    try {
      final ytid = songData['ytid']?.toString();
      if (ytid != null && ytid.isNotEmpty) {
        final offlineSong = getOfflineSongByYtid(ytid);
        if (offlineSong.isNotEmpty) {
          final audioPath = offlineSong['audioPath']?.toString();
          if (audioPath != null && audioPath.isNotEmpty) {
            final f = File(audioPath);
            if (await f.exists()) {
              songData['audioPath'] = audioPath;
              if (offlineSong['artworkPath'] != null) {
                songData['artworkPath'] = offlineSong['artworkPath'];
              }
              return true;
            }
          }
        }
      }
    } catch (e, st) {
      logger.log(
        'Error while checking offline songs',
        error: e,
        stackTrace: st,
      );
    }

    // Fallback: prefer an existing local `audioPath` on the passed song
    // object if the file exists.
    try {
      final path = songData['audioPath']?.toString();
      if (path != null && path.isNotEmpty) {
        final f = File(path);
        if (await f.exists()) return true;
      }
    } catch (_) {}

    return false;
  }

  /// Check if the given transitionId is stale (outdated by a newer request).
  bool _isStaleTransition(int? transitionId) {
    return transitionId != null && transitionId != _currentLoadingTransitionId;
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
      _currentLoadingIndex = _queueList.indexWhere(
        (candidate) =>
            candidate['queueEntryId'] == song['queueEntryId'] ||
            candidate['ytid']?.toString() == song['ytid']?.toString(),
      );
    }

    try {
      final songData = cloneMap(song);

      if (songData['ytid'] == null || songData['ytid'].toString().isEmpty) {
        logger.log('Invalid song data: missing ytid');
        return false;
      }

      _lastError = null;
      // INSTANT UI FEEDBACK: emit loading state before any await
      _emitOptimisticLoadingState(
        song: songData,
        includeMediaItem: true,
        mediaId: mediaId,
      );

      final playback = await _resolvePlaybackSource(songData).timeout(
        const Duration(seconds: 14),
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
        _lastError = 'Failed to get song URL';
        return false;
      }

      // Persist the resolved source on the queue entry for this canonical
      // ytid. The URL is intentionally not part of the song identity; only
      // the source/quality metadata follows the track between services.
      final queueSong = _queueList.cast<Map?>().firstWhere(
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
          ..['resolvedFormat'] = songData['resolvedFormat'];
        _updateQueueMediaItems();
      }
      songData['isOffline'] = playback.isOffline;

      final audioSource = await buildAudioSource(
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
        _lastError = 'Failed to build audio source';
        return false;
      }

      return await _setAudioSourceAndPlay(
        songData,
        audioSource,
        playback.songUrl,
        playback.isOffline,
        mediaId: mediaId,
        transitionId: effectiveTransitionId,
        resumeAt: resumeAt,
      );
    } catch (e, stackTrace) {
      logger.log('Error playing song', error: e, stackTrace: stackTrace);
      _lastError = e.toString();
      return false;
    } finally {
      // Do not clear _isUpdatingState here — only _updatePlaybackState owns it.
      if (ownsTransition &&
          _currentLoadingTransitionId == effectiveTransitionId) {
        _currentLoadingIndex = -1;
        _currentLoadingTransitionId = -1;
      }
    }
  }

  Future<_PlaybackSource?> _resolvePlaybackSource(Map songData) async {
    // Fully downloaded tracks always use the local file — overrides forceSource
    // and preferred online provider.
    final isOffline = await _resolveOfflineAndSetPaths(songData);
    if (isOffline) {
      songData['isOffline'] = true;
      songData['resolvedSource'] = 'offline';
      final songUrl = await _getOfflineSongUrl(songData);
      if (songUrl != null && songUrl.isNotEmpty) {
        return _PlaybackSource(songUrl: songUrl, isOffline: true);
      }
      // Listed as offline but file missing — fall through only if not in
      // explicit offline-only mode.
      if (offlineMode.value) {
        logger.log(
          'Offline file missing for ${songData['ytid']} while offline mode on',
        );
        return null;
      }
      logger.log(
        'Offline file missing for ${songData['ytid']}, falling back to online',
      );
    }

    if (!isOffline && offlineMode.value) {
      logger.log(
        'Offline mode enabled and no local file found for ${songData['ytid']}',
      );
      return null;
    }

    final songUrl = await _getPlaybackUrl(
      songData,
      false,
    ).timeout(const Duration(seconds: 14));

    if (songUrl == null || songUrl.isEmpty) {
      logger.log('Failed to get song URL for ${songData['ytid']}');
      return null;
    }

    return _PlaybackSource(songUrl: songUrl, isOffline: false);
  }

  /// Re-resolves the current canonical track using one source. The ytid and
  /// queue entry stay unchanged, so switching between YouTube and JioSaavn
  /// cannot create a duplicate track or attach the wrong artwork/history.
  ///
  /// Fully downloaded tracks refuse online switches (offline always wins).
  Future<bool> switchSource(String source) async {
    if (source != 'youtube' && source != 'jiosaavn') return false;
    final song = currentSong;
    if (song == null || _songYtid(song) == null) return false;

    final ytid = _songYtid(song)!;
    if (hasPlayableOfflineFile(ytid) || song['isOffline'] == true) {
      final stillOffline = await _resolveOfflineAndSetPaths(cloneMap(song));
      if (stillOffline) {
        logger.log(
          'Source switch ignored — fully downloaded track stays offline: $ytid',
        );
        return false;
      }
    }

    final previousSource = song['resolvedSource']?.toString() ?? 'youtube';
    if (previousSource == source) return true;

    if (_sourceSwitchInFlight) {
      logger.log('Source switch already in progress, ignoring');
      return true;
    }
    _sourceSwitchInFlight = true;

    final resumePosition = audioPlayer.position;
    final shouldResume = audioPlayer.playing ||
        audioPlayer.processingState == ProcessingState.ready ||
        audioPlayer.processingState == ProcessingState.buffering ||
        audioPlayer.processingState == ProcessingState.loading;

    final transitionId = ++_songTransitionCounter;
    _currentLoadingIndex = _currentQueueIndex;
    _currentLoadingTransitionId = transitionId;
    final request = cloneMap(song)
      ..['forceSource'] = source
      ..remove('isOffline')
      ..remove('audioPath');
    final mediaId = _getMediaItemForQueue(song).id;

    try {
      // Pause before swapping URLs — mid-decode setAudioSource hangs AVPlayer
      // on iOS and leaves the UI stuck in a broken loading state.
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

      // Superseded by skip/another load — not a real source failure.
      if (_isStaleTransition(transitionId)) {
        return true;
      }

      if (!success) {
        logger.log('Source $source not available for ${song['title']}');
        if (shouldResume && audioPlayer.audioSource != null) {
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
        return false;
      }

      _updatePlaybackState();
      return true;
    } catch (e, st) {
      logger.log('Error switching source to $source', error: e, stackTrace: st);
      if (shouldResume && audioPlayer.audioSource != null) {
        unawaited(audioPlayer.play().catchError((_) {}));
      }
      _updatePlaybackState();
      return false;
    } finally {
      _sourceSwitchInFlight = false;
      if (_currentLoadingTransitionId == transitionId) {
        _currentLoadingIndex = -1;
        _currentLoadingTransitionId = -1;
      }
    }
  }

  Future<String?> _getPlaybackUrl(Map song, bool isOffline) async {
    if (isOffline) {
      return _getOfflineSongUrl(song);
    }

    return fetchSongStreamUrl(song, song['isLive'] ?? false);
  }

  Future<String?> _getOfflineSongUrl(Map song) async {
    final audioPath = song['audioPath']?.toString();
    if (audioPath == null || audioPath.isEmpty) {
      logger.log('Missing audioPath for offline song: ${song['ytid']}');
      return null;
    }

    final file = File(audioPath);
    if (await file.exists()) {
      return audioPath;
    }

    logger.log('Offline audio file not found: $audioPath');

    final offlineSong = userOfflineSongs.value.firstWhere(
      (s) => s['ytid'] == song['ytid'],
      orElse: () => <String, dynamic>{},
    );

    if (offlineSong.isNotEmpty && offlineSong['audioPath'] != null) {
      final fallbackPath = offlineSong['audioPath']?.toString();
      if (fallbackPath == null || fallbackPath.isEmpty) return null;
      final fallbackFile = File(fallbackPath);
      if (await fallbackFile.exists()) {
        song['audioPath'] = fallbackPath;
        return fallbackPath;
      }
    }

    return null;
  }

  Future<bool> _setAudioSourceAndPlay(
    Map song,
    AudioSource audioSource,
    String songUrl,
    bool isOffline, {
    String? mediaId,
    bool allowOnlineRetry = true,
    int? transitionId,
    Duration? resumeAt,
  }) async {
    try {
      final urlHost = Uri.tryParse(songUrl)?.host ?? 'invalid-url';
      logger.log(
        'Playing [${song['title']}] source=${song['resolvedSource']} host=$urlHost',
      );

      // Final staleness check before we touch the audio player.
      // If another song was requested between the URL fetch and here, abort.
      if (_isStaleTransition(transitionId)) {
        return false;
      }

      // Soft-stop before installing a new URI. Swapping sources while AVPlayer
      // is still decoding the previous stream is a common iOS hang.
      try {
        if (audioPlayer.playing ||
            audioPlayer.processingState == ProcessingState.buffering ||
            audioPlayer.processingState == ProcessingState.loading) {
          await audioPlayer.pause();
        }
      } catch (_) {}

      await audioPlayer
          .setAudioSources([audioSource], preload: false)
          .timeout(_songTransitionTimeout);

      // Check once more after the async setAudioSource: a fast offline song
      // could have loaded and started playing while we were buffering/setting up.
      // If so, stop the source we just loaded and yield to the newer song.
      if (_isStaleTransition(transitionId)) {
        return false;
      }

      _installedSourceTransitionId = transitionId;

      if (audioPlayer.duration != null) {
        _updateCurrentMediaItemWithDuration(audioPlayer.duration!);
      }

      if (resumeAt != null && resumeAt > Duration.zero) {
        final duration = audioPlayer.duration;
        final target =
            duration != null && resumeAt > duration ? duration : resumeAt;
        try {
          await audioPlayer.seek(target);
        } catch (e, st) {
          logger.log(
            'Seek to resume position failed',
            error: e,
            stackTrace: st,
          );
        }
      }

      // just_audio's play() future completes when playback stops, not when it
      // starts. Awaiting it kept transitions in a loading state for the whole
      // song and allowed a later request to race the old one.
      unawaited(
        audioPlayer.play().catchError((Object e, StackTrace stackTrace) {
          logger.log(
            'Error starting playback',
            error: e,
            stackTrace: stackTrace,
          );
          _lastError = e.toString();
        }),
      );
      unawaited(_ensureActuallyPlaying(transitionId));
      unawaited(updateRecentlyPlayed(song['ytid'], songFallback: song));
      unawaited(_armNativeSuccessor());

      _updatePlaybackState();

      Future.delayed(const Duration(seconds: 2), _preloadUpcomingSongs);

      return true;
    } catch (e, stackTrace) {
      logger.log(
        'Error setting audio source',
        error: e,
        stackTrace: stackTrace,
      );

      if (isOffline) {
        // If offline mode is explicitly enabled, do not attempt any online
        // fallback — respect the user's offline-only preference.
        try {
          if (offlineMode.value) {
            return false;
          }
        } catch (_) {
          // If offlineMode isn't accessible, fallthrough to attempt fallback.
        }

        return _attemptOfflineFallback(
          song,
          mediaId: mediaId,
          transitionId: transitionId,
          resumeAt: resumeAt,
        );
      }

      if (allowOnlineRetry) {
        if (offlineMode.value) {
          _lastError = e.toString();
          return false;
        }
        final songId = song['ytid']?.toString();
        if (songId != null && songId.isNotEmpty) {
          await invalidateSongStreamCache(songId);

          final refreshedUrl = await fetchSongStreamUrl(
            song,
            song['isLive'] ?? false,
          );

          if (refreshedUrl != null && refreshedUrl.isNotEmpty) {
            final refreshedSource = await buildAudioSource(
              song,
              refreshedUrl,
              false,
            );

            if (refreshedSource != null) {
              return _setAudioSourceAndPlay(
                song,
                refreshedSource,
                refreshedUrl,
                false,
                mediaId: mediaId,
                allowOnlineRetry: false,
                transitionId: transitionId,
                resumeAt: resumeAt,
              );
            }
          }
        }
      }

      _lastError = e.toString();
      return false;
    }
  }

  Future<bool> _attemptOfflineFallback(
    Map song, {
    String? mediaId,
    int? transitionId,
    Duration? resumeAt,
  }) async {
    // Do not attempt any network calls when offline mode is enabled.
    if (offlineMode.value) return false;

    final onlineUrl = await fetchSongStreamUrl(song, song['isLive'] ?? false);
    if (onlineUrl != null && onlineUrl.isNotEmpty) {
      final onlineSource = await buildAudioSource(song, onlineUrl, false);
      if (onlineSource != null) {
        return _setAudioSourceAndPlay(
          song,
          onlineSource,
          onlineUrl,
          false,
          mediaId: mediaId,
          transitionId: transitionId,
          resumeAt: resumeAt,
        );
      }
    }
    return false;
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



  Future<AudioSource?> buildAudioSource(
    Map song,
    String songUrl,
    bool isOffline,
  ) async {
    try {
      final tag = mapToMediaItem(song);

      if (isOffline) {
        return AudioSource.file(songUrl, tag: tag);
      }

      final uri = Uri.parse(songUrl);
      Map<String, String>? headers;
      if (!isOffline) {
        if (uri.host.contains('googlevideo.com') ||
            uri.host.contains('youtube.com')) {
          headers = {
            'User-Agent':
                song['resolvedUserAgent']?.toString() ??
                'com.google.ios.youtube/21.26.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)',
          };
        } else if (uri.host.contains('saavncdn.com')) {
          headers = {
            'User-Agent':
                'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko)',
            'Accept': '*/*',
          };
        }
      }
      return AudioSource.uri(uri, headers: headers, tag: tag);
    } catch (e, stackTrace) {
      logger.log(
        'Error building audio source',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }



  Future<void> skipToSong(int newIndex) async {
    try {
      if (newIndex < 0 || newIndex >= _queueList.length) {
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
  Future<void> skipToNext() async {
    try {
      if (_currentQueueIndex < _queueList.length - 1) {
        await _playFromQueue(_currentQueueIndex + 1);
      } else if (repeatNotifier.value == AudioServiceRepeatMode.all &&
          _queueList.isNotEmpty) {
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
                if (_currentQueueIndex < _queueList.length - 1) {
                  await _playFromQueue(_currentQueueIndex + 1);
                }
              }
            }
          }
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
      if (_currentQueueIndex > 0) {
        await _playFromQueue(_currentQueueIndex - 1);
      } else if (_historyList.isNotEmpty) {
        final lastSong = cloneMap(_historyList.removeLast());
        _queueList.insert(0, lastSong);
        _currentQueueIndex = 0;
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
    return {for (final song in songs) song: _queueEntryIds.ensureId(song)};
  }

  void _enableShuffle(
    List<Map> unplayedManualSongs,
    Set<String> manualSongIds,
  ) {
    _originalQueueList
      ..clear()
      ..addAll(cloneMaps(_queueList));

    final currentSong = _queueList[_currentQueueIndex];
    final currentQueueEntryId = _queueEntryIds.ensureId(currentSong);

    final queueIdMap = _buildIdMap(_queueList);
    _queueList
      ..removeWhere((song) => manualSongIds.contains(queueIdMap[song]))
      ..shuffle();

    final newCurrentIndex = _queueList.indexWhere(
      (song) => _queueEntryIds.ensureId(song) == currentQueueEntryId,
    );

    if (newCurrentIndex != -1 && newCurrentIndex != 0) {
      _queueList
        ..removeAt(newCurrentIndex)
        ..insert(0, currentSong);
    }

    _queueList.insertAll(_queueList.isNotEmpty ? 1 : 0, unplayedManualSongs);

    _currentQueueIndex = 0;
    _updateQueueMediaItems();
  }

  void _disableShuffle(
    List<Map> unplayedManualSongs,
    Set<String> manualSongIds,
  ) {
    if (_originalQueueList.isEmpty) return;

    final currentSong = _queueList[_currentQueueIndex];
    final currentQueueEntryId = _queueEntryIds.ensureId(currentSong);

    final restoredQueue = cloneMaps(_originalQueueList);
    final restoredQueueIdMap = _buildIdMap(restoredQueue);
    restoredQueue.removeWhere(
      (song) => manualSongIds.contains(restoredQueueIdMap[song]),
    );

    _queueList
      ..clear()
      ..addAll(restoredQueue);

    _currentQueueIndex = _queueList.indexWhere(
      (song) => _queueEntryIds.ensureId(song) == currentQueueEntryId,
    );

    if (_currentQueueIndex == -1) {
      _currentQueueIndex = 0;
    }

    final insertIndex = _currentQueueIndex + 1;
    _queueList.insertAll(insertIndex, unplayedManualSongs);

    _originalQueueList.clear();
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

      if (_queueList.isEmpty) return;

      if (shuffleEnabled && !wasShuffled) {
        _hydrateQueueEntryIds();
        final unplayedManualSongs = _getUnplayedManualSongs();
        final manualSongIds = unplayedManualSongs
            .map(_queueEntryIds.ensureId)
            .toSet();
        _enableShuffle(unplayedManualSongs, manualSongIds);
      } else if (!shuffleEnabled && wasShuffled) {
        _hydrateQueueEntryIds();
        final unplayedManualSongs = _getUnplayedManualSongs();
        final manualSongIds = unplayedManualSongs
            .map(_queueEntryIds.ensureId)
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

      // Always set loop mode to off - we handle all repeating through _handleSongCompletion
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
      sleepTimerNotifier.value = Duration.zero;
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

class _PlaybackSource {
  const _PlaybackSource({required this.songUrl, required this.isOffline});

  final String songUrl;
  final bool isOffline;
}
