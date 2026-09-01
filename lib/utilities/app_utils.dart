import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:musified/constants/app_constants.dart';
import 'package:musified/services/settings_manager.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

BorderRadius getItemBorderRadius(
  int index,
  int totalLength, {
  bool hasItemsBefore = false,
  bool hasItemsAfter = false,
}) {
  // Determine if this item is the absolute top or absolute bottom of the visual block
  final isAbsoluteFirst = index == 0 && !hasItemsBefore;
  final isAbsoluteLast = index == totalLength - 1 && !hasItemsAfter;

  if (isAbsoluteFirst && isAbsoluteLast) {
    return commonCustomBarRadius; // Single item in the entire block
  } else if (isAbsoluteFirst) {
    return commonCustomBarRadiusFirst; // Top of the block
  } else if (isAbsoluteLast) {
    return commonCustomBarRadiusLast; // Bottom of the block
  }
  return BorderRadius.zero; // Default for middle items
}

ValueKey<int> listItemKey(String scope, int index, [Object? item]) {
  return ValueKey<int>(Object.hash(scope, index, item));
}

/// Reads a stored/decoded `List` of maps back into typed maps, dropping any
/// entry that is not a map. Returns an empty list for anything else.
List<Map<String, dynamic>> asMapList(dynamic value) {
  if (value is! List) return const [];
  return value.whereType<Map>().map(Map<String, dynamic>.from).toList();
}

/// Validates if a URL is a YouTube playlist URL
bool isYoutubePlaylistUrl(String url) {
  return _youtubePlaylistRegExp.hasMatch(url);
}

/// Extracts the playlist ID from a YouTube playlist URL
String? extractYoutubePlaylistId(String url) {
  if (!isYoutubePlaylistUrl(url)) {
    return null;
  }

  final match = _youtubePlaylistIdRegExp.firstMatch(url);
  return match?.group(1);
}

double getResponsiveTitleFontSize(Size size) {
  final isDesktop = size.width > 800;
  final isLandscape = size.width > size.height;
  if (isDesktop || isLandscape) return 20;
  if (size.width < 360) return 20;
  if (size.width < 400) return 22;
  return size.height * 0.028;
}

double getResponsiveArtistFontSize(Size size) {
  final isDesktop = size.width > 800;
  final isLandscape = size.width > size.height;
  if (isDesktop || isLandscape) return 14;
  if (size.width < 360) return 14;
  if (size.width < 400) return 15;
  return size.height * 0.018;
}

final RegExp _youtubePlaylistRegExp = RegExp(
  r'^(https?:\/\/)?(www\.|m\.|music\.)?(youtube\.com|youtu\.be)\/.*(list=([a-zA-Z0-9_-]+)).*$',
);

final RegExp _youtubePlaylistIdRegExp = RegExp('[&?]list=([a-zA-Z0-9_-]+)');

bool isSponsorshipAnnouncementUrl(String url) {
  final host = Uri.tryParse(url)?.host.toLowerCase();
  return host != null && (host == 'ko-fi.com' || host.endsWith('.ko-fi.com'));
}

/// Formats a [monthKey] (e.g. "2026-06") into a locale-aware month label
/// such as "June 2026". Falls back to [monthKey] if parsing fails.
String formatMonthPeriodLabel(Locale locale, String monthKey) {
  final parts = monthKey.split('-');
  if (parts.length != 2) return monthKey;

  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null) return monthKey;

  final label = DateFormat.yMMMM(locale.toString()).format(
    DateTime(year, month),
  );
  return label.isEmpty
      ? monthKey
      : '${label[0].toUpperCase()}${label.substring(1)}';
}

/// YouTube HE-AAC itags. iOS CoreAudio/AVPlayer reports these as ~2× duration.
const Set<int> kHeAacItags = {139, 599, 600};

bool isHeAacStream(AudioOnlyStreamInfo stream) {
  if (kHeAacItags.contains(stream.tag)) return true;
  return isHeAacFormatLabel('${stream.codec} ${stream.audioCodec}');
}

