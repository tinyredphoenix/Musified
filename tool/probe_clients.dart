// Standalone diagnostic: run every InnerTube client exactly the way the app
// resolves a stream, then verify the resulting URL actually plays.
//
//   dart run tool/probe_clients.dart [videoId ...]
//
// For each client it reports: manifest success, the stream the app would pick,
// whether the CDN accepts the URL, and the duration the MP4 header declares
// (which is what the platform player trusts).

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

const _defaultVideoIds = ['Y5m3FAxatX4', 'AMfuIWDUDHg'];

final _clients = <String, YoutubeApiClient>{
  'android_vr': YoutubeApiClient.androidVr,
  'visionos': YoutubeApiClient.visionOs,
  'ios': YoutubeApiClient.ios,
  'android': YoutubeApiClient.android,
  'mweb': YoutubeApiClient.mweb,
  'web_safari': YoutubeApiClient.safari,
  'tv': YoutubeApiClient.tv,
  'tv_downgraded': YoutubeApiClient.tvDowngraded,
  'media_connect': YoutubeApiClient.mediaConnect,
};

const _heAacItags = {139, 599, 600};

Future<void> main(List<String> args) async {
  final videoIds = args.isEmpty ? _defaultVideoIds : args;

  for (final videoId in videoIds) {
    stdout.writeln('\n${'=' * 78}');
    stdout.writeln('VIDEO $videoId');
    stdout.writeln('=' * 78);

    final catalogSeconds = await _catalogDuration(videoId);
    stdout.writeln('catalog duration: ${catalogSeconds ?? "unknown"}s\n');

    for (final entry in _clients.entries) {
      await _probeClient(entry.key, entry.value, videoId, catalogSeconds);
    }
  }
  exit(0);
}

Future<int?> _catalogDuration(String videoId) async {
  final yt = YoutubeExplode();
  try {
    final video = await yt.videos.get(videoId).timeout(
          const Duration(seconds: 15),
        );
    return video.duration?.inSeconds;
  } catch (e) {
    stdout.writeln('catalog lookup failed: $e');
    return null;
  } finally {
    yt.close();
  }
}

Future<void> _probeClient(
  String id,
  YoutubeApiClient client,
  String videoId,
  int? catalogSeconds,
) async {
  final label = id.padRight(14);
  final yt = YoutubeExplode();
  final watch = Stopwatch()..start();

  try {
    final manifest = await yt.videos.streams
        .getManifest(videoId, ytClients: [client])
        .timeout(const Duration(seconds: 30));
    watch.stop();

    final audio = manifest.audioOnly.toList();
    if (audio.isEmpty) {
      stdout.writeln('$label MANIFEST OK but 0 audio streams  (${watch.elapsedMilliseconds}ms)');
      return;
    }

    final picked = _pickLikeApp(audio);
    if (picked == null) {
      stdout.writeln('$label MANIFEST OK, ${audio.length} streams, none playable (empty URLs)  (${watch.elapsedMilliseconds}ms)');
      return;
    }

    final urlDur = double.tryParse(picked.url.queryParameters['dur'] ?? '');
    final userAgent = _userAgent(client);
    final cdn = await _checkCdn(picked.url, userAgent);
    final headerDur = cdn.ok ? await _mp4DurationSeconds(picked.url, userAgent) : null;

    final buffer = StringBuffer()
      ..write('$label OK  ')
      ..write('${watch.elapsedMilliseconds}ms  ')
      ..write('itag=${picked.tag} ')
      ..write('codec=${picked.audioCodec} ')
      ..write('${picked.bitrate.kiloBitsPerSecond.round()}kbps  ')
      ..write('cdn=${cdn.status}  ')
      ..write('urlDur=${urlDur?.round() ?? "-"}s  ')
      ..write('mp4Dur=${headerDur?.round() ?? "-"}s');

    if (catalogSeconds != null && headerDur != null) {
      final ratio = headerDur / catalogSeconds;
      if (ratio > 1.7 && ratio < 2.3) buffer.write('  <-- DOUBLED');
    }
    stdout.writeln(buffer);

    final playable = audio.where((s) => s.url.host.isNotEmpty).length;
    stdout.writeln('${' ' * 15}streams=${audio.length} playableUrls=$playable '
        'itags=${audio.map((s) => s.tag).join(",")}');
  } on TimeoutException {
    watch.stop();
    stdout.writeln('$label TIMEOUT after ${watch.elapsedMilliseconds}ms');
  } catch (e) {
    watch.stop();
    final message = e.toString().split('\n').first;
    stdout.writeln('$label FAIL  ${watch.elapsedMilliseconds}ms  $message');
  } finally {
    yt.close();
  }
}

