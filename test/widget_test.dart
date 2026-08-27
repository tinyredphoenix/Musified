import 'package:flutter_test/flutter_test.dart';
import 'package:musified/utilities/track_matcher.dart';

void main() {
  test('TrackMatcher candidate matching', () {
    expect(
      TrackMatcher.isExactMatch(
        titleA: 'Shakira, Burna Boy - Dai Dai (Official Video)',
        artistA: 'shakiraVEVO',
        durationA: 223,
        titleB: 'Dai Dai',
        artistB: 'Shakira, Burna Boy',
        durationB: 223,
      ),
      isTrue,
    );

    expect(
      TrackMatcher.isExactMatch(
        titleA: 'Love',
        artistA: 'Artist A',
        durationA: 180,
        titleB: 'Beloved',
        artistB: 'Artist A',
        durationB: 180,
      ),
      isFalse,
    );

    expect(
      TrackMatcher.isExactMatch(
        titleA: 'the cure',
        artistA: 'Lady Gaga',
        durationA: 211,
        titleB: 'The Cure',
        artistB: 'Lady Gaga',
        durationB: 211,
      ),
      isTrue,
    );
  });
}
