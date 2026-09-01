import 'package:flutter_test/flutter_test.dart';
import 'package:musified/utilities/app_utils.dart';

void main() {
  test('detects expired googlevideo URLs', () {
    final past = Uri.parse(
      'https://rr1---sn.test.googlevideo.com/videoplayback?expire=1&dur=200',
    );
    expect(isYoutubeStreamUrlExpired(past), isTrue);
    expect(isUsableYoutubePlaybackUrl(past.toString()), isFalse);
  });

  test('accepts future expire timestamps', () {
    final futureSec =
        DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch ~/
            1000;
    final url = Uri.parse(
      'https://rr1---sn.test.googlevideo.com/videoplayback'
      '?expire=$futureSec&dur=200',
    );
    expect(isYoutubeStreamUrlExpired(url), isFalse);
    expect(isUsableYoutubePlaybackUrl(url.toString()), isTrue);
  });
}
