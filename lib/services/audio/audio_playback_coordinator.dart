import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:musified/main.dart';
import 'package:musified/services/audio/audio_playback_install.dart';
import 'package:musified/services/audio/playback_source.dart';
import 'package:musified/services/common_services.dart';
import 'package:musified/utilities/app_utils.dart';

typedef PlaybackLogFn = void Function(
  String message, {
  Map<String, Object?>? extra,
});

/// Gapless install inputs — handler builds from hub queue state.
class GaplessInstallContext {
  const GaplessInstallContext({
    required this.offlineModeEnabled,
    required this.repeatOne,
    required this.currentIndex,
    required this.queueLength,
    required this.nextSong,
    required this.currentSongTitle,
    required this.hasPlayableOfflineFile,
    required this.resolveNextStreamUrl,
  });

  final bool offlineModeEnabled;
  final bool repeatOne;
  final int currentIndex;
  final int queueLength;
  final Map? nextSong;
  final String? currentSongTitle;
  final bool Function(String ytid) hasPlayableOfflineFile;
  final Future<String?> Function(Map song) resolveNextStreamUrl;
}

/// Resolves URLs, builds sources, and installs them in [audioPlayer].
/// No queue/preload imports — handler passes cache maps and gapless context.
class AudioPlaybackCoordinator {
  AudioPlaybackCoordinator({
    required this.audioPlayer,
    this.offlineTransitionTimeout = const Duration(seconds: 6),
    this.streamTransitionTimeout = const Duration(seconds: 12),
  });

  final AudioPlayer audioPlayer;
  final Duration offlineTransitionTimeout;
  final Duration streamTransitionTimeout;

  bool sourceSwitchInFlight = false;
  bool lastInstalledWasOffline = false;
  bool lastInstalledWasClipped = false;
  int? installedSourceTransitionId;
  bool gaplessSourceActive = false;
  int gaplessBaseQueueIndex = 0;
  String? lastError;

  void resetInstallState() {
    lastInstalledWasOffline = false;
    lastInstalledWasClipped = false;
    installedSourceTransitionId = null;
    gaplessSourceActive = false;
    gaplessBaseQueueIndex = 0;
    lastError = null;
  }

