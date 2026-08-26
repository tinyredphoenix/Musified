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

import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:musify/constants/clients.dart';
import 'package:musify/main.dart' show logger;
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/io_service.dart';
import 'package:musify/services/lyrics_manager.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/proxy_manager.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/services/source_resolver.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/utilities/formatter.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:musify/services/artist_service.dart' show ytMusicClient;
import 'package:musify/services/youtube_auth_service.dart';
import 'package:musify/services/youtube_music_sync_service.dart';

List globalSongs = [];

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
const Duration _manifestTimeout = Duration(seconds: 8);
const Duration _cacheValidationDuration = Duration(hours: 1);

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
  // Keep URL and provenance writes ordered. A URL without its source metadata
  // is unsafe to reuse because it can make the UI report the wrong service.
  await addOrUpdateData<String>('cache', key, url);
  await addOrUpdateData<Map<String, dynamic>>(
    'cache',
    _songStreamCacheMetaKey(songId, source),
    {'source': source, ...metadata},
  );
}

/// Fetches a stream manifest for a song, honoring proxy settings.
String? _youtubeClientUserAgent(YoutubeApiClient client) {
  final clientContext = client.payload['context']?['client'];
  return clientContext is Map ? clientContext['userAgent']?.toString() : null;
}

Future<({StreamManifest manifest, YoutubeApiClient? client})?>
_fetchStreamManifest(String songId) async {
  if (useProxy.value) {
    final manifest = await ProxyManager()
        .getSongManifest(songId)
        .timeout(_manifestTimeout);
    if (manifest == null) return null;
    return (manifest: manifest, client: null);
  }

  // 1. Fetch with fast mobile clients in parallel
  try {
    final manifest = await ytClient.videos.streams
        .getManifest(songId, ytClients: customClients)
        .timeout(_manifestTimeout);
    return (manifest: manifest, client: YoutubeApiClient.androidVr);
  } catch (error) {
    logger.log('Multi-client manifest failed for $songId, trying fallback: $error');
  }

  // 2. Fallback to standard manifest fetch
  try {
    final manifest = await ytClient.videos.streams
        .getManifest(songId)
        .timeout(_manifestTimeout);
    return (manifest: manifest, client: null);
  } catch (error) {
    logger.log('Default getManifest failed for $songId: $error');
    rethrow;
  }
}

/// Returns a cached song URL if present and still valid.
Future<String?> _getCachedSongUrl(
  String cacheKey,
  Duration cacheDuration,
) async {
  final cachedUrl = await getData(
    'cache',
    cacheKey,
    cachingDuration: cacheDuration,
  );

  if (cachedUrl is! String || cachedUrl.isEmpty) {
    return null;
  }

  return cachedUrl;
}

/// Checks if a cached URL still responds successfully.
Future<bool> _validateCachedUrl(String cachedUrl) async {
  try {
    final response = await http.head(Uri.parse(cachedUrl));
    return response.statusCode >= 200 && response.statusCode < 300;
  } catch (_) {
    return false;
  }
}