/// Mirrors selectAudioOnlyStreamForQuality at the 'high' quality setting.
AudioOnlyStreamInfo? _pickLikeApp(List<AudioOnlyStreamInfo> sources) {
  bool playable(AudioOnlyStreamInfo s) =>
      s.url.toString().isNotEmpty && s.url.host.isNotEmpty;

  bool mp4Family(AudioOnlyStreamInfo s) {
    final codec = s.codec.toString().toLowerCase();
    final container = s.container.name.toLowerCase();
    if (codec.contains('ec-3') || codec.contains('ac-3')) return false;
    if (container.contains('webm') || container.contains('opus')) return false;
    if (codec.contains('opus') && !codec.contains('mp4a')) return false;
    return container == 'm4a' ||
        container == 'mp4' ||
        container == 'aac' ||
        codec.contains('mp4a') ||
        codec.contains('aac');
  }

  bool heAac(AudioOnlyStreamInfo s) =>
      _heAacItags.contains(s.tag) ||
      s.audioCodec.toLowerCase().contains('mp4a.40.5');

  final aacLc = sources.where((s) => playable(s) && mp4Family(s) && !heAac(s));
  if (aacLc.isNotEmpty) return aacLc.toList().withHighestBitrate();

  final heaac = sources.where((s) => playable(s) && mp4Family(s) && heAac(s));
  if (heaac.isNotEmpty) return heaac.toList().withHighestBitrate();

  final any = sources.where(playable);
  return any.isEmpty ? null : any.toList().withHighestBitrate();
}

String? _userAgent(YoutubeApiClient client) {
  final ctx = client.payload['context']?['client'];
  return ctx is Map ? ctx['userAgent']?.toString() : null;
}

Future<({bool ok, String status})> _checkCdn(Uri url, String? userAgent) async {
  try {
    final response = await http.get(
      url,
      headers: {
        if (userAgent != null) 'User-Agent': userAgent,
        'Range': 'bytes=0-1',
      },
    ).timeout(const Duration(seconds: 15));
    final ok = response.statusCode == 200 || response.statusCode == 206;
    return (ok: ok, status: '${response.statusCode}');
  } catch (e) {
    return (ok: false, status: 'ERR');
  }
}

/// Reads `mvhd` (movie header) and every `mdhd` (track header). Players trust
/// the track header, so a mismatch between the two is what doubles durations.
Future<double?> _mp4DurationSeconds(Uri url, String? userAgent) async {
  final report = await _mp4HeaderReport(url, userAgent);
  if (report == null) return null;
  if (report.trackDurations.isNotEmpty) {
    stdout.writeln('${' ' * 15}mvhd=${report.movieDuration?.toStringAsFixed(1)}s '
        'mdhd=${report.trackDurations.map((t) => "${t.seconds.toStringAsFixed(1)}s@${t.timescale}Hz").join(", ")}');
  }
  return report.movieDuration;
}

typedef _TrackDuration = ({double seconds, int timescale});

Future<({double? movieDuration, List<_TrackDuration> trackDurations})?>
    _mp4HeaderReport(Uri url, String? userAgent) async {
  try {
    final response = await http.get(
      url,
      headers: {
        if (userAgent != null) 'User-Agent': userAgent,
        'Range': 'bytes=0-262143',
      },
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 && response.statusCode != 206) return null;

    final bytes = response.bodyBytes;
    final data = ByteData.sublistView(bytes);

    double? movieDuration;
    final mvhd = _indexOfAscii(bytes, 'mvhd', 0);
    if (mvhd >= 0) movieDuration = _readDuration(bytes, data, mvhd)?.seconds;

    final tracks = <_TrackDuration>[];
    var search = 0;
    while (true) {
      final mdhd = _indexOfAscii(bytes, 'mdhd', search);
      if (mdhd < 0) break;
      final parsed = _readDuration(bytes, data, mdhd);
      if (parsed != null) tracks.add(parsed);
      search = mdhd + 4;
    }

    return (movieDuration: movieDuration, trackDurations: tracks);
  } catch (_) {
    return null;
  }
}

_TrackDuration? _readDuration(Uint8List bytes, ByteData data, int boxNameIndex) {
  var offset = boxNameIndex + 4;
  if (offset >= bytes.length) return null;
  final version = bytes[offset];
  offset += 4; // version + flags

  int timescale;
  double duration;
  try {
    if (version == 1) {
      offset += 16; // creation + modification (64-bit each)
      timescale = data.getUint32(offset);
      offset += 4;
      duration = data.getUint64(offset).toDouble();
    } else {
      offset += 8; // creation + modification (32-bit each)
      timescale = data.getUint32(offset);
      offset += 4;
      duration = data.getUint32(offset).toDouble();
    }
  } catch (_) {
    return null;
  }
  if (timescale == 0) return null;
  return (seconds: duration / timescale, timescale: timescale);
}

int _indexOfAscii(Uint8List bytes, String needle, int from) {
  final pattern = ascii.encode(needle);
  outer:
  for (var i = from; i + pattern.length <= bytes.length; i++) {
    for (var j = 0; j < pattern.length; j++) {
      if (bytes[i + j] != pattern[j]) continue outer;
    }
    return i;
  }
  return -1;
}
