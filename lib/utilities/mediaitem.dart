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
    'highResImage': extras?['highResImage'] ??
        extras?['image'] ??
        mediaItem.artUri?.toString(),
    'image': extras?['image'] ??
        extras?['highResImage'] ??
        mediaItem.artUri?.toString(),
    'lowResImage': extras?['lowResImage'],
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
/// Prefers googleusercontent, ggpht, and saavncdn over 16:9 ytimg thumbs.
String? resolveMediaArtworkUrl(
  Map song, {
  String? ytid,
  int targetSize = 400,
}) {
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

  final resolvedSource = song['resolvedSource']?.toString();
  final catalogYoutube =
      resolvedSource == 'youtube' || song['catalogOrigin']?.toString() == 'youtube';
  if (catalogYoutube && ytid != null && ytid.isNotEmpty) {
    final square = chosen != null && _isSquareArtworkCdn(chosen);
    if (!square) {
      return 'https://i.ytimg.com/vi/$ytid/hqdefault.jpg';
    }
  }

  if (chosen != null) {
    return upgradeArtworkUrl(chosen, targetSize: targetSize);
  }
  if (ytid != null && ytid.isNotEmpty) {
    return 'https://i.ytimg.com/vi/$ytid/hqdefault.jpg';
  }
  return null;
}

String upgradeArtworkUrl(String url, {int targetSize = 400}) {
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

  // 2. JioSaavn CDN artwork — 500x500 is reliably square on the CDN.
  if (upgraded.contains('saavncdn.com')) {
    upgraded = upgraded
        .replaceAll('50x50.jpg', '500x500.jpg')
        .replaceAll('150x150.jpg', '500x500.jpg')
        .replaceAll('500x500.jpg', '500x500.jpg')
        .replaceAll('1500x1500.jpg', '500x500.jpg');
  }

  // 3. YouTube ytimg: keep hqdefault (4:3) for square lock-screen crops.
  // maxresdefault is 16:9 and letterboxes badly on iOS Now Playing art.
  if (upgraded.contains('ytimg.com/vi/') ||
      upgraded.contains('youtube.com/vi/')) {
    upgraded = upgraded.replaceAllMapped(
      RegExp(
        r'/(default|mqdefault|sddefault|hq720|maxresdefault)\.(jpg|webp|jpeg)',
      ),
      (match) => '/hqdefault.${match[2]}',
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

  final artworkUrl = resolveMediaArtworkUrl(song, ytid: ytid);

  final artUri = isOffline && offlineSong['artworkPath'] != null
      ? Uri.file(offlineSong['artworkPath'].toString())
      : (artworkUrl != null &&
              artworkUrl.isNotEmpty &&
              artworkUrl != 'null'
          ? Uri.parse(artworkUrl)
          : (ytid != null && ytid.isNotEmpty
              ? Uri.parse('https://i.ytimg.com/vi/$ytid/hqdefault.jpg')
              : null));
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
      'highResImage': artworkUrl ?? song['highResImage'] ?? song['image'],
      'artWorkPath': artworkFilePath,
      'artworkPath': artworkFilePath,
      'image': artworkUrl ?? song['image'] ?? song['highResImage'],
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
