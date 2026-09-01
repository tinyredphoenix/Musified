import 'package:musified/main.dart';
import 'package:musified/services/common_services.dart';
import 'package:musified/utilities/app_utils.dart';

import 'package:musified/services/audio/audio_preload_cache.dart';

/// Stream URL preloading. Only talks to [AudioPreloadCache] + network helpers.
/// Queue position/items are passed in by [AudioHandlerHub] — no queue imports.
class AudioPreloadService {
  AudioPreloadService({
    required this.cache,
    this.lookahead = 1,
    this.maxConcurrent = 1,
    this.fetchTimeout = const Duration(seconds: 8),
  });

  final AudioPreloadCache cache;
  final int lookahead;
  final int maxConcurrent;
  final Duration fetchTimeout;

  void cleanupStaleForYtids(Set<String> activeQueueYtids) {
    for (final ytid in cache.preloadedYtIds
        .where((id) => !activeQueueYtids.contains(id))
        .toList()) {
      cache.drop(ytid);
    }
    for (final ytid in cache.preloadingYtIds
        .where((id) => !activeQueueYtids.contains(id))
        .toList()) {
      cache.preloadingYtIds.remove(ytid);
      if (cache.activeCount > 0) cache.activeCount--;
    }
  }

  Set<String> queueYtids(List<Map> items) {
    return items
        .map((song) => song['ytid']?.toString())
        .where((ytid) => ytid != null && ytid.isNotEmpty)
        .cast<String>()
        .toSet();
  }

  List<Map> upcomingSongs({
    required List<Map> queueItems,
    required int currentIndex,
    required bool offlineModeEnabled,
  }) {
    if (offlineModeEnabled) return [];

    final songs = <Map>[];
    for (var i = 1; i <= lookahead; i++) {
      final nextIndex = currentIndex + i;
      if (nextIndex >= queueItems.length) break;

      final nextSong = queueItems[nextIndex];
      final ytid = nextSong['ytid']?.toString();
      if (ytid == null || ytid.isEmpty) continue;
      if (isSongAlreadyOffline(ytid)) continue;
      if (cache.preloadedYtIds.contains(ytid)) continue;
      if (cache.preloadingYtIds.contains(ytid)) continue;
      songs.add(nextSong);
    }
    return songs;
  }

  Future<void> preloadSequentially(
    List<Map> songs, {
    required bool Function() isLoadInProgress,
    required Future<void> Function(Map song) preloadOne,
  }) async {
    for (final song in songs) {
      if (isLoadInProgress()) return;
      while (cache.activeCount >= maxConcurrent) {
        if (isLoadInProgress()) return;
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final ytid = song['ytid']?.toString();
      if (ytid == null || cache.preloadingYtIds.contains(ytid)) continue;
      await preloadOne(song);
    }
  }

  Future<void> preloadSingle(
    Map nextSong, {
    required bool offlineModeEnabled,
    required bool Function() isLoadInProgress,
  }) async {
    final ytid = nextSong['ytid']?.toString();
    if (ytid == null || isLoadInProgress()) return;

    cache.preloadingYtIds.add(ytid);
    cache.activeCount++;
    String? preloadUrl;

    try {
      if (offlineModeEnabled) {
        logger.log('Offline mode enabled; skipping preload for $ytid');
      } else {
        preloadUrl = await fetchSongStreamUrl(
          nextSong,
          nextSong['isLive'] ?? false,
        ).timeout(
          fetchTimeout,
          onTimeout: () {
            logger.log('Preload timeout for song $ytid');
            return null;
          },
        );
        if (isLoadInProgress()) {
          logger.log('Preload aborted after fetch for $ytid');
          preloadUrl = null;
          return;
        }
      }
    } catch (e, stackTrace) {
      logger.log('Error preloading song $ytid', error: e, stackTrace: stackTrace);
    } finally {
      cache.preloadingYtIds.remove(ytid);
      if (cache.activeCount > 0) cache.activeCount--;
      if (preloadUrl != null && preloadUrl.isNotEmpty) {
        if (isUsableYoutubePlaybackUrl(preloadUrl)) {
          cache.preloadedYtIds.add(ytid);
          cache.streamUrls[ytid] = preloadUrl;
          nextSong['_preloadedStreamUrl'] = preloadUrl;
          logger.log(
            'Preloaded stream for $ytid',
            data: {
              'host': Uri.tryParse(preloadUrl)?.host ?? '-',
              'dur': youtubeStreamDurationSeconds(
                Uri.parse(preloadUrl),
              )?.toString() ??
                  '-',
            },
          );
        } else {
          logger.log('Preload URL unusable for $ytid (expired or invalid)');
        }
      }
    }
  }

  Future<String?> resolveNextStreamUrl(
    Map nextSong, {
    required bool offlineModeEnabled,
    required bool loadInProgress,
  }) async {
    final ytid = nextSong['ytid']?.toString();
    if (ytid == null || ytid.isEmpty) return null;

    final warmed = nextSong['_preloadedStreamUrl']?.toString();
    if (warmed != null &&
        warmed.isNotEmpty &&
        isUsableYoutubePlaybackUrl(warmed)) {
      return warmed;
    }
    if (warmed != null && warmed.isNotEmpty) {
      nextSong.remove('_preloadedStreamUrl');
    }

    final cached = cache.streamUrls[ytid];
    if (cached != null &&
        cached.isNotEmpty &&
        isUsableYoutubePlaybackUrl(cached)) {
      return cached;
    }
    if (cached != null && cached.isNotEmpty) {
      cache.drop(ytid);
    }

    if (offlineModeEnabled || loadInProgress) return null;

    try {
      final url = await fetchSongStreamUrl(
        nextSong,
        nextSong['isLive'] ?? false,
      ).timeout(
        fetchTimeout,
        onTimeout: () {
          logger.log('Gapless next URL fetch timed out for $ytid');
          return null;
        },
      );
      if (url != null &&
          url.isNotEmpty &&
          isUsableYoutubePlaybackUrl(url)) {
        cache.streamUrls[ytid] = url;
        nextSong['_preloadedStreamUrl'] = url;
        return url;
      }
      if (url != null && url.isNotEmpty) {
        logger.log('Fetched next URL unusable for $ytid (expired or invalid)');
      }
      return null;
    } catch (e, st) {
      logger.log(
        'Gapless next URL fetch failed for $ytid',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }
}
