import 'dart:math';
import 'package:musified/services/playlist_download_service.dart';

class PlaylistUtils {
  static bool isArtistPlaylist(dynamic playlist) =>
      playlist is Map &&
      (playlist['isArtist'] == true ||
          playlist['source']?.toString() == 'youtube-artist');

  static bool isPlaylistOffline(Map playlist) =>
      !isArtistPlaylist(playlist) &&
      offlinePlaylistService.isPlaylistDownloaded(
        playlist['ytid']?.toString() ?? '',
      );

  static bool folderHasOfflinePlaylists(Map folder) {
    final playlists = folder['playlists'] as List? ?? [];
    return playlists.any((p) => p is Map && isPlaylistOffline(p));
  }

  static bool isFolder(Map data) => data.containsKey('playlists');

  static bool isCustomPlaylist(Map playlist) {
    final source = playlist['source']?.toString();
    final playlistId = playlist['ytid']?.toString();
    return source == 'user-created' ||
        (playlistId != null && playlistId.startsWith('customId-'));
  }

  static String generateCustomPlaylistId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final randomSuffix = Random().nextInt(0x7fffffff);
    return 'customId-$timestamp-$randomSuffix';
  }

  static List<dynamic> filterOfflinePlaylistsNotInFolders(
    List<dynamic> rawOfflinePlaylists,
    List<dynamic> folders,
  ) {
    final folderPlaylistIds = folders
        .expand(
          (f) => (f['playlists'] as List? ?? []).map(
            (p) => p is Map ? p['ytid']?.toString() : p?.toString(),
          ),
        )
        .where((id) => id != null)
        .cast<String>()
        .toSet();

    return rawOfflinePlaylists
        .where(
          (p) => p is Map && !folderPlaylistIds.contains(p['ytid']?.toString()),
        )
        .toList();
  }

  /// Returns IDs of offline playlists that are not inside user folders.
  static Set<String> offlinePlaylistIdsNotInFolders(
    List<dynamic> rawOfflinePlaylists,
    List<dynamic> folders,
  ) {
    final items = filterOfflinePlaylistsNotInFolders(
      rawOfflinePlaylists,
      folders,
    );
    return items.map((p) => p['ytid']?.toString()).whereType<String>().toSet();
  }

  /// Returns playlists with any entry whose ytid is present in ids removed.
  static List<dynamic> excludePlaylistsWithIds(
    List<dynamic> playlists,
    Set<String> ids,
  ) {
    return playlists
        .where((p) => p is Map && !ids.contains(p['ytid']?.toString()))
        .toList();
  }

  /// Find the index of a song in a playlist by its ytid.
  /// Returns the index if found, -1 if not found.
  static int findSongIndexByYtid(Map playlist, String songYtid) {
    final list = playlist['list'] as List<dynamic>? ?? [];
    return list.indexWhere((s) => s is Map && s['ytid'] == songYtid);
  }

  /// Check if a playlist already exists by title and song ytids.
  static bool playlistExists(
    Map<String, dynamic> playlist,
    List<String> incomingYtids,
    List<dynamic> playlistsToCheck,
  ) {
    return playlistsToCheck.any((p) {
      if (p['title'] != playlist['title']) return false;
      final existingList = (p['list'] as List<dynamic>?) ?? [];
      final existingYtids = existingList
          .map((s) => s['ytid']?.toString())
          .where((e) => e != null)
          .toList();
      if (existingYtids.length != incomingYtids.length) return false;
      return listsEqual(existingYtids, incomingYtids);
    });
  }

  /// Compare two lists of strings for equality.
  static bool listsEqual(List<String?> list1, List<String> list2) {
    for (var i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }
}
