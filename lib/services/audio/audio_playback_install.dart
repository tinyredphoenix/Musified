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
      final tag = mapToMediaItem(song);

      if (isOffline) {
        final file = File(songUrl);
        final bytes = await file.exists() ? await file.length() : 0;
        logger.log(
          'Building file source',
          data: {'path': songUrl, 'bytes': bytes, 'title': song['title']},
        );
        final fileSource = AudioSource.uri(Uri.file(songUrl), tag: tag);
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
            tag: tag,
          );
        }
        return fileSource;
      }

      final uri = Uri.parse(songUrl);
      Map<String, String>? headers;
      if (uri.host.contains('googlevideo.com') ||
          uri.host.contains('youtube.com')) {
        headers = {
          'User-Agent':
              song['resolvedUserAgent']?.toString() ??
              'com.google.ios.youtube/21.26.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)',
        };
      } else if (uri.host.contains('saavncdn.com')) {
        headers = {
          'User-Agent':
              'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko)',
          'Accept': '*/*',
        };
      }

      final uriSource = AudioSource.uri(uri, headers: headers, tag: tag);
      final isYoutube =
          song['resolvedSource'] == 'youtube' ||
          uri.host.contains('googlevideo.com') ||
          uri.host.contains('youtube.com');
      final catalogDuration = parseSongDuration(song['duration']);
      if (isYoutube &&
          catalogDuration != null &&
          catalogDuration > const Duration(seconds: 5) &&
          _needsDurationClip(song)) {
        logger.log(
          'Clipping HE-AAC YouTube "${song['title']}" to ${catalogDuration.inSeconds}s',
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

  static bool _needsDurationClip(Map song) {
    if (isHeAacFormatLabel(song['resolvedFormat']?.toString())) {
      return true;
    }
    final itag = song['resolvedItag'];
    if (itag is int && kHeAacItags.contains(itag)) return true;
    final parsed = int.tryParse(itag?.toString() ?? '');
    return parsed != null && kHeAacItags.contains(parsed);
  }
}