Future<List> fetchSongsList(String searchQuery) async {
  try {
    // 1. Search YouTube Music catalog for songs only (avoids news, vlogs, reactions)
    final musicTracks = await ytMusicClient.music.searchSongs(searchQuery);
    if (musicTracks.isNotEmpty) {
      return musicTracks
          .map((video) => returnSongLayout(0, video))
          .toList();
    }

    // 2. Fallback: query YouTube with music filter suffix
    final List<Video> searchResults =
        await ytClient.search.search('$searchQuery audio');
    return searchResults
        .map((video) => returnSongLayout(0, video))
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

Map<String, dynamic> getOfflineSongByYtid(String ytid) {
  try {
    final song = userOfflineSongs.value.firstWhere(
      (s) => s['ytid'] == ytid,
      orElse: () => <String, dynamic>{},
    );
    return Map<String, dynamic>.from(song);
  } catch (_) {
    return <String, dynamic>{};
  }
}

/// True when a fully downloaded copy exists on disk.
/// Fully downloaded tracks always play from disk — online source switches
/// must not override this.
bool hasPlayableOfflineFile(String? ytid) {
  if (ytid == null || ytid.isEmpty) return false;
  final path = getOfflineSongByYtid(ytid)['audioPath']?.toString();
  if (path == null || path.isEmpty) return false;
  try {
    return File(path).existsSync();
  } catch (_) {
    return false;
  }
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

/// Drops both cached forms of a song's stream, so the next request resolves
/// it again. Used when a cached URL turns out to be dead.
Future<void> invalidateSongStreamCache(String songId) async {
  _selectedAudioStreams.remove(_selectedAudioStreamKey(songId));
  for (final source in ['youtube', 'jiosaavn']) {
    final key = _songStreamCacheKey(songId, source);
    await deleteData('cache', key);
    await deleteData('cache', _songStreamCacheMetaKey(songId, source));
  }
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
    if (cachedSelection != null) return cachedSelection.stream;

    final resolvedManifest = await _fetchStreamManifest(songId);
    final audioStream = resolvedManifest?.manifest.audioOnly;
    if (audioStream == null || audioStream.isEmpty) {
      logger.log('fetchBestAudioStream: no audio streams for $songId');
      return null;
    }

    final selectedStream = selectAudioOnlyStreamForQuality(
      audioStream.sortByBitrate(),
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
  logger.log('Resolution start for songId=$songId');
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

    const cacheDuration = Duration(hours: 3);
    final forceSource = song['forceSource']?.toString();
    // The UI uses `jiosaavn`, while older settings/download records use
    // `saavn`. Normalize both spellings before selecting a provider so an
    // explicit source switch can never silently fall back to auto mode.
    final requestedPreference = forceSource ?? preferredSource.value;
    final preference = requestedPreference == 'saavn'
        ? 'jiosaavn'
        : requestedPreference;
    final sources = switch (preference) {
      'youtube' => ['youtube'],
      'jiosaavn' => ['jiosaavn'],
      _ => ['jiosaavn', 'youtube'],
    };

    // Cache entries are source-specific. This prevents a JioSaavn URL from
    // being replayed after switching to YouTube (and vice versa).
    for (final source in sources) {
      final sourceKey = _songStreamCacheKey(songId, source);
      final cachedUrl = await _getCachedSongUrl(sourceKey, cacheDuration);
      if (cachedUrl == null) continue;
      final cacheBox = await Hive.openBox('cache');
      final metadata = cacheBox.get(_songStreamCacheMetaKey(songId, source));
      if (metadata is! Map || metadata['source'] != source) {
        await deleteData('cache', sourceKey);
        continue;
      }
      song['resolvedSource'] = source;
      song['resolvedBitrate'] = metadata['bitrate'];
      song['resolvedFormat'] = metadata['format'];
      song['resolvedUserAgent'] = metadata['userAgent'];
      return cachedUrl;
    }

    // Try JioSaavn only when it is an allowed source. If YouTube is also an allowed
    // source, resolve both concurrently so if JioSaavn doesn't have the track, YouTube
    // starts playing immediately without waiting 4+ seconds.
    if (jiosaavnEnabled.value && sources.contains('jiosaavn')) {
      Future<AudioOnlyStreamInfo?>? parallelYtFuture;
      if (sources.contains('youtube')) {
        parallelYtFuture = fetchBestAudioStream(songId);
      }

      try {
        final saavnSource = await SourceResolver()
            .resolveAudioSource(song)
            .timeout(const Duration(milliseconds: 1500), onTimeout: () => null);
        if (saavnSource != null && saavnSource['url'] != null) {
          final url = saavnSource['url'] as String;
          if (url.isNotEmpty) {
            logger.log(
              'JioSaavn stream result found: host=${Uri.tryParse(url)?.host}',
            );
            song['resolvedSource'] = 'jiosaavn';
            song['resolvedBitrate'] = saavnSource['bitrate'];
            song['resolvedFormat'] = saavnSource['format'];
            await _cacheResolvedStream(songId, 'jiosaavn', url, {
              'bitrate': saavnSource['bitrate'],
              'format': saavnSource['format'],
            });
            logger.log('Final URL resolved via jiosaavn');
            return url;
          }
        }
        logger.log('JioSaavn search result not found or empty url');
      } catch (e) {
        logger.log('JioSaavn resolve error: $e');
      }

      if (parallelYtFuture != null) {
        final selectedStream = await parallelYtFuture;
        if (selectedStream != null) {
          final url = selectedStream.url.toString();
          logger.log('YouTube stream result found: host=${Uri.tryParse(url)?.host}');
          song['resolvedSource'] = 'youtube';
          song['resolvedBitrate'] = selectedStream.bitrate.kiloBitsPerSecond.round();
          song['resolvedFormat'] = selectedStream.audioCodec;
          await _cacheResolvedStream(songId, 'youtube', url, {
            'bitrate': selectedStream.bitrate.kiloBitsPerSecond.round(),
            'format': selectedStream.audioCodec,
          });
          logger.log('Final URL resolved via youtube');
          return url;
        }
      }
    }

    if (!sources.contains('youtube')) return null;

    // Get fresh URL, reusing the stream already resolved for this song.
    final selectedStream = await fetchBestAudioStream(songId);
    if (selectedStream == null) {
      logger.log('fetchSongStreamUrl: no audio streams for $songId');
      return null;
    }

    final url = selectedStream.url.toString();
    logger.log('YouTube stream result found: host=${Uri.tryParse(url)?.host}');
    song['resolvedSource'] = 'youtube';
    song['resolvedBitrate'] = selectedStream.bitrate.kiloBitsPerSecond.round();
    song['resolvedFormat'] = selectedStream.audioCodec;
    final selectedClient = _getSelectedAudioStream(songId)?.client;
    final userAgent = selectedClient == null
        ? null
        : _youtubeClientUserAgent(selectedClient);
    song['resolvedUserAgent'] = userAgent;

    await _cacheResolvedStream(songId, 'youtube', url, {
      'bitrate': song['resolvedBitrate'],
      'format': song['resolvedFormat'],
      'userAgent': userAgent,
    });
    logger.log('Final URL resolved via youtube');

    return url;
  } on TimeoutException catch (_) {
    logger.log('fetchSongStreamUrl request timed out for $songId');
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

    final offlineSong = Map<String, dynamic>.from(song as Map);
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
          logger.log('makeSongOffline: audioManifest is null for $ytid');
          return false;
        }
        downloadedSource = 'youtube';
        audioBitrateKbps = audioManifest.bitrate.kiloBitsPerSecond.round();
        audioCodec = audioManifest.audioCodec;

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
