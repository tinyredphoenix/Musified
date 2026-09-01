import 'package:flutter_test/flutter_test.dart';
import 'package:musified/services/common_services.dart';

void main() {
  test('reads the true track length from a googlevideo URL', () {
    final url = Uri.parse(
      'https://rr2---sn-g5pauxapo-qxas.googlevideo.com/videoplayback'
      '?expire=1&itag=140&mime=audio%2Fmp4&dur=263.221&clen=4218000',
    );
    expect(youtubeStreamDurationSeconds(url), 263);
  });

  test('ignores missing or nonsensical dur values', () {
    expect(
      youtubeStreamDurationSeconds(Uri.parse('https://example.com/a')),
      isNull,
    );
    expect(
      youtubeStreamDurationSeconds(Uri.parse('https://example.com/a?dur=0')),
      isNull,
    );
    expect(
      youtubeStreamDurationSeconds(Uri.parse('https://example.com/a?dur=nope')),
      isNull,
    );
  });
}
