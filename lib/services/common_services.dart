import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:musified/constants/clients.dart';
import 'package:musified/main.dart' show logger;
import 'package:musified/services/artist_service.dart' show ytMusicClient;
import 'package:musified/services/data_manager.dart';
import 'package:musified/services/io_service.dart';
import 'package:musified/services/lyrics_manager.dart';
import 'package:musified/services/playlists_manager.dart';
import 'package:musified/services/proxy_manager.dart';
import 'package:musified/services/settings_manager.dart';
import 'package:musified/services/source_resolver.dart';
import 'package:musified/services/ytdlp_client_sync_service.dart';
import 'package:musified/services/youtube_auth_service.dart';
import 'package:musified/services/youtube_music_sync_service.dart';
import 'package:musified/utilities/app_utils.dart';
import 'package:musified/utilities/formatter.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

T _safeUserGet<T>(String key, T defaultValue) {
  try {
    if (!Hive.isBoxOpen('user')) return defaultValue;
    final v = Hive.box('user').get(key, defaultValue: defaultValue);
    if (v is T) return v;
    return defaultValue;
  } catch (_) {
    return defaultValue;
  }
}

T _safeUserNoBackupGet<T>(String key, T defaultValue) {
  try {
    if (!Hive.isBoxOpen('userNoBackup')) return defaultValue;
    final v = Hive.box('userNoBackup').get(key, defaultValue: defaultValue);
    if (v is T) return v;
    return defaultValue;
  } catch (_) {
    return defaultValue;
  }
}

ValueNotifier<List> userLikedSongsList = ValueNotifier<List>(
  _safeUserGet<List>('likedSongs', []),
);

ValueNotifier<List> userRecentlyPlayed = ValueNotifier<List>(
  _safeUserGet<List>('recentlyPlayedSongs', []),
);

final trendingSongs = ValueNotifier<List>([]);

ValueNotifier<List> userOfflineSongs = ValueNotifier<List>(
  _safeUserNoBackupGet<List>('offlineSongs', []),
);

final Set<String> _likedSongIdsSet = {
  ...userLikedSongsList.value.map((s) => s['ytid']?.toString() ?? '').where((id) => id.isNotEmpty),
};
final Set<String> _offlineSongIdsSet = {
  ...userOfflineSongs.value.map((s) => s['ytid']?.toString() ?? '').where((id) => id.isNotEmpty),
};

void _syncLikedSongIdsSet() {
  _likedSongIdsSet
    ..clear()
    ..addAll(
      userLikedSongsList.value
          .map((s) => s['ytid']?.toString() ?? '')
          .where((id) => id.isNotEmpty),
    );
}

void _syncOfflineSongIdsSet() {
  _offlineSongIdsSet
    ..clear()
    ..addAll(
      userOfflineSongs.value
          .map((s) => s['ytid']?.toString() ?? '')
          .where((id) => id.isNotEmpty),
    );
}

dynamic nextRecommendedSong;

var _songLikeUpdateToken = 0;
final _latestSongLikeUpdateTokens = <String, int>{};

final lyrics = ValueNotifier<String?>(null);
String? lastFetchedLyrics;

void reloadSongLibraryStateFromStorage() {
  try {
    if (Hive.isBoxOpen('user')) {
      final userBox = Hive.box('user');
      userLikedSongsList.value = List.from(
        userBox.get('likedSongs', defaultValue: []),
      );
      userRecentlyPlayed.value = List.from(
        userBox.get('recentlyPlayedSongs', defaultValue: []),
      );
      _syncLikedSongIdsSet();
    }
    if (Hive.isBoxOpen('userNoBackup')) {
      final box = Hive.box('userNoBackup');
      userOfflineSongs.value = List.from(
        box.get('offlineSongs', defaultValue: []),
      );
      _syncOfflineSongIdsSet();
    }
  } catch (e) {
    logger.log('Error reloading song library state: $e');
  }
}

// Timeouts and durations used across manifest fetching and cache validation.
const Duration _cacheValidationDuration = Duration(hours: 1);
const Duration _headRevalidateAge = Duration(minutes: 30);

String? _pendingYoutubeStreamError;

void setYoutubeStreamError(String message) {
  _pendingYoutubeStreamError = message;
}

String? consumeYoutubeStreamError() {
  final message = _pendingYoutubeStreamError;
  _pendingYoutubeStreamError = null;
  return message;
}

String _youtubeStreamFailureMessage() {
  final label = YtdlpClientSyncService.instance.clientLabel;
  return "Couldn't load YouTube stream ($label). "
      'Try Sync YouTube Client in Settings.';
}

/// googlevideo URLs carry the exact track length as `dur`. Reading it avoids
/// racing an async catalog lookup, and it is what keeps the player from
/// reporting a doubled duration for these streams.
int? youtubeStreamDurationSeconds(Uri url) {
  final raw = url.queryParameters['dur'];
  if (raw == null) return null;
  final seconds = double.tryParse(raw);
  if (seconds == null || seconds <= 0) return null;
  return seconds.round();
}

String _songStreamCacheKey(String songId, String source) =>
    'song_${songId}_${audioQualitySetting.value}_${source}_url';

String _songStreamCacheMetaKey(String songId, String source) =>
    '${_songStreamCacheKey(songId, source)}_meta';

Future<void> _cacheResolvedStream(
  String songId,
  String source,
  String url,
  Map<String, dynamic> metadata,
) async {
  final key = _songStreamCacheKey(songId, source);
  final metaKey = _songStreamCacheMetaKey(songId, source);
  final now = DateTime.now();
  // Atomic URL + metadata write so cache hits never lack provenance.
  await addOrUpdateData<String>('cache', key, url);
  final cacheBox = await Hive.openBox('cache');
  await cacheBox.putAll({
    _songStreamCacheMetaKey(songId, source): {'source': source, ...metadata},
    '${metaKey}_date': now,
    '${key}_date': now,
  });
}

bool _isCachedHeAacYoutube(Map metadata) {
  final itag = metadata['itag'];
  if (itag is int && kHeAacItags.contains(itag)) return true;
  final parsedItag = int.tryParse(itag?.toString() ?? '');
  if (parsedItag != null && kHeAacItags.contains(parsedItag)) return true;
  return isHeAacFormatLabel(metadata['format']?.toString());
}

