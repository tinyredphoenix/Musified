import 'dart:convert';

import 'package:musified/main.dart';
import 'package:musified/services/youtube_client.dart';
import 'package:musified/utilities/app_utils.dart';
import 'package:musified/utilities/formatter.dart';

class PlaylistSharingService {
  static const int _maxExpandConcurrency = 5;
  static const int _maxSharedPlaylistSongs = 200;

  static Map<String, dynamic> createCompactPlaylist(Map fullPlaylist) {
    return {
      'title': fullPlaylist['title'],
      if (fullPlaylist['image'] != null) 'image': fullPlaylist['image'],
      'source': 'user-created',
      'list': fullPlaylist['list'].map((song) => song['ytid']).toList(),
    };
  }

  static Future<List<T?>> _mapWithConcurrency<T>(
    int length,
    Future<T?> Function(int index) task, {
    int concurrency = _maxExpandConcurrency,
  }) async {
    if (length <= 0) return const [];
    final results = List<T?>.filled(length, null);
    var nextIndex = 0;
    final workers = concurrency.clamp(1, length);

    Future<void> worker() async {
      while (true) {
        final index = nextIndex++;
        if (index >= length) return;
        results[index] = await task(index);
      }
    }

    await Future.wait(List.generate(workers, (_) => worker()));
    return results;
  }

  static Future<Map<String, dynamic>> expandCompactPlaylist(
    Map<String, dynamic> compactPlaylist,
  ) async {
    final List<dynamic> songIds = compactPlaylist['list'];
    if (songIds.length > _maxSharedPlaylistSongs) {
      throw StateError('Shared playlist exceeds $_maxSharedPlaylistSongs songs');
    }

    final expandedSongs = await _mapWithConcurrency<Map<String, dynamic>?>(
      songIds.length,
      (index) async {
        final ytid = songIds[index]?.toString();
        if (!isValidYoutubeVideoId(ytid)) return null;
        try {
          final video = await ytClient.videos.get(ytid!);
          return returnSongLayout(index, video);
        } catch (e, stackTrace) {
          logger.log(
            'Error expanding song: $ytid',
            error: e,
            stackTrace: stackTrace,
          );
          return null;
        }
      },
    );

    return {
      ...compactPlaylist,
      'list': expandedSongs.whereType<Map<String, dynamic>>().toList(),
    };
  }

  static String encodePlaylist(Map playlist) {
    final compactPlaylist = createCompactPlaylist(playlist);
    return base64Url.encode(utf8.encode(json.encode(compactPlaylist)));
  }

  static Future<Map<String, dynamic>?> decodeAndExpandPlaylist(
    String encodedPlaylist,
  ) async {
    try {
      final jsonString = utf8.decode(base64Url.decode(encodedPlaylist));
      final compactPlaylist = json.decode(jsonString) as Map<String, dynamic>;
      return await expandCompactPlaylist(compactPlaylist);
    } catch (e, stackTrace) {
      logger.log('Failed to decode playlist', error: e, stackTrace: stackTrace);
      return null;
    }
  }
}
