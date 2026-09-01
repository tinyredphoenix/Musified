import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:musified/main.dart';

/// Inputs for [AudioCompletionCoordinator.handleNearEndSkip].
class NearEndSkipContext {
  const NearEndSkipContext({
    required this.position,
    required this.sleepTimerExpired,
    required this.lastInstalledWasClipped,
    required this.gaplessSourceActive,
    required this.loadInProgress,
    required this.sourceSwitchInFlight,
    required this.playerPlaying,
    required this.processingState,
    required this.playerDuration,
    required this.currentSong,
    required this.currentMediaItem,
    required this.canonicalDuration,
    required this.catalogFromExtras,
    required this.triggerCompleted,
  });

  final Duration position;
  final bool sleepTimerExpired;
  final bool lastInstalledWasClipped;
  final bool gaplessSourceActive;
  final bool loadInProgress;
  final bool sourceSwitchInFlight;
  final bool playerPlaying;
  final ProcessingState processingState;
  final Duration? playerDuration;
  final Map? currentSong;
  final MediaItem? currentMediaItem;
  final Duration Function(Map song, MediaItem? item, Duration playerDuration)
      canonicalDuration;
  final Duration? Function(Map<String, dynamic>? extras) catalogFromExtras;
  final void Function() triggerCompleted;
}

/// Inputs for track-finished processing (gapless advance, sleep timer, queue).
class ProcessingCompletedContext {
  const ProcessingCompletedContext({
    required this.loadInProgress,
    required this.sourceSwitchInFlight,
    required this.gaplessSourceActive,
    required this.gaplessBaseQueueIndex,
    required this.playerIndex,
    required this.sequenceLength,
    required this.queueLength,
    required this.sleepTimerEndOfSong,
    required this.sleepTimerExpired,
    required this.syncGaplessAdvance,
    required this.clearGaplessActive,
    required this.onSleepTimerEndOfSong,
    required this.onCompleteTrack,
    required this.logPlayer,
  });

  final bool loadInProgress;
  final bool sourceSwitchInFlight;
  final bool gaplessSourceActive;
  final int gaplessBaseQueueIndex;
  final int playerIndex;
  final int sequenceLength;
  final int queueLength;
  final bool sleepTimerEndOfSong;
  final bool sleepTimerExpired;
  final void Function(int queueIndex) syncGaplessAdvance;
  final void Function() clearGaplessActive;
  final void Function() onSleepTimerEndOfSong;
  final Future<void> Function() onCompleteTrack;
  final void Function(String message) logPlayer;
}

/// Inputs for advancing after a track completes.
class SongCompletionContext {
  const SongCompletionContext({
    required this.addCurrentToHistory,
    required this.repeatOne,
    required this.playAgain,
    required this.skipToNext,
    required this.currentQueueIndex,
    required this.stopPlayback,
  });

  final Future<void> Function() addCurrentToHistory;
  final bool repeatOne;
  final Future<void> Function() playAgain;
  final Future<void> Function() skipToNext;
  final int Function() currentQueueIndex;
  final Future<void> Function() stopPlayback;
}

/// Inputs for playback error recovery.
class PlaybackErrorContext {
  const PlaybackErrorContext({
    required this.lastError,
    required this.setLastError,
    required this.canRetryPlayback,
    required this.stopPlayback,
    required this.invalidateStreamCache,
    required this.removePreloadedUrl,
    required this.retryCurrentSong,
    required this.skipToNext,
    required this.songYtid,
    required this.currentSong,
  });

  final String? lastError;
  final void Function(String? error) setLastError;
  final bool Function() canRetryPlayback;
  final Future<void> Function() stopPlayback;
  final Future<void> Function(String ytid) invalidateStreamCache;
  final void Function(String ytid) removePreloadedUrl;
  final Future<bool> Function(Map song) retryCurrentSong;
  final Future<void> Function() skipToNext;
  final String? Function(Map song) songYtid;
  final Map? Function() currentSong;
}

/// Track completion, near-end advance, and playback error recovery.
/// No queue/preload imports — handler passes indices and callbacks.
class AudioCompletionCoordinator {
  static const int maxConsecutiveErrors = 3;
  static const Duration errorRetryDelay = Duration(seconds: 1);

  bool eventPending = false;
  bool handlerLoadStarted = false;
  int consecutiveErrors = 0;
  DateTime? _lastPlaybackErrorAt;

  static const Duration _errorWindow = Duration(minutes: 5);

  void reset() {
    eventPending = false;
    handlerLoadStarted = false;
    consecutiveErrors = 0;
    _lastPlaybackErrorAt = null;
  }

  void onProcessingStateReady({required void Function() clearSleepTimerExpired}) {
    eventPending = false;
    handlerLoadStarted = false;
    clearSleepTimerExpired();
  }

  /// Gate for [_playFromQueue]: skip when already loading this index (non-completion).
  bool shouldSkipPlayFromQueueAlreadyLoading(
    int loadingIndex,
    int index, {
    String? loadingKey,
    String? requestedKey,
  }) {
    if (loadingIndex != index || eventPending) return false;
    if (loadingKey == null || requestedKey == null) return false;
    return loadingKey == requestedKey;
  }

  /// Gate: allow one load attempt while handling completion.
  void tryMarkCompletionLoadStarted(int loadingIndex) {
    if (loadingIndex >= 0 && eventPending && !handlerLoadStarted) {
      handlerLoadStarted = true;
    }
  }

