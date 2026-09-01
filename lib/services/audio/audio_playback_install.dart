import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:musified/main.dart';
import 'package:musified/services/common_services.dart';
import 'package:musified/utilities/app_utils.dart';
import 'package:musified/utilities/mediaitem.dart';

/// Builds [AudioSource] for just_audio. No queue/preload dependencies.
class AudioPlaybackInstall {
  static Future<AudioSource?> buildSource(
    Map song,
    String songUrl,
    bool isOffline,
  ) async {
    try {
      if (isOffline) {
        final file = File(songUrl);
        if (!await file.exists()) {
          logger.log('Offline file missing for ${song['ytid']}');
          return null;
        }
        final bytes = await file.length();
        logger.log(
          'Building file source',
          data: {'path': songUrl, 'bytes': bytes, 'title': song['title']},
        );
        final fileSource = AudioSource.uri(Uri.file(songUrl), tag: mapToMediaItem(song));
        final catalogDuration = parseSongDuration(song['duration']);
        final codec = song['audioCodec']?.toString() ??
            getOfflineSongByYtid(song['ytid']?.toString() ?? '')['audioCodec']
                ?.toString();
        if (catalogDuration != null &&
            catalogDuration > const Duration(seconds: 5) &&
            isHeAacFormatLabel(codec)) {
          logger.log(
            'Clipping offline HE-AAC "${song['title']}" to ${catalogDuration.inSeconds}s',
          );
          return ClippingAudioSource(
            child: fileSource,
            end: catalogDuration,
            tag: mapToMediaItem(song),
          );
        }
        return fileSource;
      }

      final playbackUri = Uri.parse(songUrl);
      final catalogUri = _resolveStreamUri(playbackUri);
      final isYoutube =
          song['resolvedSource'] == 'youtube' ||
          catalogUri.host.contains('googlevideo.com') ||
          catalogUri.host.contains('youtube.com');

      // Trust the stream URL's dur= before anything async — stops iOS from
      // reporting ~2× length for visionos AAC-LC (itag 140).
      if (isYoutube) {
        final urlDur = youtubeStreamDurationSeconds(catalogUri);
        if (urlDur != null) {
          song['duration'] = urlDur;
        }
      }

      final tag = mapToMediaItem(song);

      Map<String, String>? headers;
      if (catalogUri.host.contains('googlevideo.com') ||
          catalogUri.host.contains('youtube.com')) {
        headers = {
          'User-Agent':
              song['resolvedUserAgent']?.toString() ??
              'com.google.ios.youtube/21.26.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)',
        };
      } else if (playbackUri.host.contains('saavncdn.com')) {
        headers = {
          'User-Agent':
              'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko)',
          'Accept': '*/*',
        };
      }

      final uriSource = AudioSource.uri(playbackUri, headers: headers, tag: tag);
      final catalogDuration = parseSongDuration(song['duration']);

      if (isYoutube &&
          catalogDuration != null &&
          catalogDuration > const Duration(seconds: 5)) {
        logger.log(
          'Clipping YouTube "${song['title']}" to ${catalogDuration.inSeconds}s '
          '(itag=${song['resolvedItag'] ?? '-'} codec=${song['resolvedFormat'] ?? '-'})',
        );
        return ClippingAudioSource(
          child: uriSource,
          end: catalogDuration,
          tag: tag,
        );
      }
      return uriSource;
    } catch (e, stackTrace) {
      logger.log(
        'Error building audio source',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  static Uri _resolveStreamUri(Uri uri) {
    if (uri.host.contains('googlevideo.com') ||
        uri.host.contains('youtube.com')) {
      return uri;
    }
    final embedded = uri.queryParameters['url'];
    if (embedded != null) {
      final inner = Uri.tryParse(embedded);
      if (inner != null &&
          (inner.host.contains('googlevideo.com') ||
              inner.host.contains('youtube.com'))) {
        return inner;
      }
    }
    return uri;
  }
}