bool isHeAacFormatLabel(String? format) {
  if (format == null || format.isEmpty) return false;
  final f = format.toLowerCase();
  return f.contains('mp4a.40.5') ||
      f.contains('he-aac') ||
      f.contains('heaac') ||
      f.contains('sbr');
}

/// Parses catalog duration from song maps. YouTube/Innertube values may be
/// seconds, milliseconds, or a clock string (`3:24` / `1:02:03`).
Duration? parseSongDuration(dynamic value) {
  if (value == null) return null;
  if (value is Duration) {
    return value > Duration.zero ? value : null;
  }
  if (value is num) {
    return _durationFromNumber(value.toInt());
  }
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  if (text.contains(':')) {
    final parts = text.split(':');
    if (parts.length < 2 || parts.length > 3) return null;
    final nums = parts.map(int.tryParse).toList();
    if (nums.any((n) => n == null)) return null;
    final ints = nums.cast<int>();
    final seconds = ints.length == 2
        ? ints[0] * 60 + ints[1]
        : ints[0] * 3600 + ints[1] * 60 + ints[2];
    return seconds > 0 ? Duration(seconds: seconds) : null;
  }
  final parsed = int.tryParse(text);
  if (parsed == null) return null;
  return _durationFromNumber(parsed);
}

Duration? _durationFromNumber(int n) {
  if (n <= 0) return null;
  // Values larger than 24h-as-seconds are almost always milliseconds
  // (e.g. a 3:00 track stored as 180000).
  if (n > 86400) return Duration(milliseconds: n);
  return Duration(seconds: n);
}

/// YouTube CDN URL must be absolute https with a host (not cipher-only stubs).
bool isPlayableYoutubeStreamUrl(Uri url) {
  if (url.toString().isEmpty) return false;
  final scheme = url.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return false;
  return url.host.isNotEmpty;
}

/// googlevideo URLs carry track length as `dur` (seconds, may be fractional).
int? youtubeStreamDurationSeconds(Uri url) {
  final raw = url.queryParameters['dur'];
  if (raw == null) return null;
  final seconds = double.tryParse(raw);
  if (seconds == null || seconds <= 0) return null;
  return seconds.round();
}

/// YouTube video IDs are 11 chars; reject path traversal for file storage keys.
final RegExp _youtubeVideoIdPattern = RegExp(r'^[a-zA-Z0-9_-]{11}$');

String sanitizeStorageSongId(String songId) {
  final trimmed = songId.trim();
  if (_youtubeVideoIdPattern.hasMatch(trimmed)) return trimmed;
  final stripped = trimmed.replaceAll(RegExp(r'[^\w-]'), '_');
  if (stripped.isEmpty) return 'invalid';
  return stripped.length > 64 ? stripped.substring(0, 64) : stripped;
}

bool isValidYoutubeVideoId(String? id) {
  if (id == null) return false;
  return _youtubeVideoIdPattern.hasMatch(id.trim());
}

/// YouTube CDN hosts only — not JioSaavn or other HTTPS streams.
bool isYoutubeCdnHost(String host) {
  final lower = host.toLowerCase();
  return lower.contains('googlevideo.com') ||
      lower.contains('youtube.com') ||
      lower.contains('ytimg.com');
}

bool isJiosaavnStreamHost(String host) {
  return host.toLowerCase().contains('saavncdn.com');
}

/// Signed googlevideo URLs expire; stale preloads cause iOS -1004 on load.
bool isYoutubeStreamUrlExpired(
  Uri url, {
  Duration grace = const Duration(seconds: 45),
}) {
  final expireRaw = url.queryParameters['expire'];
  if (expireRaw == null) return false;
  final expireSec = int.tryParse(expireRaw);
  if (expireSec == null) return false;
  final expiry = DateTime.fromMillisecondsSinceEpoch(expireSec * 1000);
  return DateTime.now().isAfter(expiry.subtract(grace));
}

bool isUsableYoutubePlaybackUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !isPlayableYoutubeStreamUrl(uri)) return false;
  if (!isYoutubeCdnHost(uri.host)) return false;
  if (isYoutubeStreamUrlExpired(uri)) return false;
  return true;
}

bool isUsableJiosaavnPlaybackUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !isPlayableYoutubeStreamUrl(uri)) return false;
  return isJiosaavnStreamHost(uri.host);
}

/// Which streaming provider this song should play from right now.
String preferredStreamSourceForSong(Map song) {
  final force = song['forceSource']?.toString();
  if (force == 'youtube') return 'youtube';
  if (force == 'jiosaavn' || force == 'saavn') return 'jiosaavn';
  final resolved = song['resolvedSource']?.toString();
  if (resolved == 'youtube' || resolved == 'jiosaavn') return resolved!;
  return songShouldResolveYoutube(song) ? 'youtube' : 'jiosaavn';
}

bool streamUrlMatchesPreferredSource(String url, Map song) {
  final preferred = preferredStreamSourceForSong(song);
  if (preferred == 'youtube') return isUsableYoutubePlaybackUrl(url);
  if (preferred == 'jiosaavn') return isUsableJiosaavnPlaybackUrl(url);
  return false;
}

/// Prefer YouTube over JioSaavn when the catalog entry is from YouTube.
/// Explicit [forceSource] always wins over catalog metadata.
bool songShouldResolveYoutube(Map song) {
  final force = song['forceSource']?.toString();
  if (force == 'youtube') return true;
  if (force == 'jiosaavn' || force == 'saavn') return false;
  if (song['catalogOrigin']?.toString() == 'youtube') return true;
  if (song['resolvedSource']?.toString() == 'youtube') return true;
  final pref = force ?? preferredSource.value;
  return pref == 'youtube';
}

AudioOnlyStreamInfo selectAudioOnlyStreamForQuality(
  List<AudioOnlyStreamInfo> availableSources,
) {
  // CRITICAL FOR IOS: Apple AVPlayer does not support WebM (AVError -11828).
  // Never select HE-AAC (mp4a.40.5 / itags 139, 599, 600): CoreAudio reports
  // ~2× duration, so the next queue item starts at the real EOF with no
  // artwork/title change, or the remaining half plays silence.
  bool isMp4Family(AudioOnlyStreamInfo stream) {
    final codec = stream.codec.toString().toLowerCase();
    final container = stream.container.name.toLowerCase();
    if (_isDolbyCodec(codec)) return false;
    if (container.contains('webm') || container.contains('opus')) return false;
    if (codec.contains('opus') && !codec.contains('mp4a')) return false;
    return (container == 'm4a' || container == 'mp4' || container == 'aac') ||
        (codec.contains('mp4a') || codec.contains('aac'));
  }

  final aacLcSources = availableSources
      .where(
        (stream) =>
            isPlayableYoutubeStreamUrl(stream.url) &&
            isMp4Family(stream) &&
            !isHeAacStream(stream),
      )
      .toList();

  // Last resort only: HE-AAC is playable but MUST be clipped to catalog
  // duration by the player. Never fall through to WebM on iOS.
  final heAacFallback = availableSources
      .where(
        (stream) =>
            isPlayableYoutubeStreamUrl(stream.url) &&
            isMp4Family(stream) &&
            isHeAacStream(stream),
      )
      .toList();

  final anyPlayable = availableSources
      .where((stream) => isPlayableYoutubeStreamUrl(stream.url))
      .toList();

  final selectionPool = aacLcSources.isNotEmpty
      ? aacLcSources
      : (heAacFallback.isNotEmpty
          ? heAacFallback
          : anyPlayable);
  final sortedPool = selectionPool.sortByBitrate();
  if (sortedPool.isEmpty) {
    return availableSources.first;
  }

  final qualitySetting = audioQualitySetting.value;

  // sortByBitrate() is descending (highest first). Low quality must use the
  // cheapest playable AAC stream, not the top of that list.
  if (qualitySetting == 'low') {
    return sortedPool.last;
  } else if (qualitySetting == 'medium') {
    return sortedPool[sortedPool.length ~/ 2];
  }

  return sortedPool.withHighestBitrate();
}

bool _isDolbyCodec(String codec) {
  return codec.contains('ec-3') ||
      codec.contains('ac-3') ||
      codec.contains('eac3') ||
      codec.contains('dolby');
}
