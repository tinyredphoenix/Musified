import 'package:audio_service/audio_service.dart';
import 'package:musified/services/common_services.dart';
import 'package:musified/utilities/app_utils.dart';

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

bool _isSquareArtworkCdn(String url) {
  return url.contains('googleusercontent.com') ||
      url.contains('ggpht.com') ||
      url.contains('saavncdn.com');
}

String? _nonEmptyUrl(dynamic value) {
  final url = value?.toString();
  if (url == null || url.isEmpty || url == 'null') return null;
  return url;
}

/// Square-friendly artwork URL for lock-screen / in-app art.
/// Prefers googleusercontent, ggpht, and saavncdn over 16:9 ytimg maxres.
String? resolveMediaArtworkUrl(Map song, {String? ytid}) {
  final candidates = <String>[
    for (final key in [
      'highResImage',
      'image',
      'lowResImage',
      'thumbnail',
      'artwork',
    ])
      if (_nonEmptyUrl(song[key]) != null) _nonEmptyUrl(song[key])!,
  ];

  String? chosen;
  for (final url in candidates) {
    if (_isSquareArtworkCdn(url)) {
      chosen = url;
      break;
    }
  }
  chosen ??= candidates.isNotEmpty ? candidates.first : null;

  if (chosen != null) return upgradeArtworkUrl(chosen);
  if (ytid != null && ytid.isNotEmpty) {
    return 'https://i.ytimg.com/vi/$ytid/hqdefault.jpg';
  }
  return null;
}

String upgradeArtworkUrl(String url, {int targetSize = 800}) {
  if (url.isEmpty || url == 'null') return url;

  var upgraded = url;
  // 1. Google / YouTube Music CDN URLs with sizing parameters (=w120-h120, =s120, etc.)
  if (upgraded.contains('googleusercontent.com') ||
      upgraded.contains('ggpht.com')) {
    upgraded = upgraded
        .replaceAll(
          RegExp(r'=w\d+-h\d+(?:-[a-zA-Z0-9]+)*'),
          '=w$targetSize-h$targetSize-l90-rj',
        )
        .replaceAll(RegExp(r'=s\d+(?:-[a-zA-Z0-9]+)*'), '=s$targetSize');
  }

  // 2. JioSaavn CDN artwork (e.g. 50x50.jpg, 150x150.jpg -> 500x500.jpg)
  if (upgraded.contains('saavncdn.com')) {
    upgraded = upgraded
        .replaceAll('50x50.jpg', '500x500.jpg')
        .replaceAll('150x150.jpg', '500x500.jpg');
  }

  // 3. YouTube standard thumbnails: always prefer maxresdefault (1280×720 16:9).
  // This avoids baked-in black letterboxing from hqdefault (4:3).
  if (upgraded.contains('ytimg.com/vi/') ||
      upgraded.contains('youtube.com/vi/')) {
    upgraded = upgraded.replaceAllMapped(
      RegExp(
        r'/(default|mqdefault|hqdefault|sddefault|hq720)\.(jpg|webp|jpeg)',
      ),
      (match) => '/maxresdefault.${match[2]}',
    );
  }

  return upgraded;
}

MediaItem mapToMediaItem(Map song) {
  final ytid = song['ytid']?.toString();
  final offlineSong = ytid != null
      ? getOfflineSongByYtid(ytid)
      : <String, dynamic>{};
  // The active playback decision wins over disk presence. Once a track has
  // been resolved to a streaming provider (via source switch), it must not
  // keep presenting as "offline" just because a download exists on disk.
  final resolvedSource = song['resolvedSource']?.toString();
  final bool isOffline;
  if (resolvedSource == 'youtube' || resolvedSource == 'jiosaavn') {
    isOffline = false;
  } else if (resolvedSource == 'offline') {
    isOffline = true;
  } else {
    isOffline = hasPlayableOfflineFile(ytid) || song['isOffline'] == true;
  }
  final downloadSource =
      song['downloadSource'] ?? offlineSong['downloadSource'];

  final highQualityImageUrl = resolveMediaArtworkUrl(song, ytid: ytid);

  final artUri = isOffline && offlineSong['artworkPath'] != null
      ? Uri.file(offlineSong['artworkPath'].toString())
      : (highQualityImageUrl != null &&
              highQualityImageUrl.isNotEmpty &&
              highQualityImageUrl != 'null'
          ? Uri.parse(highQualityImageUrl)
          : Uri.parse('https://i.ytimg.com/vi/${ytid ?? ''}/hqdefault.jpg'));
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
    duration: parseSongDuration(song['duration']),
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
      'catalogDurationSeconds': parseSongDuration(song['duration'])?.inSeconds,
    },
  );
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
