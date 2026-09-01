import 'dart:async';
import 'package:hive/hive.dart';
import 'package:musified/main.dart';
import 'package:musified/services/jiosaavn_service.dart';
import 'package:musified/services/settings_manager.dart';
import 'package:musified/utilities/track_matcher.dart';

class SourceResolver {
  factory SourceResolver() => _instance;
  SourceResolver._();

  static final SourceResolver _instance = SourceResolver._();

  final JioSaavnService _saavnService = JioSaavnService();

  Future<Box?> _getBox() async {
    try {
      if (Hive.isBoxOpen('saavn_match_cache')) {
        return Hive.box('saavn_match_cache');
      }
      return await Hive.openBox('saavn_match_cache');
    } catch (_) {
      return null;
    }
  }

  Future<void> init() async {
    await _getBox();
  }

  /// Resolve the best audio source for a song.
  Future<Map<String, dynamic>?> resolveAudioSource(
    Map song, {
    String? quality,
  }) async {
    if (!jiosaavnEnabled.value) return null;

    // Source preference is applied by fetchSongStreamUrl. Keeping this
    // resolver source-agnostic also lets the now-playing source picker force
    // JioSaavn for one canonical YouTube track without changing its identity.
    final ytid = song['ytid']?.toString() ?? song['id']?.toString() ?? '';
    if (ytid.isEmpty) return null;

    // Check cache
    try {
      final cached = await getCachedMatch(ytid);
      if (cached != null) {
        final encryptedUrl = cached['encrypted_media_url']?.toString() ?? '';
        if (encryptedUrl.isNotEmpty) {
          final streamUrl = await _saavnService.getStreamUrl(
            encryptedUrl,
            quality: quality ?? jiosaavnQuality.value,
          );
          if (streamUrl != null) {
            logger.log('JioSaavn cached match hit for $ytid');
            return {
              'url': streamUrl,
              'source': 'saavn',
              'bitrate': int.tryParse(quality ?? jiosaavnQuality.value) ?? 320,
              'format': 'm4a',
              'saavnId': cached['saavnId'],
              'image': cached['image'],
            };
          }
          await deleteCachedMatch(ytid);
        }
      }
    } catch (e) {
      logger.log('JioSaavn cache read error: $e');
    }

    // Try several query shapes — YouTube search titles often carry extra words.
    final title = song['title']?.toString() ?? '';
    final artist = song['artist']?.toString() ?? '';
    final queries = <String>{
      '$title $artist'.trim(),
      '$artist $title'.trim(),
      title.trim(),
      ...TrackMatcher.getTitleCandidates(title),
    }.where((q) => q.isNotEmpty).toList();

    for (final query in queries) {
      if (query.isEmpty) continue;
      var results = <Map<String, dynamic>>[];
      try {
        results = await _saavnService.searchTracks(query);
      } catch (e) {
        logger.log('JioSaavn search error for "$query": $e');
        continue;
      }
      if (results.isEmpty) continue;

      for (final track in results) {
        final isMatch = TrackMatcher.isExactMatch(
          titleA: title,
          artistA: artist,
          durationA: song['duration'],
          titleB: track['title']?.toString() ?? '',
          artistB: track['artist']?.toString() ?? '',
          durationB: track['duration'],
        );

        if (isMatch) {
          unawaited(cacheMatch(ytid, track));

          final encryptedUrl = track['encrypted_media_url']?.toString() ?? '';
          if (encryptedUrl.isEmpty) continue;
          final streamUrl = await _saavnService.getStreamUrl(
            encryptedUrl,
            quality: quality ?? jiosaavnQuality.value,
          );

          if (streamUrl != null && streamUrl.isNotEmpty) {
            logger.log(
              'JioSaavn matched [${track['title']} by ${track['artist']}] for $ytid',
            );
            return {
              'url': streamUrl,
              'source': 'saavn',
              'bitrate': int.tryParse(quality ?? jiosaavnQuality.value) ?? 320,
              'format': 'm4a',
              'saavnId': track['saavnId'],
              'image': track['image'],
            };
          }
        }
      }
    }

    return null;
  }

  Future<Map<String, dynamic>?> getCachedMatch(String ytid) async {
    final box = await _getBox();
    final data = box?.get(ytid);
    if (data != null && data is Map) {
      final map = Map<String, dynamic>.from(data);
      map['_accessedAt'] = DateTime.now().millisecondsSinceEpoch;
      unawaited(box?.put(ytid, map));
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  Future<void> cacheMatch(String ytid, Map<String, dynamic> saavnData) async {
    try {
      final box = await _getBox();
      if (box == null) return;
      await box.put(ytid, {
        ...saavnData,
        '_accessedAt': DateTime.now().millisecondsSinceEpoch,
      });
      const maxKeys = 1500;
      if (box.length > maxKeys) {
        final entries = <({dynamic key, int accessed})>[];
        for (final key in box.keys) {
          final raw = box.get(key);
          if (raw is Map) {
            final at = raw['_accessedAt'];
            final ms = at is int ? at : 0;
            entries.add((key: key, accessed: ms));
          }
        }
        entries.sort((a, b) => a.accessed.compareTo(b.accessed));
        final excess = box.length - maxKeys;
        for (var i = 0; i < excess && i < entries.length; i++) {
          await box.delete(entries[i].key);
        }
      }
    } catch (_) {}
  }

  Future<void> deleteCachedMatch(String ytid) async {
    try {
      final box = await _getBox();
      await box?.delete(ytid);
    } catch (_) {}
  }

  Future<void> clearMatchCache() async {
    try {
      final box = await _getBox();
      await box?.clear();
    } catch (_) {}
  }
}
