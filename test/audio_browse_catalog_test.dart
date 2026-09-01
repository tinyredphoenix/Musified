import 'package:flutter_test/flutter_test.dart';
import 'package:musified/services/audio/audio_browse_catalog.dart';
import 'package:musified/services/audio/audio_queue_controller.dart';
import 'package:musified/services/audio/audio_queue_state.dart';

void main() {
  test('AudioBrowseCatalog finds song across libraries', () {
    final found = AudioBrowseCatalog.findByYtid(
      'abc',
      currentSong: null,
      queueItems: [],
      liked: [{'ytid': 'abc', 'title': 'Hit'}],
      offline: [],
      recent: [],
    );
    expect(found?['title'], 'Hit');
  });

  test('AudioBrowseCatalog normalises resumable metadata', () {
    final normalised = AudioBrowseCatalog.normaliseResumableSong({
      'ytid': 'x1',
      'title': 'Song',
    });
    expect(normalised?['id'], 'x1');
    expect(normalised?['isLive'], false);
  });

  test('AudioQueueController reorder shifts current index', () {
    final state = AudioQueueState();
    state.items.addAll([
      {'ytid': 'a'},
      {'ytid': 'b'},
      {'ytid': 'c'},
    ]);
    state.currentIndex = 2;
    final controller = AudioQueueController(state);

    expect(controller.reorder(0, 2), isTrue);
    expect(state.currentIndex, 1);
    expect(state.items.map((s) => s['ytid']).toList(), ['b', 'c', 'a']);
  });

  test('AudioQueueController reorder allows drag to end', () {
    final state = AudioQueueState();
    state.items.addAll([
      {'ytid': 'a'},
      {'ytid': 'b'},
      {'ytid': 'c'},
    ]);
    final controller = AudioQueueController(state);

    expect(controller.reorder(0, 3), isTrue);
    expect(state.items.map((s) => s['ytid']).toList(), ['b', 'c', 'a']);
  });

  test('AudioBrowseCatalog resolves queue entry media ids', () {
    final song = {
      'queueEntryId': 'queue-1',
      'ytid': 'abcdefghijk',
      'title': 'Queued',
    };
    final found = AudioBrowseCatalog.findByMediaId(
      'queue-1',
      currentSong: null,
      queueItems: [song],
      liked: [],
      offline: [],
      recent: [],
    );
    expect(found?['title'], 'Queued');
  });
}
