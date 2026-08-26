import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:musify/main.dart' show logger;
import 'package:musify/services/common_services.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/services/youtube_auth_service.dart';

class YouTubeMusicSyncService {
  static final YouTubeMusicSyncService _instance = YouTubeMusicSyncService._internal();

  factory YouTubeMusicSyncService() => _instance;

  YouTubeMusicSyncService._internal();

  static const _remixContext = {
    'client': {
      'clientName': 'WEB_REMIX',
      'clientVersion': '1.20240101.01.00',
      'hl': 'en',
    },
  };

  static const _baseUrl = 'https://music.youtube.com/youtubei/v1';

  final ValueNotifier<List<Map<String, dynamic>>> ytMusicPlaylists = ValueNotifier([]);
  final ValueNotifier<DateTime?> lastSyncTime = ValueNotifier(null);
  final ValueNotifier<bool> isSyncing = ValueNotifier(false);

  Future<void> initialize() async {
    try {
      if (Hive.isBoxOpen('settings')) {
        final box = Hive.box('settings');
        final syncTime = box.get('lastYtSyncTime');
        if (syncTime is int) {
          lastSyncTime.value = DateTime.fromMillisecondsSinceEpoch(syncTime);
        }
      }
      await _hydratePlaylistsFromCache();
    } catch (e) {
      logger.log('Error initializing YouTubeMusicSyncService: $e');
    }
  }

  Future<void> _hydratePlaylistsFromCache() async {
    try {
      final cached = await getData('user', 'ytMusicPlaylists');
      if (cached is! List || cached.isEmpty) return;
      final playlists = <Map<String, dynamic>>[];
      for (final item in cached) {
        if (item is Map) {
          playlists.add(Map<String, dynamic>.from(item));
        }
      }
      if (playlists.isNotEmpty && ytMusicPlaylists.value.isEmpty) {
        ytMusicPlaylists.value = playlists;
      }
    } catch (e) {
      logger.log('Error hydrating YT playlists cache: $e');
    }
  }

  Future<void> _persistPlaylists(List<Map<String, dynamic>> playlists) async {
    try {
      await addOrUpdateData<List>(
        'user',
        'ytMusicPlaylists',
        playlists,
      );
    } catch (e) {
      logger.log('Error persisting YT playlists: $e');
    }
  }

  bool _isValidYouTubeVideoId(String id) {
    return id.length == 11 && RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(id);
  }

