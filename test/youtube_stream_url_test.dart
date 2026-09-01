import 'package:flutter_test/flutter_test.dart';
import 'package:musified/utilities/app_utils.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  test('ANDROID client streams can have empty URLs without deciphering', () async {
    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.streams.getManifest(
        'AMfuIWDUDHg',
        ytClients: [YoutubeApiClient.android],
      );
      final first = manifest.audioOnly.sortByBitrate().first;
      expect(isPlayableYoutubeStreamUrl(first.url), isFalse);
    } finally {
      yt.close();
    }
  });
}