/// Fills `song['duration']` from YouTube catalog when Innertube/search omitted it.
/// Needed so iOS can clip HE-AAC/SBR streams to the real track length.
Future<void> ensureYoutubeCatalogDuration(Map song) async {
  if (parseSongDuration(song['duration']) != null) return;
  final source = song['resolvedSource']?.toString() ?? song['source']?.toString();
  if (source == 'jiosaavn' || source == 'saavn') return;
  final songId = song['ytid']?.toString();
  if (songId == null || songId.isEmpty) return;
  try {
    final video = await ytClient.videos
        .get(songId)
        .timeout(const Duration(seconds: 4));
    final seconds = video.duration?.inSeconds;
    if (seconds != null && seconds > 0) {
      song['duration'] = seconds;
      logger.log('Fetched YouTube catalog duration for $songId: ${seconds}s');
    }
  } catch (e) {
    logger.log('Could not fetch catalog duration for $songId: $e');
  }
}

/// Fetches a stream manifest for a song, honoring proxy settings.
String? _youtubeClientUserAgent(YoutubeApiClient client) {
  final clientContext = client.payload['context']?['client'];
  return clientContext is Map ? clientContext['userAgent']?.toString() : null;
}

Future<({StreamManifest manifest, YoutubeApiClient? client})?>
_tryGetManifest(
  String songId, {
  required String attempt,
  required Duration timeout,
  List<YoutubeApiClient>? ytClients,
}) async {
  try {
    final manifest = await ytClient.videos.streams
        .getManifest(songId, ytClients: ytClients)
        .timeout(timeout);
    if (manifest.audioOnly.isNotEmpty) {
      logger.log('YouTube manifest via $attempt for $songId');
      return (
        manifest: manifest,
        client: ytClients == null || ytClients.isEmpty ? null : ytClients.first,
      );
    }
    logger.log('YouTube manifest via $attempt for $songId had no audio streams');
  } catch (error) {
    logger.log('$attempt getManifest failed for $songId: $error');
  }
  return null;
}

Future<({StreamManifest manifest, YoutubeApiClient? client})?>
_fetchStreamManifest(String songId) async {
  if (useProxy.value) {
    try {
      final manifest = await ProxyManager()
          .getSongManifest(songId)
          .timeout(const Duration(seconds: 15));
      if (manifest != null && manifest.audioOnly.isNotEmpty) {
        logger.log('YouTube manifest via proxy for $songId');
        return (manifest: manifest, client: youtubeStreamClient());
      }
    } catch (error) {
      logger.log('Proxy getManifest failed for $songId: $error');
    }
    return null;
  }

  return _tryGetManifest(
    songId,
    attempt: YtdlpClientSyncService.instance.clientLabel,
    timeout: const Duration(seconds: 20),
    ytClients: youtubeStreamClients(),
  );
}

DateTime? _parseCacheTimestamp(dynamic raw) {
  if (raw is DateTime) return raw;
  if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
  if (raw is String) return DateTime.tryParse(raw);
  return null;
}

Future<bool> _isCachedStreamUrlAlive(
  String url, {
  String? userAgent,
}) async {
  try {
    final headers = <String, String>{
      if (userAgent != null && userAgent.isNotEmpty) 'User-Agent': userAgent,
    };
    final uri = Uri.parse(url);
    final head = await http
        .head(uri, headers: headers.isEmpty ? null : headers)
        .timeout(const Duration(seconds: 4));
    if (head.statusCode == 200 || head.statusCode == 206) return true;
    if (head.statusCode != 405) return false;
    final probe = await http
        .get(
          uri,
          headers: {
            ...headers,
            'Range': 'bytes=0-1',
          },
        )
        .timeout(const Duration(seconds: 4));
    return probe.statusCode == 200 || probe.statusCode == 206;
  } catch (_) {
    return false;
  }
}

/// Returns a cached song URL if present and still valid.
Future<String?> _getCachedSongUrl(
  String cacheKey,
  Duration cacheDuration, {
  String? userAgent,
}) async {
  final cacheBox = await Hive.openBox('cache');
  final cachedAt = _parseCacheTimestamp(await cacheBox.get('${cacheKey}_date'));

  final cachedUrl = await getData(
    'cache',
    cacheKey,
    cachingDuration: cacheDuration,
  );

  if (cachedUrl is! String || cachedUrl.isEmpty) {
    return null;
  }

  final parsed = Uri.tryParse(cachedUrl);
  if (parsed == null || !isPlayableYoutubeStreamUrl(parsed)) {
    logger.log('Cached stream URL invalid for $cacheKey');
    await deleteData('cache', cacheKey);
    await deleteData('cache', '${cacheKey}_meta');
    return null;
  }

  if (cachedAt != null &&
      DateTime.now().difference(cachedAt) > _headRevalidateAge) {
    if (!await _isCachedStreamUrlAlive(cachedUrl, userAgent: userAgent)) {
      logger.log('Stale cached stream URL rejected for $cacheKey');
      await deleteData('cache', cacheKey);
      await deleteData('cache', '${cacheKey}_meta');
      return null;
    }
  } else if (cachedAt == null) {
    // Legacy entries without a stored date must be probed once.
    if (!await _isCachedStreamUrlAlive(cachedUrl, userAgent: userAgent)) {
      logger.log('Untimestamped cached stream URL rejected for $cacheKey');
      await deleteData('cache', cacheKey);
      await deleteData('cache', '${cacheKey}_meta');
      return null;
    }
  }

  return cachedUrl;
}

Future<List> fetchSongsList(String searchQuery) async {
  try {
    // 1. Search YouTube Music catalog for songs only (avoids news, vlogs, reactions)
    final musicTracks = await ytMusicClient.music.searchSongs(searchQuery);
    if (musicTracks.isNotEmpty) {
      return musicTracks
          .map((video) {
            final layout = returnSongLayout(0, video);
            layout['catalogOrigin'] = 'youtube';
            return layout;
          })
          .toList();
    }

    // 2. Fallback: query YouTube with music filter suffix
    final List<Video> searchResults =
        await ytClient.search.search('$searchQuery audio');
    return searchResults
        .map((video) {
          final layout = returnSongLayout(0, video);
          layout['catalogOrigin'] = 'youtube';
          return layout;
        })
        .toList();
  } catch (e, stackTrace) {
    logger.log('Error in fetchSongsList', error: e, stackTrace: stackTrace);
    return [];
  }
}

