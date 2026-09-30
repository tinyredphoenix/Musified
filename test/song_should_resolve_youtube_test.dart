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

  test('source youtube without catalogOrigin still resolves youtube', () {
    final song = {
      'ytid': 'abc',
      'source': 'youtube',
    };
    expect(songIsYoutubeCatalog(song), true);
    expect(songShouldResolveYoutube(song), true);
    expect(preferredStreamSourceForSong(song), 'youtube');
  });

  test('auto preference resolves youtube immediately (no Saavn gap)', () {
    final song = {
      'ytid': 'abc',
      'title': 'Some Track',
      'artist': 'Someone',
    };
    // Without a YouTube catalog tag, auto must still prefer YouTube on the
    // playback path so lock-screen transitions never wait on Saavn search.
    expect(songShouldResolveYoutube(song), true);
  });

  test('warm youtube URL is kept when a saavn match is also cached', () {
    final song = {
      'ytid': 'abc',
      'resolvedSource': 'jiosaavn',
      'source': 'youtube',
    };
    expect(
      streamUrlMatchesPreferredSource(
        'https://rr1---sn-test.googlevideo.com/videoplayback?expire=9999999999',
        song,
      ),
      true,
    );
    expect(
      streamUrlMatchesPreferredSource(
        'https://aac.saavncdn.com/song.mp4',
        song,
      ),
      true,
    );
  });

  test('cached jiosaavn resolvedSource skips youtube-first path', () {
    final song = {
      'ytid': 'abc',
      'resolvedSource': 'jiosaavn',
    };
    expect(songShouldResolveYoutube(song), false);
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
