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

import 'package:audio_service/audio_service.dart';
import 'package:musify/services/common_services.dart';

Map mediaItemToMap(MediaItem mediaItem) {
  final extras = mediaItem.extras;
  final album = mediaItem.album;
  return {
    'id': mediaItem.id,
    'ytid': extras?['ytid'],
    'album': (album == null || album == 'null') ? null : album,
    'artist': mediaItem.artist?.toString(),
    'title': mediaItem.title,
    'artistId': extras?['artistId'],
    'videoAuthor': extras?['videoAuthor'],
    'highResImage': extras?['highResImage'] ?? mediaItem.artUri?.toString(),
    'lowResImage': extras?['lowResImage'],
    'isLive': extras?['isLive'] ?? false,
    'isOffline': extras?['isOffline'] ?? false,
    'downloadSource': extras?['downloadSource'],
    'resolvedSource': extras?['resolvedSource'],
    'resolvedBitrate': extras?['resolvedBitrate'],
    'resolvedFormat': extras?['resolvedFormat'],
  };
}

String upgradeArtworkUrl(String url, {int targetSize = 800}) {
  if (url.isEmpty || url == 'null') return url;

  var upgraded = url;
  // 1. Google / YouTube Music CDN URLs with sizing parameters (=w120-h120, =s120, etc.)
  if (upgraded.contains('googleusercontent.com') ||
      upgraded.contains('ggpht.com')) {
    upgraded = upgraded
        .replaceAll(RegExp(r'=w\d+-h\d+(?:-[a-zA-Z0-9]+)*'), '=w$targetSize-h$targetSize-l90-rj')
        .replaceAll(RegExp(r'=s\d+(?:-[a-zA-Z0-9]+)*'), '=s$targetSize');
  }

  // 2. JioSaavn CDN artwork (e.g. 50x50.jpg, 150x150.jpg -> 500x500.jpg)
  if (upgraded.contains('saavncdn.com')) {
    upgraded = upgraded
        .replaceAll('50x50.jpg', '500x500.jpg')
        .replaceAll('150x150.jpg', '500x500.jpg');
  }

  // 3. YouTube standard thumbnails: upgrade hqdefault (480x360) / default (120x90) / sddefault (640x480)
  if (upgraded.contains('ytimg.com/vi/')) {
    upgraded = upgraded
        .replaceAll('/default.jpg', '/maxresdefault.jpg')
        .replaceAll('/mqdefault.jpg', '/maxresdefault.jpg')
        .replaceAll('/hqdefault.jpg', '/maxresdefault.jpg')
        .replaceAll('/sddefault.jpg', '/maxresdefault.jpg');
  }

  return upgraded;
}

MediaItem mapToMediaItem(Map song) {
  final ytid = song['ytid']?.toString();
  final offlineSong = ytid != null
      ? getOfflineSongByYtid(ytid)
      : <String, dynamic>{};
  // Fully downloaded tracks always present as offline — overrides any
  // in-flight online source preference on the song map.
  final isOffline =
      hasPlayableOfflineFile(ytid) || song['isOffline'] == true;
  final downloadSource =
      song['downloadSource'] ?? offlineSong['downloadSource'];

  final rawImageUrl = song['highResImage']?.toString() ??
      song['image']?.toString() ??
      song['lowResImage']?.toString() ??
      song['thumbnail']?.toString() ??
      song['artwork']?.toString() ??
      (ytid != null && ytid.isNotEmpty
          ? 'https://i.ytimg.com/vi/$ytid/maxresdefault.jpg'
          : null);

  final highQualityImageUrl = rawImageUrl != null
      ? upgradeArtworkUrl(rawImageUrl)
      : null;

  final artUri = isOffline && offlineSong['artworkPath'] != null
      ? Uri.file(offlineSong['artworkPath'].toString())
      : (highQualityImageUrl != null &&
              highQualityImageUrl.isNotEmpty &&
              highQualityImageUrl != 'null'
          ? Uri.parse(highQualityImageUrl)
          : Uri.parse('https://i.ytimg.com/vi/${ytid ?? ''}/maxresdefault.jpg'));
  // ytid is the canonical track identity shared by YouTube and JioSaavn.
  // Provider URLs, source labels, and queue-entry ids must never change it.
  final stableId = (ytid == null || ytid.isEmpty)
      ? song['id'].toString()
      : ytid;

  final albumRaw = song['album']?.toString();
  final album = (albumRaw == null || albumRaw.isEmpty || albumRaw == 'null')
      ? null
      : albumRaw;
  final artworkFilePath =
      (isOffline ? offlineSong['artworkPath'] : song['artworkPath'])
          ?.toString() ??
      song['artWorkPath']?.toString() ??
      '';

  return MediaItem(
    id: stableId,
    artist: song['artist']?.toString().trim(),
    album: album,
    title: song['title'].toString(),
    artUri: artUri,
    duration: _songDuration(song['duration']),
    extras: {
      'lowResImage': song['lowResImage'],
      'ytid': song['ytid'],
      'artistId': song['artistId'],
      'videoAuthor': song['videoAuthor'],
      'isLive': song['isLive'],
      'isOffline': isOffline,
      'downloadSource': downloadSource,
      'highResImage': song['highResImage'],
      'artWorkPath': artworkFilePath,
      'artworkPath': artworkFilePath,
      'resolvedSource': song['resolvedSource'],
      'resolvedBitrate': song['resolvedBitrate'],
      'resolvedFormat': song['resolvedFormat'],
      'catalogDurationSeconds': _songDuration(song['duration'])?.inSeconds,
    },
  );
}

Duration? _songDuration(dynamic value) {
  if (value == null) return null;
  if (value is Duration) return value;
  if (value is int) return Duration(seconds: value);
  final parsed = int.tryParse(value.toString());
  if (parsed == null) return null;
  return Duration(seconds: parsed);
}

/// Compares two Duration objects with tolerance for minor differences.
///
/// This prevents unnecessary updates when duration values have minor variations
/// (e.g., due to buffering or precision differences).
bool durationEquals(Duration? prev, Duration? curr) {
  if (prev == curr) return true;
  if (prev == null || curr == null) return prev == curr;

  // Consider durations equal if they differ by less than 1 second
  return (prev - curr).abs() < const Duration(seconds: 1);
}
