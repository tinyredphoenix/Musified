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

  test('catalog youtube without force prefers youtube', () {
    final song = {
      'ytid': 'abc',
      'catalogOrigin': 'youtube',
    };
    expect(songShouldResolveYoutube(song), true);
  });
}