  /// Gate: block duplicate completion-driven loads.
  bool shouldSkipDuplicateCompletionLoad(int loadingIndex) {
    return loadingIndex >= 0 && eventPending && handlerLoadStarted;
  }

  void clearConsecutiveErrors() => consecutiveErrors = 0;

  void handleProcessingCompleted(ProcessingCompletedContext ctx) {
    if (ctx.loadInProgress || ctx.sourceSwitchInFlight) {
      ctx.logPlayer('Ignoring completed — source replace in progress');
      return;
    }

    if (ctx.gaplessSourceActive) {
      if (ctx.playerIndex < ctx.sequenceLength - 1) {
        final nextQueueIndex =
            ctx.gaplessBaseQueueIndex + ctx.playerIndex + 1;
        if (nextQueueIndex < ctx.queueLength) {
          ctx.syncGaplessAdvance(nextQueueIndex);
        }
        eventPending = false;
        return;
      }
      ctx.clearGaplessActive();
    }

    ctx.logPlayer('processingState=completed');
    if (ctx.sleepTimerEndOfSong) {
      ctx.onSleepTimerEndOfSong();
      return;
    }

    if (!ctx.sleepTimerExpired && !eventPending) {
      eventPending = true;
      logger.log('Track completed — Dart advancing queue');
      unawaited(
        runSongCompletion(
          sleepTimerExpired: ctx.sleepTimerExpired,
          onComplete: ctx.onCompleteTrack,
        ),
      );
    }
  }

  void handleNearEndSkip(NearEndSkipContext ctx) {
    if (eventPending || ctx.sleepTimerExpired) return;
    if (ctx.gaplessSourceActive) return;
    if (ctx.loadInProgress || ctx.sourceSwitchInFlight) return;
    if (!ctx.playerPlaying) return;
    if (ctx.processingState == ProcessingState.completed) return;

    final playerDuration = ctx.playerDuration;
    if (playerDuration == null) return;

    var duration = playerDuration;
    final song = ctx.currentSong;
    if (song != null) {
      duration = ctx.canonicalDuration(song, ctx.currentMediaItem, duration);
    } else {
      final catalog = ctx.catalogFromExtras(ctx.currentMediaItem?.extras);
      if (catalog != null &&
          duration > catalog + const Duration(seconds: 5)) {
        duration = catalog;
      }
    }

    // Advance either because the source was clipped to the real length, or
    // because the player over-reports it (Apple does this for some AAC
    // streams) and audio actually stops at the canonical duration.
    final playerOverReportsDuration =
        playerDuration > duration + const Duration(seconds: 5);
    if (!ctx.lastInstalledWasClipped && !playerOverReportsDuration) return;

    if (duration < const Duration(seconds: 5)) return;
    final remaining = duration - ctx.position;
    if (remaining > const Duration(milliseconds: 450) || remaining.isNegative) {
      return;
    }
    logger.log(
      'Near end of track (${remaining.inMilliseconds}ms left of ${duration.inSeconds}s) — advancing',
    );
    ctx.triggerCompleted();
  }

  Future<void> runSongCompletion({
    required bool sleepTimerExpired,
    required Future<void> Function() onComplete,
  }) async {
    try {
      if (!sleepTimerExpired && eventPending) {
        await onComplete();
      }
    } finally {
      if (eventPending) {
        eventPending = false;
        handlerLoadStarted = false;
      }
    }
  }

  Future<void> completeSong(SongCompletionContext ctx) async {
    await ctx.addCurrentToHistory();

    if (ctx.repeatOne) {
      await ctx.playAgain();
      return;
    }

    final indexBefore = ctx.currentQueueIndex();
    await ctx.skipToNext();
    if (ctx.currentQueueIndex() == indexBefore) {
      logger.log('Queue ended — stopping instead of playing trailing silence');
      await ctx.stopPlayback();
    }
  }

  void handlePlaybackError(
    PlaybackErrorContext ctx, {
    bool advance = true,
  }) {
    final now = DateTime.now();
    if (_lastPlaybackErrorAt != null &&
        now.difference(_lastPlaybackErrorAt!) > _errorWindow) {
      consecutiveErrors = 0;
    }
    _lastPlaybackErrorAt = now;
    consecutiveErrors++;
    logger.log(
      'Playback error occurred. Consecutive errors: $consecutiveErrors',
      error: ctx.lastError,
    );

    if (consecutiveErrors >= maxConsecutiveErrors) {
      logger.log('Max consecutive errors reached. Stopping playback.');
      unawaited(ctx.stopPlayback());
      return;
    }

    if (advance && ctx.canRetryPlayback()) {
      unawaited(retryOrAdvanceAfterError(ctx));
    } else {
      ctx.setLastError(null);
    }
  }

  Future<void> retryOrAdvanceAfterError(PlaybackErrorContext ctx) async {
    final song = ctx.currentSong();
    final ytid = song != null ? ctx.songYtid(song) : null;
    if (ytid != null && ctx.lastError != null) {
      await ctx.invalidateStreamCache(ytid);
      ctx.removePreloadedUrl(ytid);
      if (consecutiveErrors == 1 && song != null) {
        final retried = await ctx.retryCurrentSong(song);
        if (retried) {
          consecutiveErrors = 0;
          ctx.setLastError(null);
          return;
        }
      }
    }
    await Future.delayed(errorRetryDelay);
    await ctx.skipToNext();
  }
}
