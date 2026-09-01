import 'package:flutter_test/flutter_test.dart';
import 'package:musified/utilities/app_utils.dart';

void main() {
  test('force jiosaavn overrides youtube catalog origin', () {
    final song = {
      'ytid': 'abc',
      'catalogOrigin': 'youtube',
      'forceSource': 'jiosaavn',
    };
    expect(songShouldResolveYoutube(song), false);
  });

  test('force youtube overrides jiosaavn preference', () {
    final song = {
      'ytid': 'abc',
      'catalogOrigin': 'youtube',
      'forceSource': 'youtube',
    };
    expect(songShouldResolveYoutube(song), true);
  });

  test('saavn URL is not treated as youtube playback URL', () {
    expect(
      isUsableYoutubePlaybackUrl('https://aac.saavncdn.com/song.mp4'),
      false,
    );
  });

  test('googlevideo URL is treated as youtube playback URL', () {
    expect(
      isUsableYoutubePlaybackUrl(
        'https://rr1---sn-test.googlevideo.com/videoplayback?expire=9999999999',
      ),
      true,
    );
  });
}
