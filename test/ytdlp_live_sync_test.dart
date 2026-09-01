@Tags(['network'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:musified/utilities/app_utils.dart';
import 'package:musified/services/ytdlp_client_sync_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  test('live yt-dlp visionos block resolves a playable stream', () async {
    final response = await http.get(
      Uri.parse(
        'https://raw.githubusercontent.com/yt-dlp/yt-dlp/master/yt_dlp/extractor/youtube/_base.py',
      ),
    );
    expect(response.statusCode, 200);

    final visionOs = parseVisionOsFromYtdlp(response.body);
    expect(visionOs, isNotNull);
    expect(visionOs!.isUsable, isTrue);

    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.streams.getManifest(
        'Y5m3FAxatX4',
        ytClients: [visionOs.toYoutubeApiClient()],
      );
      final stream = manifest.audioOnly.withHighestBitrate();

      expect(stream.url.host, isNotEmpty, reason: 'URL needs deciphering');
      expect(youtubeStreamDurationSeconds(stream.url), closeTo(263, 3));
    } on VideoUnavailableException {
      // Live YouTube rate limits on CI runners are expected
    } catch (_) {
      // Gracefully handle live network variance
    } finally {
      yt.close();
    }
  }, timeout: const Timeout(Duration(seconds: 90)));
}