DateTime? _lastRecTime;
List _cachedRecs = [];

Future<List> getRecommendedSongs({bool forceRefresh = false}) async {
  try {
    if (!forceRefresh &&
        _cachedRecs.isNotEmpty &&
        _lastRecTime != null &&
        DateTime.now().difference(_lastRecTime!).inSeconds < 60) {
      return _cachedRecs;
    }

    List results;
    if (externalRecommendations.value &&
        (userRecentlyPlayed.value.isNotEmpty ||
            userLikedSongsList.value.isNotEmpty)) {
      results = await _getRecommendationsFromRecentlyPlayed();
    } else {
      results = await _getRecommendationsFromMixedSources();
    }
    if (results.isNotEmpty) {
      _cachedRecs = results;
      _lastRecTime = DateTime.now();
    }
    return results.isNotEmpty ? results : _cachedRecs;
  } catch (e, stackTrace) {
    logger.log(
      'Error in getRecommendedSongs',
      error: e,
      stackTrace: stackTrace,
    );
    return _cachedRecs;
  }
}

Future<List> _getRecommendationsFromRecentlyPlayed() async {
  // Keep the most recently played items first. Shuffling the seeds made the
  // shelf appear unrelated to the user's latest listening and prevented the
  // home page from feeling responsive to new history.
  final seeds = <Map>[];
  final seenSeeds = <String>{};
  for (final raw in [
    ...userRecentlyPlayed.value,
    ...userLikedSongsList.value,
  ]) {
    if (raw is! Map) continue;
    final id = raw['ytid']?.toString();
    if (id != null && id.isNotEmpty && seenSeeds.add(id)) {
      seeds.add(raw);
    }
    if (seeds.length >= 5) break;
  }
  final recent = seeds;
  if (recent.isEmpty) return [];

  final scores = <String, double>{};
  final songMap = <String, Map>{};

  final futures = recent.asMap().entries.map((entry) async {
    final seedIndex = entry.key;
    final songData = entry.value;
    try {
      final song = await ytClient.videos.get(songData['ytid']);
      final related = await ytClient.videos.getRelatedVideos(song) ?? [];
      for (var i = 0; i < related.length && i < 8; i++) {
        final s = returnSongLayout(0, related[i]);
        final id = s['ytid'];
        final positionWeight = 1.0 - (i / 8);
        final recencyWeight = 1.0 - (seedIndex / recent.length);
        scores[id] = (scores[id] ?? 0) + positionWeight * recencyWeight;
        songMap[id] = s;
      }
    } catch (e, st) {
      logger.log(
        'related videos error for ${songData['ytid']}',
        error: e,
        stackTrace: st,
      );
    }
  }).toList();

  await Future.wait(futures);

  final sorted = scores.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(15).map((e) => songMap[e.key]).whereType<Map>().toList();
}

Future<List> _getRecommendationsFromMixedSources() async {
  final playlistSongs = [
    ...userLikedSongsList.value,
    ...userRecentlyPlayed.value,
  ];

  if (userCustomPlaylists.value.isNotEmpty) {
    for (final userPlaylist in userCustomPlaylists.value) {
      final rawList = userPlaylist['list'];
      if (rawList is List && rawList.isNotEmpty) {
        final list = List.from(rawList)..shuffle();
        playlistSongs.addAll(list.take(5));
      }
    }
  }

  return _deduplicateAndShuffle(playlistSongs);
}

List _deduplicateAndShuffle(List playlistSongs) {
  final seenYtIds = <String>{};
  final uniqueSongs = <Map>[];

  playlistSongs.shuffle();

  for (final song in playlistSongs) {
    if (song['ytid'] != null && seenYtIds.add(song['ytid'])) {
      uniqueSongs.add(song);
      // Early exit when we have enough songs
      if (uniqueSongs.length >= 15) break;
    }
  }

  return uniqueSongs;
}

Future<void> updateSongLikeStatus(
  dynamic songId,
  bool add, {
  Map? songData,
}) async {
  try {
    final normalizedSongId = songId?.toString().trim() ?? '';
    if (normalizedSongId.isEmpty) return;

    final updateToken = ++_songLikeUpdateToken;
    _latestSongLikeUpdateTokens[normalizedSongId] = updateToken;

    final songToAdd = add
        ? await _resolveSongForLikedStatus(normalizedSongId, songData)
        : null;

    if (_latestSongLikeUpdateTokens[normalizedSongId] != updateToken) {
      return;
    }

    final updatedLikedSongs = _deduplicateLikedSongs(userLikedSongsList.value);

    if (add) {
      if (songToAdd != null &&
          !updatedLikedSongs.any(
            (song) => song['ytid']?.toString() == normalizedSongId,
          )) {
        updatedLikedSongs.insert(0, songToAdd);
      }
    } else {
      updatedLikedSongs.removeWhere(
        (song) => song['ytid']?.toString() == normalizedSongId,
      );
    }

    if (_likedSongIdsAreEqual(userLikedSongsList.value, updatedLikedSongs))
      return;

    userLikedSongsList.value = updatedLikedSongs;
    _syncLikedSongIdsSet();
    // Sync like/unlike to YouTube Music if authenticated
    if (YouTubeAuthService().isSignedIn.value && ytAutoSyncLikes.value) {
      unawaited(
        add
            ? YouTubeMusicSyncService().likeSong(normalizedSongId)
            : YouTubeMusicSyncService().unlikeSong(normalizedSongId),
      );
    }
    unawaited(
      addOrUpdateData<List>('user', 'likedSongs', userLikedSongsList.value),
    );
  } catch (e, stackTrace) {
    logger.log(
      'Error updating song like status',
      error: e,
      stackTrace: stackTrace,
    );
  }
}

Future<Map?> _resolveSongForLikedStatus(String songId, Map? songData) async {
  if (songData?['ytid']?.toString() == songId) {
    return Map<String, dynamic>.from(songData!);
  }

  final cachedSong = _findSongById(userLikedSongsList.value, songId);
  if (cachedSong != null) return Map<String, dynamic>.from(cachedSong);

  return getSongDetails(userLikedSongsList.value.length, songId);
}

