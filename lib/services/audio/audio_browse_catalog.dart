import 'package:audio_service/audio_service.dart';
import 'package:musified/utilities/app_utils.dart';
import 'package:musified/utilities/map_utils.dart';
import 'package:musified/utilities/mediaitem.dart';

/// Lock-screen / CarPlay browse IDs and song lookup helpers.
abstract final class AudioBrowseCatalog {
  static const String recentMediaIdPrefix = 'recent:';

  static const String rootLiked = 'liked_songs';
  static const String rootOffline = 'offline_songs';
  static const String rootRecent = 'recently_played';
  static const String rootQueue = 'current_queue';

  static String recentMediaId(String ytid) => '$recentMediaIdPrefix$ytid';

  static String? ytidFromMediaId(String mediaId) {
    if (mediaId.isEmpty) return null;
    if (mediaId.startsWith(recentMediaIdPrefix)) {
      return mediaId.substring(recentMediaIdPrefix.length);
    }
    if (mediaId.startsWith('queue-')) return null;
    if (isValidYoutubeVideoId(mediaId)) return mediaId;
    return null;
  }

  static Map? findByQueueEntryId(String? entryId, List<Map> queueItems) {
    if (entryId == null || entryId.isEmpty) return null;
    for (final song in queueItems) {
      if (song['queueEntryId']?.toString() == entryId) return song;
    }
    return null;
  }

  static Map? findByMediaId(
    String mediaId, {
    required Map? currentSong,
    required List<Map> queueItems,
    required Iterable liked,
    required Iterable offline,
    required Iterable recent,
  }) {
    final fromQueue = findByQueueEntryId(mediaId, queueItems);
    if (fromQueue != null) return fromQueue;

    final ytid = ytidFromMediaId(mediaId);
    if (ytid == null) return null;
    return findByYtid(
      ytid,
      currentSong: currentSong,
      queueItems: queueItems,
      liked: liked,
      offline: offline,
      recent: recent,
    );
  }

  static String? songYtid(Map song) {
    final ytid = song['ytid']?.toString();
    return ytid == null || ytid.isEmpty ? null : ytid;
  }

  static Map? firstPlayableSong(Iterable songs) {
    for (final song in songs.whereType<Map>()) {
      if (songYtid(song) != null) return song;
    }
    return null;
  }

  static Map? findInList(Iterable songs, String ytid) {
    for (final song in songs.whereType<Map>()) {
      if (songYtid(song) == ytid) return song;
    }
    return null;
  }

  static Map? findByYtid(
    String? ytid, {
    required Map? currentSong,
    required List<Map> queueItems,
    required Iterable liked,
    required Iterable offline,
    required Iterable recent,
  }) {
    if (ytid == null || ytid.isEmpty) return null;
    if (currentSong != null && songYtid(currentSong) == ytid) return currentSong;

    for (final source in [queueItems, recent, offline, liked]) {
      final song = findInList(source, ytid);
      if (song != null) return song;
    }
    return null;
  }

  static Map? latestResumableSong({
    required Map? currentSong,
    required MediaItem? activeMediaItem,
    required Iterable recent,
    required Iterable offline,
    required Iterable liked,
    required List<Map> queueItems,
  }) {
    if (currentSong != null && songYtid(currentSong) != null) return currentSong;

    final activeYtid = activeMediaItem?.extras?['ytid']?.toString();
    final fromLibraries = findByYtid(
      activeYtid,
      currentSong: null,
      queueItems: queueItems,
      liked: liked,
      offline: offline,
      recent: recent,
    );
    if (fromLibraries != null) return fromLibraries;

    if (activeYtid != null &&
        activeYtid.isNotEmpty &&
        activeMediaItem != null) {
      return mediaItemToMap(activeMediaItem);
    }

    return firstPlayableSong(recent) ??
        firstPlayableSong(offline) ??
        firstPlayableSong(liked);
  }

  static Map<String, dynamic>? normaliseResumableSong(Map song) {
    final ytid = songYtid(song);
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

  static MediaItem? mediaItemForResumption(Map song) {
    final normalised = normaliseResumableSong(song);
    if (normalised == null) return null;

    final ytid = normalised['ytid'].toString();
    final artist = normalised['artist']?.toString().trim() ?? '';
    return mapToMediaItem(normalised).copyWith(
      id: recentMediaId(ytid),
      displayTitle: normalised['title']?.toString(),
      displaySubtitle: artist.isEmpty ? 'Musify' : artist,
    );
  }

  static List<MediaItem> browsableRootChildren() {
    return [
      const MediaItem(
        id: rootQueue,
        title: 'Now Playing Queue',
        playable: false,
        extras: {'isBrowsable': true},
      ),
      const MediaItem(
        id: rootLiked,
        title: 'Liked Songs',
        playable: false,
        extras: {'isBrowsable': true},
      ),
      const MediaItem(
        id: rootOffline,
        title: 'Downloaded',
        playable: false,
        extras: {'isBrowsable': true},
      ),
      const MediaItem(
        id: rootRecent,
        title: 'Recently Played',
        playable: false,
        extras: {'isBrowsable': true},
      ),
    ];
  }
}