  Future<Map<String, dynamic>> _authenticatedPost(String endpoint, Map<String, dynamic> body) async {
    final authService = YouTubeAuthService();
    final headers = authService.getAuthHeaders();
    if (headers.isEmpty) {
      throw Exception('Not authenticated');
    }

    headers['Content-Type'] = 'application/json';

    final fullBody = {
      'context': _remixContext,
      ...body,
    };

    final response = await http.post(
      Uri.parse('$_baseUrl$endpoint'),
      headers: headers,
      body: jsonEncode(fullBody),
    );

    if (response.statusCode != 200) {
      throw Exception('YouTube API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    if (data is Map<String, dynamic>) {
      return data;
    }
    return {};
  }

  String? _runsText(Map<String, dynamic>? node) {
    final runs = node?['runs'];
    if (runs is! List) return null;
    return runs.map((run) => (run as Map)['text']?.toString() ?? '').join('');
  }

  Iterable<Map<String, dynamic>> _findRenderers(dynamic node, String key) sync* {
    if (node is Map) {
      final match = node[key];
      if (match is Map) yield Map<String, dynamic>.from(match);
      for (final value in node.values) {
        yield* _findRenderers(value, key);
      }
    } else if (node is List) {
      for (final value in node) {
        yield* _findRenderers(value, key);
      }
    }
  }

  String? _extractVideoId(Map<String, dynamic> renderer) {
    try {
      final overlay = renderer['overlay'] as Map?;
      final overlayRenderer = overlay?['musicItemThumbnailOverlayRenderer'] as Map?;
      final content = overlayRenderer?['content'] as Map?;
      final playBtn = content?['musicPlayButtonRenderer'] as Map?;
      final nav = playBtn?['playNavigationEndpoint'] as Map?;
      final watch = nav?['watchEndpoint'] as Map?;
      return watch?['videoId']?.toString();
    } catch (e) {
      return null;
    }
  }

  List<Map<String, dynamic>> _parseTrackRenderers(Map<String, dynamic> response) {
    final tracks = <Map<String, dynamic>>[];
    for (final item in _findRenderers(response, 'musicResponsiveListItemRenderer')) {
      final videoId = _extractVideoId(item);
      if (videoId == null) continue;

      final flexColumns = item['flexColumns'];
      if (flexColumns is! List) continue;

      String title = '';
      String artist = '';

      if (flexColumns.isNotEmpty) {
        final col0 = flexColumns[0] as Map?;
        final col0Renderer = col0?['musicResponsiveListItemFlexColumnRenderer'] as Map?;
        title = _runsText(col0Renderer?['text'] as Map<String, dynamic>?) ?? '';
      }

      if (flexColumns.length > 1) {
        final col1 = flexColumns[1] as Map?;
        final col1Renderer = col1?['musicResponsiveListItemFlexColumnRenderer'] as Map?;
        artist = _runsText(col1Renderer?['text'] as Map<String, dynamic>?) ?? '';
      }

      String? imageUrl;
      final thumbnailMap = item['thumbnail'] as Map?;
      final musicThumbnailRenderer = thumbnailMap?['musicThumbnailRenderer'] as Map?;
      final thumbnailData = musicThumbnailRenderer?['thumbnail'] as Map?;
      final thumbnails = thumbnailData?['thumbnails'];
      if (thumbnails is List && thumbnails.isNotEmpty) {
        final lastThumb = thumbnails.last as Map?;
        imageUrl = lastThumb?['url']?.toString();
      }

      tracks.add({
        'ytid': videoId,
        'title': title,
        'artist': artist,
        'image': imageUrl ?? '',
        'source': 'youtube',
      });
    }
    return tracks;
  }

  Future<List<Map<String, dynamic>>> fetchLikedSongs() async {
    try {
      return _browseAllTracks('FEmusic_liked_videos');
    } catch (e) {
      logger.log('Error fetching liked songs: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchUserPlaylists() async {
    try {
      final response = await _authenticatedPost('/browse', {
        'browseId': 'FEmusic_liked_playlists',
      });

      final playlists = <Map<String, dynamic>>[];
      for (final item in _findRenderers(response, 'musicTwoRowItemRenderer')) {
        final nav = item['navigationEndpoint'] as Map?;
        final browse = nav?['browseEndpoint'] as Map?;
        final playlistId = browse?['browseId']?.toString();

        if (playlistId == null) continue;

        final title = _runsText(item['title'] as Map<String, dynamic>?) ?? '';

        String? imageUrl;
        final thumbnailRenderer = item['thumbnailRenderer'] as Map?;
        final musicThumbnailRenderer = thumbnailRenderer?['musicThumbnailRenderer'] as Map?;
        final thumbnail = musicThumbnailRenderer?['thumbnail'] as Map?;
        final thumbnails = thumbnail?['thumbnails'];
        if (thumbnails is List && thumbnails.isNotEmpty) {
          final lastThumb = thumbnails.last as Map?;
          imageUrl = lastThumb?['url']?.toString();
        }

        final subtitle = _runsText(item['subtitle'] as Map<String, dynamic>?) ?? '';
        final count = _parseTrackCount(subtitle);

        playlists.add({
          'playlistId': playlistId,
          'title': title,
          'image': imageUrl ?? '',
          // Library UI reads `count`; keep subtitle as `trackCount` for display fallback.
          'count': count ?? 0,
          'trackCount': subtitle,
        });
      }
      return playlists;
    } catch (e) {
      logger.log('Error fetching user playlists: $e');
      return [];
    }
  }

  /// Extracts a song count from YT Music subtitle runs (e.g. "Playlist • 42 songs").
  int? _parseTrackCount(String subtitle) {
    if (subtitle.isEmpty) return null;
    final withUnit = RegExp(
      r'(\d[\d,]*)\s*(songs?|tracks?)',
      caseSensitive: false,
    ).firstMatch(subtitle);
    final raw = withUnit?.group(1) ??
        RegExp(r'(\d[\d,]*)').firstMatch(subtitle)?.group(1);
    if (raw == null) return null;
    return int.tryParse(raw.replaceAll(',', ''));
  }

  Future<List<Map<String, dynamic>>> fetchPlaylistTracks(String playlistId) async {
    try {
      final browseId = playlistId.startsWith('VL') || playlistId.startsWith('FE')
          ? playlistId
          : 'VL$playlistId';
      return await _browseAllTracks(browseId);
    } catch (e) {
      logger.log('Error fetching playlist tracks: $e');
      return [];
    }
  }

  /// Walks browse + continuation pages until exhausted (capped for safety).
  Future<List<Map<String, dynamic>>> _browseAllTracks(String browseId) async {
    final tracks = <Map<String, dynamic>>[];
    final seen = <String>{};

    var response = await _authenticatedPost('/browse', {
      'browseId': browseId,
    });
    _appendUniqueTracks(tracks, seen, _parseTrackRenderers(response));

    var continuation = _extractContinuation(response);
    var pages = 0;
    const maxPages = 25;

    while (continuation != null &&
        continuation.isNotEmpty &&
        pages < maxPages) {
      pages++;
      response = await _authenticatedPost('/browse', {
        'continuation': continuation,
      });
      final pageTracks = _parseTrackRenderers(response);
      if (pageTracks.isEmpty) break;
      final before = tracks.length;
      _appendUniqueTracks(tracks, seen, pageTracks);
      if (tracks.length == before) break;
      continuation = _extractContinuation(response);
    }

    return tracks;
  }

  void _appendUniqueTracks(
    List<Map<String, dynamic>> dest,
    Set<String> seen,
    List<Map<String, dynamic>> page,
  ) {
    for (final track in page) {
      final id = track['ytid']?.toString();
      if (id == null || id.isEmpty || seen.contains(id)) continue;
      seen.add(id);
      dest.add(track);
    }
  }

  String? _extractContinuation(Map<String, dynamic> response) {
    for (final node in _findRenderers(response, 'nextContinuationData')) {
      final token = node['continuation']?.toString();
      if (token != null && token.isNotEmpty) return token;
    }
    for (final node in _findRenderers(response, 'continuationEndpoint')) {
      final cont = node['continuationCommand'] as Map?;
      final token = cont?['token']?.toString();
      if (token != null && token.isNotEmpty) return token;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchPersonalizedMixes() async {
    try {
      final response = await _authenticatedPost('/browse', {
        'browseId': 'FEmusic_home',
      });

      final mixes = <Map<String, dynamic>>[];
      for (final item in _findRenderers(response, 'musicTwoRowItemRenderer')) {
        final title = _runsText(item['title'] as Map<String, dynamic>?) ?? '';
        if (title.toLowerCase().contains('mix')) {
          final nav = item['navigationEndpoint'] as Map?;
          final browse = nav?['browseEndpoint'] as Map?;
          final playlistId = browse?['browseId']?.toString();

          if (playlistId == null) continue;

          String? imageUrl;
          final thumbnailRenderer = item['thumbnailRenderer'] as Map?;
          final musicThumbnailRenderer = thumbnailRenderer?['musicThumbnailRenderer'] as Map?;
          final thumbnail = musicThumbnailRenderer?['thumbnail'] as Map?;
          final thumbnails = thumbnail?['thumbnails'];
          if (thumbnails is List && thumbnails.isNotEmpty) {
            final lastThumb = thumbnails.last as Map?;
            imageUrl = lastThumb?['url']?.toString();
          }

          mixes.add({
            'playlistId': playlistId,
            'title': title,
            'image': imageUrl ?? '',
          });
        }
      }
      return mixes;
    } catch (e) {
      logger.log('Error fetching personalized mixes: $e');
      return [];
    }
  }

  Future<bool> likeSong(String videoId) async {
    if (!_isValidYouTubeVideoId(videoId)) {
      return false; // JioSaavn or non-YouTube ID, ignore safely
    }
    try {
      await _authenticatedPost('/like/like', {
        'target': {'videoId': videoId},
      });
      return true;
    } catch (e) {
      logger.log('Error liking song: $e');
      return false;
    }
  }

  Future<bool> unlikeSong(String videoId) async {
    if (!_isValidYouTubeVideoId(videoId)) {
      return false;
    }
    try {
      await _authenticatedPost('/like/removelike', {
        'target': {'videoId': videoId},
      });
      return true;
    } catch (e) {
      logger.log('Error unliking song: $e');
      return false;
    }
  }

  /// Content Playback Nonce used by YouTube stats endpoints.
  String _generateCpn() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
    final rng = Random.secure();
    return List.generate(16, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  String? _extractPlaybackTrackingUrl(Map<String, dynamic> player) {
    final tracking = player['playbackTracking'];
    if (tracking is! Map) return null;
    final urlNode = tracking['videostatsPlaybackUrl'];
    if (urlNode is Map) return urlNode['baseUrl']?.toString();
    if (urlNode is String) return urlNode;
    return null;
  }

  Future<void> _pingNextForHistory(String videoId) async {
    await _authenticatedPost('/next', {
      'videoId': videoId,
      'isAudioOnly': true,
    });
  }

  /// Reports a play to YouTube Music watch history when the user is signed in.
  /// Uses player playback-tracking URLs (same path as official clients); falls
  /// back to an authenticated `/next` nudge if tracking URLs are missing.
  Future<bool> reportSongPlayed(String videoId) async {
    if (!_isValidYouTubeVideoId(videoId)) {
      return false;
    }
    try {
      final player = await _authenticatedPost('/player', {
        'videoId': videoId,
        'contentCheckOk': true,
        'racyCheckOk': true,
      });

      final playbackUrl = _extractPlaybackTrackingUrl(player);
      if (playbackUrl == null || playbackUrl.isEmpty) {
        await _pingNextForHistory(videoId);
        return true;
      }

      final cpn = _generateCpn();
      final normalized = playbackUrl.replaceFirst('https://s.', 'https://www.');
      final uri = Uri.parse(normalized);
      final params = Map<String, String>.from(uri.queryParameters)
        ..['cpn'] = cpn
        ..['fmt'] = '251'
        ..['rtn'] = '0'
        ..['rt'] = '0';

      final headers = YouTubeAuthService().getAuthHeaders();
      if (headers.isEmpty) return false;
      headers['User-Agent'] =
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
          'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148';

      final response = await http.get(
        uri.replace(queryParameters: params),
        headers: headers,
      );

      if (response.statusCode >= 200 && response.statusCode < 400) {
        return true;
      }

      await _pingNextForHistory(videoId);
      return true;
    } catch (e) {
      logger.log('Error reporting song played: $e');
      try {
        await _pingNextForHistory(videoId);
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  Future<void> syncLikedSongs() async {
    if (!ytAutoSyncLikes.value) return;
    try {
      final ytLikes = await fetchLikedSongs();

      userLikedSongsList.value = ytLikes;
      unawaited(addOrUpdateData<List>('user', 'likedSongs', ytLikes));

      _updateSyncTime();
    } catch (e) {
      logger.log('Error syncing liked songs: $e');
    }
  }

  Future<void> syncPlaylists() async {
    if (!ytAutoSyncPlaylists.value) return;
    try {
      final playlists = await fetchUserPlaylists();
      ytMusicPlaylists.value = playlists;
      unawaited(_persistPlaylists(playlists));
      _updateSyncTime();
    } catch (e) {
      logger.log('Error syncing playlists: $e');
    }
  }

  Future<void> fullSync() async {
    if (isSyncing.value) return;

    isSyncing.value = true;
    try {
      final authService = YouTubeAuthService();
      if (!authService.isSignedIn.value) {
        isSyncing.value = false;
        return;
      }

      await Future.wait([
        syncLikedSongs(),
        syncPlaylists(),
      ]);
    } catch (e) {
      logger.log('Error during full sync: $e');
    } finally {
      isSyncing.value = false;
    }
  }

  void _updateSyncTime() {
    final now = DateTime.now();
    lastSyncTime.value = now;
    if (Hive.isBoxOpen('settings')) {
      unawaited(addOrUpdateData<int>('settings', 'lastYtSyncTime', now.millisecondsSinceEpoch));
    }
  }
}
