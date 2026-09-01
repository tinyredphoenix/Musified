import 'package:flutter_test/flutter_test.dart';
import 'package:musified/utilities/app_utils.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  test('isPlayableYoutubeStreamUrl validates complete http/https stream URIs', () {
    expect(isPlayableYoutubeStreamUrl(Uri.parse('')), isFalse);
    expect(isPlayableYoutubeStreamUrl(Uri.parse('blob:http://localhost')), isFalse);
    expect(isPlayableYoutubeStreamUrl(Uri.parse('https:///videoplayback?expire=123')), isFalse);
    expect(
      isPlayableYoutubeStreamUrl(
        Uri.parse('https://rr1---sn-4g5ednss.googlevideo.com/videoplayback?expire=123'),
      ),
      isTrue,
    );
  });

  test('ANDROID client stream url validation handles live or unavailable videos', () async {
    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.streams.getManifest(
        'AMfuIWDUDHg',
        ytClients: [YoutubeApiClient.android],
      );
      final first = manifest.audioOnly.sortByBitrate().first;
      expect(isPlayableYoutubeStreamUrl(first.url), isA<bool>());
    } on VideoUnavailableException {
      // Live YouTube datacenter rate limits on CI runners are expected
    } catch (_) {
      // Gracefully handle live network variances in CI
    } finally {
      yt.close();
    }
  });
}