  Future<bool> resolveOfflineAndSetPaths(Map songData) async {
    try {
      final ytid = songData['ytid']?.toString();
      if (ytid != null && ytid.isNotEmpty) {
        final offlineSong = getOfflineSongByYtid(ytid);
        if (offlineSong.isNotEmpty) {
          final audioPath = offlineSong['audioPath']?.toString();
          if (audioPath != null && audioPath.isNotEmpty) {
            final f = File(audioPath);
            if (await f.exists() && await f.length() > 8192) {
              songData['audioPath'] = audioPath;
              if (offlineSong['artworkPath'] != null) {
                songData['artworkPath'] = offlineSong['artworkPath'];
              }
              logger.log(
                'Offline file OK',
                data: {
                  'ytid': ytid,
                  'bytes': await f.length(),
                  'path': audioPath,
                },
              );
              return true;
            }
            logger.log(
              'Offline file unusable',
              data: {
                'ytid': ytid,
                'exists': await f.exists(),
                'bytes': await f.exists() ? await f.length() : 0,
                'path': audioPath,
              },
            );
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

    try {
      final path = songData['audioPath']?.toString();
      if (path != null && path.isNotEmpty) {
        final f = File(path);
        if (await f.exists()) return true;
      }
    } catch (_) {}

    return false;
  }

  Future<String?> getOfflineSongUrl(
    Map song,
    List<Map<dynamic, dynamic>> offlineLibrary,
  ) async {
    final audioPath = song['audioPath']?.toString();
    if (audioPath == null || audioPath.isEmpty) {
      logger.log('Missing audioPath for offline song: ${song['ytid']}');
      return null;
    }

    final file = File(audioPath);
    if (await file.exists()) {
      final bytes = await file.length();
      if (bytes > 8192) return audioPath;
      logger.log(
        'Offline audio file too small',
        data: {'ytid': song['ytid'], 'bytes': bytes, 'path': audioPath},
      );
    }

    logger.log('Offline audio file not found: $audioPath');

    final offlineSong = offlineLibrary.firstWhere(
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

  Future<String?> getPlaybackUrl(
    Map song,
    Map<String, String> preloadedUrls, {
    required bool isOffline,
  }) async {
    if (isOffline) {
      return getOfflineSongUrl(
        song,
        userOfflineSongs.value.cast<Map<dynamic, dynamic>>(),
      );
    }

    final ytid = song['ytid']?.toString();

    void rejectStale(String source, String url) {
      logger.log(
        'Rejecting stale $source stream URL for $ytid',
        data: {
          'expire': Uri.tryParse(url)?.queryParameters['expire'] ?? '-',
        },
      );
      song.remove('_preloadedStreamUrl');
      if (ytid != null) preloadedUrls.remove(ytid);
    }

    final warmed = song['_preloadedStreamUrl']?.toString();
    if (warmed != null && warmed.isNotEmpty) {
      if (isUsableYoutubePlaybackUrl(warmed)) {
        logger.log('Using pre-warmed stream URL for $ytid');
        return warmed;
      }
      rejectStale('pre-warmed', warmed);
    }
    if (ytid != null && preloadedUrls.containsKey(ytid)) {
      final cached = preloadedUrls[ytid]!;
      if (isUsableYoutubePlaybackUrl(cached)) {
        logger.log('Using preloaded stream URL for $ytid');
        return cached;
      }
      rejectStale('preloaded', cached);
    }

    return fetchSongStreamUrl(song, song['isLive'] ?? false);
  }

  Future<PlaybackSource?> resolvePlaybackSource(
    Map songData, {
    required bool offlineModeEnabled,
    required Map<String, String> preloadedUrls,
  }) async {
    final forceSource = songData['forceSource']?.toString();
    final skipOffline =
        (forceSource == 'youtube' || forceSource == 'jiosaavn') &&
        sourceSwitchInFlight;

    if (skipOffline) {
      logger.log(
        'Skipping local file — explicit source=$forceSource',
        data: {'ytid': songData['ytid'], 'title': songData['title']},
      );
      songData
        ..remove('isOffline')
        ..remove('audioPath');
    } else {
      final isOffline = await resolveOfflineAndSetPaths(songData);
      if (isOffline) {
        songData['isOffline'] = true;
        songData['resolvedSource'] = 'offline';
        final songUrl = await getOfflineSongUrl(
          songData,
          userOfflineSongs.value.cast<Map<dynamic, dynamic>>(),
        );
        if (songUrl != null && songUrl.isNotEmpty) {
          logger.log(
            'Playing from local file',
            data: {
              'ytid': songData['ytid'],
              'path': songUrl,
            },
          );
          return PlaybackSource(songUrl: songUrl, isOffline: true);
        }
        if (offlineModeEnabled) {
          logger.log(
            'Offline file missing for ${songData['ytid']} while offline mode on',
          );
          return null;
        }
        logger.log(
          'Offline file missing for ${songData['ytid']}, falling back to online',
        );
      }

      if (!isOffline && offlineModeEnabled) {
        logger.log(
          'Offline mode enabled and no local file found for ${songData['ytid']}',
        );
        return null;
      }
    }

    final songUrl = await getPlaybackUrl(
      songData,
      preloadedUrls,
      isOffline: false,
    ).timeout(const Duration(seconds: 36));

    if (songUrl == null || songUrl.isEmpty) {
      logger.log(
        'Failed to get song URL for ${songData['ytid']}',
        data: {'force': forceSource ?? '-', 'title': songData['title']},
      );
      return null;
    }

    return PlaybackSource(songUrl: songUrl, isOffline: false);
  }

  Future<AudioSource> maybeAppendGaplessNext(
    AudioSource current,
    bool isOffline,
    GaplessInstallContext ctx,
  ) async {
    // Gapless concat is disabled: mixed offline/youtube queues and doubled
    // AVPlayer durations caused wrong track ends and -1004 load failures.
    gaplessSourceActive = false;
    return current;
  }

  Future<bool> setAudioSourceAndPlay({
    required Map song,
    required AudioSource audioSource,
    required String songUrl,
    required bool isOffline,
    required GaplessInstallContext gaplessCtx,
    required bool Function(int?) isStale,
    required PlaybackLogFn logPlayer,
    required bool Function() offlineModeEnabled,
    required void Function(Duration duration) onDurationKnown,
    required void Function() onPlaybackStateChanged,
    required Future<void> Function(int? transitionId) ensureActuallyPlaying,
    required Future<void> Function(Map song) onRecentlyPlayed,
    required void Function() schedulePreload,
    String? mediaId,
    bool allowOnlineRetry = true,
    int? transitionId,
    Duration? resumeAt,
  }) async {
    try {
      final urlHost = isOffline
          ? 'file:${songUrl.split('/').last}'
          : (Uri.tryParse(songUrl)?.host ?? 'invalid-url');
      logger.log(
        'Playing [${song['title']}] source=${song['resolvedSource']} host=$urlHost',
      );

      if (isStale(transitionId)) return false;

      // Stop so AVPlayer does not carry doubled position/duration from the
      // previous item into the next load.
      final needsHardReset = isOffline || lastInstalledWasOffline;
      if (!gaplessSourceActive && audioPlayer.audioSource != null) {
        try {
          await audioPlayer.stop().timeout(const Duration(seconds: 2));
          if (!needsHardReset) {
            await audioPlayer.seek(Duration.zero);
          }
        } catch (e) {
          logger.log('stop before stream switch failed: $e');
        }
      }

      final installSource =
          await maybeAppendGaplessNext(audioSource, isOffline, gaplessCtx);

      logPlayer(
        'setAudioSources',
        extra: {
          'title': song['title'],
          'source': song['resolvedSource'],
          'offline': isOffline,
          'host': urlHost,
          'clip': audioSource is ClippingAudioSource,
          'hardReset': needsHardReset,
          'gapless': gaplessSourceActive,
        },
      );

      await audioPlayer
          .setAudioSources(
            [installSource],
            preload: true,
          )
          .timeout(
            isOffline ? offlineTransitionTimeout : streamTransitionTimeout,
          );

      logPlayer(
        'Source installed',
        extra: {
          'title': song['title'],
          'source': song['resolvedSource'],
          'playerDur': audioPlayer.duration?.inSeconds,
        },
      );

      if (isStale(transitionId)) return false;

      installedSourceTransitionId = transitionId;
      lastInstalledWasOffline = isOffline;
      lastInstalledWasClipped =
          installSource is ClippingAudioSource ||
          audioSource is ClippingAudioSource;

      if (audioPlayer.duration != null) {
        final catalog = parseSongDuration(song['duration']);
        if (catalog != null &&
            catalog > const Duration(seconds: 5) &&
            audioPlayer.duration! > catalog + const Duration(seconds: 5)) {
          onDurationKnown(catalog);
        } else {
          onDurationKnown(audioPlayer.duration!);
        }
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

      unawaited(
        audioPlayer.play().catchError((Object e, StackTrace stackTrace) {
          logger.log(
            'Error starting playback',
            error: e,
            stackTrace: stackTrace,
          );
          lastError = e.toString();
        }),
      );
      unawaited(ensureActuallyPlaying(transitionId));
      unawaited(onRecentlyPlayed(song));

      onPlaybackStateChanged();
      Future.delayed(const Duration(seconds: 2), schedulePreload);

      return true;
    } catch (e, stackTrace) {
      logPlayer(
        'Error setting audio source',
        extra: {'title': song['title'], 'offline': isOffline},
      );
      logger.log(
        'Error setting audio source',
        error: e,
        stackTrace: stackTrace,
      );

      if (isOffline) {
        try {
          if (offlineModeEnabled()) return false;
        } catch (_) {}

        return attemptOfflineFallback(
          song: song,
          gaplessCtx: gaplessCtx,
          isStale: isStale,
          logPlayer: logPlayer,
          offlineModeEnabled: offlineModeEnabled,
          onDurationKnown: onDurationKnown,
          onPlaybackStateChanged: onPlaybackStateChanged,
          ensureActuallyPlaying: ensureActuallyPlaying,
          onRecentlyPlayed: onRecentlyPlayed,
          schedulePreload: schedulePreload,
          mediaId: mediaId,
          transitionId: transitionId,
          resumeAt: resumeAt,
        );
      }

      if (allowOnlineRetry) {
        if (offlineModeEnabled()) {
          lastError = e.toString();
          return false;
        }
        final songId = song['ytid']?.toString();
        if (songId != null && songId.isNotEmpty) {
          song.remove('_preloadedStreamUrl');
          await invalidateSongStreamCache(songId);

          final refreshedUrl = await fetchSongStreamUrl(
            song,
            song['isLive'] ?? false,
          );

          if (refreshedUrl != null && refreshedUrl.isNotEmpty) {
            final refreshedSource = await AudioPlaybackInstall.buildSource(
              song,
              refreshedUrl,
              false,
            );

            if (refreshedSource != null) {
              return setAudioSourceAndPlay(
                song: song,
                audioSource: refreshedSource,
                songUrl: refreshedUrl,
                isOffline: false,
                gaplessCtx: gaplessCtx,
                isStale: isStale,
                logPlayer: logPlayer,
                offlineModeEnabled: offlineModeEnabled,
                onDurationKnown: onDurationKnown,
                onPlaybackStateChanged: onPlaybackStateChanged,
                ensureActuallyPlaying: ensureActuallyPlaying,
                onRecentlyPlayed: onRecentlyPlayed,
                schedulePreload: schedulePreload,
                mediaId: mediaId,
                allowOnlineRetry: false,
                transitionId: transitionId,
                resumeAt: resumeAt,
              );
            }
          }
        }
      }

      lastError = e.toString();
      return false;
    }
  }

  Future<bool> attemptOfflineFallback({
    required Map song,
    required GaplessInstallContext gaplessCtx,
    required bool Function(int?) isStale,
    required PlaybackLogFn logPlayer,
    required bool Function() offlineModeEnabled,
    required void Function(Duration duration) onDurationKnown,
    required void Function() onPlaybackStateChanged,
    required Future<void> Function(int? transitionId) ensureActuallyPlaying,
    required Future<void> Function(Map song) onRecentlyPlayed,
    required void Function() schedulePreload,
    String? mediaId,
    int? transitionId,
    Duration? resumeAt,
  }) async {
    if (offlineModeEnabled()) return false;

    final onlineUrl = await fetchSongStreamUrl(song, song['isLive'] ?? false);
    if (onlineUrl != null && onlineUrl.isNotEmpty) {
      final onlineSource =
          await AudioPlaybackInstall.buildSource(song, onlineUrl, false);
      if (onlineSource != null) {
        return setAudioSourceAndPlay(
          song: song,
          audioSource: onlineSource,
          songUrl: onlineUrl,
          isOffline: false,
          gaplessCtx: gaplessCtx,
          isStale: isStale,
          logPlayer: logPlayer,
          offlineModeEnabled: offlineModeEnabled,
          onDurationKnown: onDurationKnown,
          onPlaybackStateChanged: onPlaybackStateChanged,
          ensureActuallyPlaying: ensureActuallyPlaying,
          onRecentlyPlayed: onRecentlyPlayed,
          schedulePreload: schedulePreload,
          mediaId: mediaId,
          transitionId: transitionId,
          resumeAt: resumeAt,
        );
      }
    }
    return false;
  }
}