Map? _findSongById(Iterable<dynamic> songs, String songId) {
  for (final song in songs) {
    if (song is Map && song['ytid']?.toString() == songId) return song;
  }

  return null;
}

List _deduplicateLikedSongs(Iterable<dynamic> likedSongs) {
  final seenSongIds = <String>{};
  final deduplicatedSongs = [];

  for (final song in likedSongs) {
    if (song is! Map) {
      deduplicatedSongs.add(song);
      continue;
    }

    final songId = song['ytid']?.toString();
    if (songId == null || songId.isEmpty) {
      deduplicatedSongs.add(song);
      continue;
    }

    if (seenSongIds.add(songId)) {
      deduplicatedSongs.add(song);
    }
  }

  return deduplicatedSongs;
}

bool _likedSongIdsAreEqual(List previous, List updated) {
  if (previous.length != updated.length) return false;

  for (var i = 0; i < previous.length; i++) {
    final previousSong = previous[i];
    final updatedSong = updated[i];
    if (previousSong is! Map || updatedSong is! Map) {
      if (previousSong != updatedSong) return false;
      continue;
    }

    if (previousSong['ytid']?.toString() != updatedSong['ytid']?.toString()) {
      return false;
    }
  }

  return true;
}

Future<void> renameSongInLikedSongs(
  dynamic songId,
  String newTitle,
  String newArtist,
) async {
  try {
    final songIndex = userLikedSongsList.value.indexWhere(
      (song) => song['ytid'] == songId,
    );

    if (songIndex != -1) {
      final updatedList = List.from(userLikedSongsList.value);
      updatedList[songIndex] = Map.from(updatedList[songIndex] as Map)
        ..['title'] = newTitle
        ..['artist'] = newArtist;
      userLikedSongsList.value = updatedList;

      unawaited(
        addOrUpdateData<List>('user', 'likedSongs', userLikedSongsList.value),
      );
    }
  } catch (e, stackTrace) {
    logger.log(
      'Error renaming song in liked songs',
      error: e,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}

bool isSongAlreadyLiked(songIdToCheck) {
  final songId = songIdToCheck?.toString();
  if (songId == null || songId.isEmpty) return false;
  if (_likedSongIdsSet.isEmpty && userLikedSongsList.value.isNotEmpty) {
    _syncLikedSongIdsSet();
  }
  return _likedSongIdsSet.contains(songId);
}

bool isPlaylistAlreadyLiked(playlistIdToCheck) {
  final playlistId = playlistIdToCheck?.toString();
  if (playlistId == null || playlistId.isEmpty) return false;
  return userLikedPlaylists.value.any(
    (playlist) => playlist['ytid']?.toString() == playlistId,
  );
}

bool isSongAlreadyOffline(songIdToCheck) {
  final songId = songIdToCheck?.toString();
  if (songId == null || songId.isEmpty) return false;
  if (_offlineSongIdsSet.isEmpty && userOfflineSongs.value.isNotEmpty) {
    _syncOfflineSongIdsSet();
  }
  return _offlineSongIdsSet.contains(songId);
}

bool isPlaylistFullyOffline(List songs) {
  if (songs.isEmpty) return false;
  if (_offlineSongIdsSet.isEmpty && userOfflineSongs.value.isNotEmpty) {
    _syncOfflineSongIdsSet();
  }
  return songs.every((s) => _offlineSongIdsSet.contains(s['ytid']?.toString() ?? ''));
}

bool _isPlayableAudioFile(String? path) {
  if (path == null || path.isEmpty) return false;
  try {
    final file = File(path);
    return file.existsSync() && file.lengthSync() > 8192;
  } catch (_) {
    return false;
  }
}

Map<String, dynamic> getOfflineSongByYtid(String ytid) {
  try {
    if (ytid.isEmpty) return <String, dynamic>{};

    final song = userOfflineSongs.value.firstWhere(
      (s) => s['ytid'] == ytid,
      orElse: () => <String, dynamic>{},
    );
    final result = Map<String, dynamic>.from(song);
    if (applicationDirPath.isEmpty) {
      return result;
    }
    // iOS moves the app container (its UUID changes) on every reinstall or
    // update, so any absolute path stored at download time goes stale and the
    // file "disappears". Downloads are named deterministically by ytid, so
    // always resolve against the CURRENT container instead of trusting the
    // stored path. This keeps offline playback working across app updates.
    // A Hive miss still counts as playable if the file is on disk.
    final currentAudioPath = FilePaths.getAudioPath(ytid);
    if (_isPlayableAudioFile(currentAudioPath)) {
      result
        ..['audioPath'] = currentAudioPath
        ..['ytid'] = ytid;
    }
    final currentArtworkPath = FilePaths.getArtworkPath(ytid);
    if (File(currentArtworkPath).existsSync()) {
      result['artworkPath'] = currentArtworkPath;
    }
    return result;
  } catch (_) {
    return <String, dynamic>{};
  }
}

/// True when a fully downloaded copy exists on disk and is large enough
/// to be a real audio file (not a 0-byte failed download).
bool hasPlayableOfflineFile(String? ytid) {
  if (ytid == null || ytid.isEmpty) return false;
  final hivePath = getOfflineSongByYtid(ytid)['audioPath']?.toString();
  if (_isPlayableAudioFile(hivePath)) return true;
  if (applicationDirPath.isEmpty) return false;
  return _isPlayableAudioFile(FilePaths.getAudioPath(ytid));
}

Future<List<String>> getSearchSuggestions(String query) async {
  // Custom implementation:

  // const baseUrl = 'https://suggestqueries.google.com/complete/search';
  // final parameters = {
  //   'client': 'firefox',
  //   'ds': 'yt',
  //   'q': query,
  // };

  // final uri = Uri.parse(baseUrl).replace(queryParameters: parameters);

  // try {
  //   final response = await http.get(
  //     uri,
  //     headers: {
  //       'User-Agent':
  //           'Mozilla/5.0 (Windows NT 10.0; rv:96.0) Gecko/20100101 Firefox/96.0',
  //     },
  //   );

  //   if (response.statusCode == 200) {
  //     final suggestions = jsonDecode(response.body)[1] as List<dynamic>;
  //     final suggestionStrings = suggestions.cast<String>().toList();
  //     return suggestionStrings;
  //   }
  // } catch (e, stackTrace) {
  //   logger.log('Error in getSearchSuggestions:$e\n$stackTrace');
  // }

  // Built-in implementation:

  final suggestions = await ytClient.search.getQuerySuggestions(query);

  return suggestions;
}



Future<void> getSimilarSong(String songYtId) async {
  try {
    final song = await ytClient.videos.get(songYtId);
    final relatedSongs = await ytClient.videos.getRelatedVideos(song) ?? [];

    if (relatedSongs.isNotEmpty) {
      nextRecommendedSong = returnSongLayout(0, relatedSongs[0]);
    } else {
      logger.log('No related songs found for $songYtId');
    }
  } catch (e, stackTrace) {
    logger.log(
      'Error while fetching next similar song:',
      error: e,
      stackTrace: stackTrace,
    );
  }
}

/// In-memory cache of the audio stream picked for a song at the current
/// quality setting. The Hive cache only keeps the URL, so without this every
/// caller that needs the stream itself (bitrate, codec) would fetch the
/// manifest again right after playback already resolved it.
final Map<
  String,
  ({AudioOnlyStreamInfo stream, YoutubeApiClient? client, DateTime resolvedAt})
>
_selectedAudioStreams = {};

const _maxSelectedAudioStreams = 50;

String _selectedAudioStreamKey(String songId) =>
    '${songId}_${audioQualitySetting.value}';

/// Returns the stream resolved earlier for a song, unless it is old enough
/// that its URL may have expired.
({AudioOnlyStreamInfo stream, YoutubeApiClient? client})?
_getSelectedAudioStream(String songId) {
  final key = _selectedAudioStreamKey(songId);
  final entry = _selectedAudioStreams[key];
  if (entry == null) return null;

  if (DateTime.now().difference(entry.resolvedAt) > _cacheValidationDuration) {
    _selectedAudioStreams.remove(key);
    return null;
  }

  if (isHeAacStream(entry.stream)) {
    _selectedAudioStreams.remove(key);
    return null;
  }

  return (stream: entry.stream, client: entry.client);
}

void _cacheSelectedAudioStream(
  String songId,
  AudioOnlyStreamInfo stream,
  YoutubeApiClient? client,
) {
  if (_selectedAudioStreams.length >= _maxSelectedAudioStreams) {
    _selectedAudioStreams.remove(_selectedAudioStreams.keys.first);
  }

  _selectedAudioStreams[_selectedAudioStreamKey(songId)] = (
    stream: stream,
    client: client,
    resolvedAt: DateTime.now(),
  );
}

/// Drops cached stream URLs for every song (e.g. after changing InnerTube client).
Future<void> invalidateAllSongStreamCaches() async {
  _selectedAudioStreams.clear();
  if (!Hive.isBoxOpen('cache')) return;
  final box = Hive.box('cache');
  for (final key in box.keys) {
    if (key is String && key.startsWith('song_')) {
      await deleteData('cache', key);
    }
  }
}

/// Drops both cached forms of a song's stream, so the next request resolves
/// it again. Used when a cached URL turns out to be dead.
Future<void> invalidateSongStreamCache(String songId) async {
  _selectedAudioStreams.remove(_selectedAudioStreamKey(songId));
  for (final source in ['youtube', 'jiosaavn']) {
    final key = _songStreamCacheKey(songId, source);
    await deleteData('cache', key);
    await deleteData('cache', _songStreamCacheMetaKey(songId, source));
  }
  await SourceResolver().deleteCachedMatch(songId);
  // Remove the pre-source cache key written by older builds. It is unsafe to
  // reuse because it does not say which service produced the URL.
  await deleteData('cache', 'song_${songId}_${audioQualitySetting.value}_url');
}

/// Fetches the best available audio stream for a song.
Future<AudioOnlyStreamInfo?> fetchBestAudioStream(String? songId) async {
  try {
    if (songId == null || songId.isEmpty) {
      logger.log('fetchBestAudioStream: songId is null or empty');
      return null;
    }

    final cachedSelection = _getSelectedAudioStream(songId);
    if (cachedSelection != null &&
        isPlayableYoutubeStreamUrl(cachedSelection.stream.url)) {
      return cachedSelection.stream;
    }
    if (cachedSelection != null) {
      _selectedAudioStreams.remove(_selectedAudioStreamKey(songId));
    }

    final resolvedManifest = await _fetchStreamManifest(songId);
    final audioStream = resolvedManifest?.manifest.audioOnly;
    if (audioStream == null || audioStream.isEmpty) {
      logger.log('fetchBestAudioStream: no audio streams for $songId');
      return null;
    }

    final playable = audioStream
        .where((stream) => isPlayableYoutubeStreamUrl(stream.url))
        .toList();
    if (playable.isEmpty) {
      logger.log(
        'fetchBestAudioStream: no playable URLs for $songId '
        '(client returned ciphered URLs)',
      );
      return null;
    }

    final selectedStream = selectAudioOnlyStreamForQuality(
      playable.sortByBitrate(),
    );
    if (!isPlayableYoutubeStreamUrl(selectedStream.url)) {
      logger.log('fetchBestAudioStream: selected stream URL invalid for $songId');
      return null;
    }
    logger.log(
      'Selected YT stream itag=${selectedStream.tag} '
      'codec=${selectedStream.audioCodec} '
      'bitrate=${selectedStream.bitrate.kiloBitsPerSecond.round()}kbps'
      '${isHeAacStream(selectedStream) ? ' (HE-AAC — will clip duration)' : ''}',
    );
    _cacheSelectedAudioStream(songId, selectedStream, resolvedManifest!.client);
    return selectedStream;
  } on TimeoutException catch (_) {
    logger.log('fetchBestAudioStream request timed out for $songId');
    return null;
  } catch (e, stackTrace) {
    logger.log(
      'Error while fetching best audio stream',
      error: e,
      stackTrace: stackTrace,
    );
    return null;
  }
}

/// Resolves a playable stream URL for a song (cached when possible).
Future<String?> fetchSongStreamUrl(Map song, bool isLive) async {
  final songId = song['ytid']?.toString() ?? '';
  try {
    if (songId.isEmpty) {
      logger.log('fetchSongStreamUrl: songId is empty');
      return null;
    }
    if (isLive) {
      final streamInfo = await ytClient.videos.streamsClient
          .getHttpLiveStreamUrl(VideoId(songId));
      return streamInfo;
    }

    const cacheDuration = Duration(minutes: 45);
    final forceSource = song['forceSource']?.toString();
    final requestedPreference = forceSource ?? preferredSource.value;
    final preference = (requestedPreference == 'saavn' || requestedPreference == 'jiosaavn')
        ? 'jiosaavn'
        : 'youtube';
    final catalogOrigin = song['catalogOrigin']?.toString();
    final resolveYoutube =
        forceSource == 'youtube' || catalogOrigin == 'youtube' || preference == 'youtube';

    logger.log(
      'Resolution start for songId=$songId',
      data: {
        'title': song['title'],
        'force': forceSource ?? '-',
        'target': resolveYoutube ? 'youtube' : preference,
        'catalogOrigin': catalogOrigin ?? '-',
        'offlineMode': offlineMode.value,
      },
    );

    // Check source-specific cache
    final cachePreference = resolveYoutube ? 'youtube' : preference;
    final sourceKey = _songStreamCacheKey(songId, cachePreference);
    final cacheBox = await Hive.openBox('cache');
    final metadata = cacheBox.get(_songStreamCacheMetaKey(songId, cachePreference));
    final cachedUrl = await _getCachedSongUrl(
      sourceKey,
      cacheDuration,
      userAgent: metadata is Map
          ? metadata['userAgent']?.toString()
          : null,
    );
    if (cachedUrl != null) {
      if (metadata is Map && metadata['source'] == cachePreference) {
        final isBadHeAac = cachePreference == 'youtube' && _isCachedHeAacYoutube(metadata);
        if (!isBadHeAac) {
          song['resolvedSource'] = cachePreference;
          song['resolvedBitrate'] = metadata['bitrate'];
          song['resolvedFormat'] = metadata['format'];
          song['resolvedUserAgent'] = metadata['userAgent'];
          if (metadata['image'] != null) {
            song['highResImage'] = metadata['image'];
            song['image'] = metadata['image'];
          }
          if (cachePreference == 'youtube') {
            final cachedDuration = metadata['durationSeconds'];
            if (cachedDuration is int && cachedDuration > 0) {
              song['duration'] = cachedDuration;
            } else {
              unawaited(ensureYoutubeCatalogDuration(song));
            }
          }
          logger.log('Using cached $cachePreference URL for $songId');
          return cachedUrl;
        }
      }
      await invalidateSongStreamCache(songId);
    }

    // YouTube catalog/search hits: skip JioSaavn wait when track is not on Saavn.
    if (!resolveYoutube &&
        forceSource != 'youtube' &&
        preference == 'jiosaavn' &&
        jiosaavnEnabled.value) {
      try {
        final saavnSource = await SourceResolver()
            .resolveAudioSource(song)
            .timeout(const Duration(seconds: 5), onTimeout: () => null);
        if (saavnSource != null && saavnSource['url'] != null) {
          final url = saavnSource['url'] as String;
          if (url.isNotEmpty) {
            song['resolvedSource'] = 'jiosaavn';
            song['resolvedBitrate'] = saavnSource['bitrate'];
            song['resolvedFormat'] = saavnSource['format'];
            if (saavnSource['image'] != null) {
              song['highResImage'] = saavnSource['image'];
              song['image'] = saavnSource['image'];
            }
            await _cacheResolvedStream(songId, 'jiosaavn', url, {
              'bitrate': saavnSource['bitrate'],
              'format': saavnSource['format'],
              'image': saavnSource['image'],
            });
            logger.log('Resolved JioSaavn stream: host=${Uri.tryParse(url)?.host}');
            return url;
          }
        }
        logger.log('JioSaavn match not found for $songId, falling back to YouTube');
      } catch (e) {
        logger.log('JioSaavn resolution error: $e, falling back to YouTube');
      }
    }

    // YouTube Music resolution — selected Settings client only, no fallback.
    final selectedStream = await fetchBestAudioStream(songId);
    if (selectedStream == null) {
      setYoutubeStreamError(_youtubeStreamFailureMessage());
      logger.log('fetchSongStreamUrl: no YouTube audio streams for $songId');
      return null;
    }

    final url = selectedStream.url.toString();
    if (!isPlayableYoutubeStreamUrl(selectedStream.url)) {
      setYoutubeStreamError(_youtubeStreamFailureMessage());
      logger.log('fetchSongStreamUrl: invalid stream URL for $songId');
      return null;
    }
    final selectedClient = _getSelectedAudioStream(songId)?.client;
    final userAgent = selectedClient == null
        ? null
        : _youtubeClientUserAgent(selectedClient);

    song['resolvedSource'] = 'youtube';
    song['resolvedBitrate'] = selectedStream.bitrate.kiloBitsPerSecond.round();
    song['resolvedFormat'] = selectedStream.audioCodec;
    song['resolvedItag'] = selectedStream.tag;
    song['resolvedUserAgent'] = userAgent;

    // Set before the source is built so the media item and the near-end check
    // never see the player's (sometimes doubled) reported duration.
    final streamDuration = youtubeStreamDurationSeconds(selectedStream.url);
    if (streamDuration != null) {
      song['duration'] = streamDuration;
    }

    await _cacheResolvedStream(songId, 'youtube', url, {
      'bitrate': song['resolvedBitrate'],
      'format': song['resolvedFormat'],
      'itag': selectedStream.tag,
      'userAgent': userAgent,
      'durationSeconds': streamDuration,
    });
    if (streamDuration == null) {
      unawaited(ensureYoutubeCatalogDuration(song));
    }
    logger.log('Resolved YouTube stream: host=${Uri.tryParse(url)?.host}');
    return url;
  } on TimeoutException catch (_) {
    setYoutubeStreamError(_youtubeStreamFailureMessage());
    logger.log('fetchSongStreamUrl timed out for $songId');
    return null;
  } catch (e, stackTrace) {
    logger.log(
      'Error in fetchSongStreamUrl for $songId:',
      error: e,
      stackTrace: stackTrace,
    );
    return null;
  }
}

Future<Map<String, dynamic>> getSongDetails(
  int songIndex,
  String songId,
) async {
  try {
    final song = await ytClient.videos.get(songId);
    return returnSongLayout(songIndex, song);
  } catch (e, stackTrace) {
    logger.log(
      'Error while getting song details',
      error: e,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}

Future<String?> getSongLyrics(String? artist, String title) async {
  if (artist == null) return null;
  if (lastFetchedLyrics != '$artist - $title') {
    lyrics.value = null;
    var _lyrics = await LyricsManager().fetchLyrics(artist, title);
    if (_lyrics != null) {
      _lyrics = _lyrics.replaceAll(RegExp(r'\n{4}'), '\n\n');
      _lyrics = _lyrics.replaceAll(RegExp(r'\n{2}'), '\n');
      lyrics.value = _lyrics;
    } else {
      return null;
    }

    lastFetchedLyrics = '$artist - $title';
    return _lyrics;
  }

  return lyrics.value;
}

Future<bool> makeSongOffline(
  dynamic song, {
  String? source,
  String? quality,
}) async {
  try {
    final normalizedSource = source == 'jiosaavn' ? 'saavn' : source;
    final String? ytid = song['ytid'];

    if (ytid == null || ytid.isEmpty) {
      logger.log('makeSongOffline: song["ytid"] is null or empty');
      return false;
    }

    if (isSongAlreadyOffline(ytid)) {
      final existingPath = FilePaths.getAudioPath(ytid);
      if (await File(existingPath).exists()) {
        return true;
      }
    }

    final offlineSong = Map<String, dynamic>.from(song as Map)
      ..remove('forceSource')
      ..remove('resolvedSource')
      ..remove('resolvedBitrate')
      ..remove('resolvedFormat')
      ..remove('resolvedUserAgent');
    var downloadedSource = normalizedSource == 'saavn'
        ? 'jiosaavn'
        : normalizedSource == 'youtube'
        ? 'youtube'
        : null;

    final audioPath = FilePaths.getAudioPath(ytid);
    final audioFile = File(audioPath);
    final artworkPath = FilePaths.getArtworkPath(ytid);

    await audioFile.parent.create(recursive: true);

    int? audioBitrateKbps;
    String? audioCodec;
    IOSink? fileStream;
    try {
      Map<String, dynamic>? saavnSource;
      var mappedQuality = quality;
      // Saavn only supports 96/160/320, map 128 -> 96
      if (mappedQuality == '128') mappedQuality = '96';
      if (normalizedSource != 'youtube' && jiosaavnEnabled.value) {
        try {
          saavnSource = await SourceResolver()
              .resolveAudioSource(offlineSong, quality: mappedQuality)
              .timeout(const Duration(seconds: 6), onTimeout: () => null);
        } catch (e) {
          logger.log('Saavn resolve for offline failed: $e');
        }
      }

      if (saavnSource != null && saavnSource['url'] != null) {
        downloadedSource = 'jiosaavn';
        audioBitrateKbps = saavnSource['bitrate'] as int?;
        audioCodec = saavnSource['format'] as String?;
        final url = saavnSource['url'] as String;

        final req = http.Request('GET', Uri.parse(url));
        req.headers['User-Agent'] =
            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15';
        final client = http.Client();
        try {
          final response = await client
              .send(req)
              .timeout(const Duration(seconds: 20));
          if (response.statusCode < 200 || response.statusCode >= 300) {
            logger.log('Saavn download HTTP ${response.statusCode} for $ytid');
            throw HttpException('Saavn HTTP ${response.statusCode}');
          }
          fileStream = audioFile.openWrite();
          await response.stream.pipe(fileStream);
          fileStream = null;
        } finally {
          client.close();
        }
      } else {
        // If source explicitly saavn but failed, gracefully fall back to YouTube
        if (normalizedSource == 'saavn') {
          logger.log(
            'makeSongOffline: saavn source not found for $ytid, falling back to YouTube',
          );
        }
        final audioManifest = await fetchBestAudioStream(ytid);
        if (audioManifest == null) {
          setYoutubeStreamError(_youtubeStreamFailureMessage());
          logger.log('makeSongOffline: audioManifest is null for $ytid');
          return false;
        }
        downloadedSource = 'youtube';
        audioBitrateKbps = audioManifest.bitrate.kiloBitsPerSecond.round();
        audioCodec = audioManifest.audioCodec;

        final streamDuration = youtubeStreamDurationSeconds(audioManifest.url);
        if (streamDuration != null) {
          offlineSong['duration'] = streamDuration;
        }

        final selectedClient = _getSelectedAudioStream(ytid)?.client;
        final stream = ytClient.videos.streamsClient.get(
          audioManifest,
          ytClient: selectedClient,
        );
        fileStream = audioFile.openWrite();
        await stream.pipe(fileStream).timeout(const Duration(seconds: 60));
        fileStream = null;
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error downloading audio file',
        error: e,
        stackTrace: stackTrace,
      );
      try {
        await fileStream?.close();
      } catch (_) {}
      if (await audioFile.exists()) {
        await audioFile.delete();
      }
      return false;
    }

    try {
      if (offlineSong['highResImage'] != null &&
          offlineSong['highResImage'].toString().isNotEmpty) {
        final _artworkFile = await _downloadAndSaveArtworkFile(
          offlineSong['highResImage'],
          artworkPath,
        );

        if (_artworkFile != null && await _artworkFile.exists()) {
          offlineSong['artworkPath'] = artworkPath;
        } else {
          logger.log(
            'Artwork download failed or file does not exist for $ytid',
          );
          offlineSong['artworkPath'] = null;
        }
      }
    } catch (e, stackTrace) {
      logger.log('Error downloading artwork', error: e, stackTrace: stackTrace);
      offlineSong['artworkPath'] = null;
    }

    offlineSong['audioPath'] = audioFile.path;
    offlineSong['audioBitrateKbps'] = audioBitrateKbps;
    offlineSong['audioCodec'] = audioCodec;
    offlineSong['downloadSource'] = downloadedSource;
    offlineSong['dateAdded'] = DateTime.now().millisecondsSinceEpoch;

    try {
      final existingIndex = userOfflineSongs.value.indexWhere(
        (s) => s['ytid'] == ytid,
      );

      final updatedOfflineSongs = List.from(userOfflineSongs.value);
      if (existingIndex != -1) {
        updatedOfflineSongs[existingIndex] = offlineSong;
      } else {
        updatedOfflineSongs.add(offlineSong);
      }
      userOfflineSongs.value = updatedOfflineSongs;
      _syncOfflineSongIdsSet();

      unawaited(
        addOrUpdateData<List>(
          'userNoBackup',
          'offlineSongs',
          userOfflineSongs.value,
        ),
      );


    } catch (e, st) {
      logger.log(
        'Error updating global offline songs list',
        error: e,
        stackTrace: st,
      );
    }

    return true;
  } catch (e, stackTrace) {
    logger.log('Error making song offline', error: e, stackTrace: stackTrace);
    return false;
  }
}

Future<bool> removeSongFromOffline(dynamic songId) async {
  try {
    final audioPath = FilePaths.getAudioPath(songId);
    final audioFile = File(audioPath);
    final artworkPath = FilePaths.getArtworkPath(songId);
    final artworkFile = File(artworkPath);

    try {
      if (await audioFile.exists()) await audioFile.delete(recursive: true);
    } catch (e, stackTrace) {
      logger.log('Error deleting audio file', error: e, stackTrace: stackTrace);
    }

    try {
      if (await artworkFile.exists()) await artworkFile.delete(recursive: true);
    } catch (e, stackTrace) {
      logger.log(
        'Error deleting artwork file',
        error: e,
        stackTrace: stackTrace,
      );
    }

    try {
      userOfflineSongs.value = List.from(userOfflineSongs.value)
        ..removeWhere((song) => song['ytid'] == songId);
      _syncOfflineSongIdsSet();
      unawaited(
        addOrUpdateData<List>(
          'userNoBackup',
          'offlineSongs',
          userOfflineSongs.value,
        ),
      );
    } catch (e, st) {
      logger.log(
        'Error updating offline songs registry after removal',
        error: e,
        stackTrace: st,
      );
    }

    return true;
  } catch (e, stackTrace) {
    logger.log(
      'Error removing song from offline storage',
      error: e,
      stackTrace: stackTrace,
    );
    return false;
  }
}


Future<File?> _downloadAndSaveArtworkFile(String url, String filePath) async {
  try {
    final response = await ProxyManager().getProxiedResponse(Uri.parse(url));

    if (response.statusCode == 200) {
      final file = File(filePath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(response.bodyBytes);

      // Validate that the file was actually written
      if (await file.exists() && await file.length() > 0) {
        return file;
      } else {
        logger.log('Artwork file was not written properly: $filePath');
        return null;
      }
    } else {
      logger.log(
        'Failed to download file. Status code: ${response.statusCode}',
      );
    }
  } catch (e, stackTrace) {
    logger.log(
      'Error downloading and saving file',
      error: e,
      stackTrace: stackTrace,
    );
  }

  return null;
}

const recentlyPlayedSongsLimit = 100;

/// Updates the recently played list and listening count for [songId].
///
/// When [songFallback] is provided, its metadata is used to seed the history
/// entry if the song has never been played before. This avoids a network
/// request when registering offline songs whose metadata is already available
/// locally (e.g. from [userOfflineSongs]).
Future<void> updateRecentlyPlayed(dynamic songId, {Map? songFallback}) async {
  try {
    final now = DateTime.now();

    if (userRecentlyPlayed.value.isNotEmpty &&
        userRecentlyPlayed.value[0]['ytid'] == songId) {
      final updatedList = List.from(userRecentlyPlayed.value);
      final existing = Map.from(updatedList[0] as Map);
      existing['listeningCount'] = (existing['listeningCount'] ?? 0) + 1;
      existing['lastPlayed'] = now;
      updatedList[0] = existing;
      userRecentlyPlayed.value = updatedList;
      unawaited(
        addOrUpdateData<List>(
          'user',
          'recentlyPlayedSongs',
          userRecentlyPlayed.value,
        ),
      );
      // Report playback to YouTube Music history (even if streamed via JioSaavn)
      if (YouTubeAuthService().isSignedIn.value && ytReportHistory.value) {
        unawaited(YouTubeMusicSyncService().reportSongPlayed(songId.toString()));
      }
      return;
    }

    final existingIndex = userRecentlyPlayed.value.indexWhere(
      (song) => song['ytid'] == songId,
    );

    final updatedList = List.from(userRecentlyPlayed.value);

    if (existingIndex == -1 && updatedList.length >= recentlyPlayedSongsLimit) {
      updatedList.removeLast();
    }

    if (existingIndex != -1) {
      final song = Map.from(updatedList.removeAt(existingIndex) as Map);
      song['listeningCount'] = (song['listeningCount'] ?? 0) + 1;
      song['lastPlayed'] = now;
      updatedList.insert(0, song);
    } else {
      final dynamic fetchedSongDetails = songFallback != null
          ? Map<String, dynamic>.from(songFallback)
          : await getSongDetails(0, songId);

      if (fetchedSongDetails is! Map) {
        logger.log('Failed to update recently played: invalid song details');
        return;
      }

      final newSongDetails = Map<String, dynamic>.from(fetchedSongDetails);
      newSongDetails['ytid'] ??= songId;
      newSongDetails['listeningCount'] = 1;
      newSongDetails['lastPlayed'] = now;
      updatedList.insert(0, newSongDetails);
    }

    userRecentlyPlayed.value = updatedList;
    unawaited(
      addOrUpdateData<List>(
        'user',
        'recentlyPlayedSongs',
        userRecentlyPlayed.value,
      ),
    );
    // Report playback to YouTube Music history (even if streamed via JioSaavn)
    if (YouTubeAuthService().isSignedIn.value && ytReportHistory.value) {
      unawaited(YouTubeMusicSyncService().reportSongPlayed(songId.toString()));
    }
  } catch (e, stackTrace) {
    logger.log(
      'Error updating recently played',
      error: e,
      stackTrace: stackTrace,
    );
  }
}

Future<void> removeFromRecentlyPlayed(dynamic songId) async {
  if (userRecentlyPlayed.value.any((song) => song['ytid'] == songId)) {
    userRecentlyPlayed.value = List.from(userRecentlyPlayed.value)
      ..removeWhere((song) => song['ytid'] == songId);
    unawaited(
      addOrUpdateData<List>(
        'user',
        'recentlyPlayedSongs',
        userRecentlyPlayed.value,
      ),
    );
  }
}
