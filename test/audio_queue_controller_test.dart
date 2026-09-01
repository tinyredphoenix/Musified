import 'package:flutter_test/flutter_test.dart';
import 'package:musified/services/audio/audio_queue_controller.dart';
import 'package:musified/services/audio/audio_queue_state.dart';

void main() {
  test('insertIndexForAdd respects playNext and bounds', () {
    final state = AudioQueueState();
    state.items.addAll([
      {'ytid': 'a'},
      {'ytid': 'b'},
    ]);
    state.currentIndex = 1;
    final controller = AudioQueueController(state);

    expect(controller.insertIndexForAdd(playNext: false), 2);
    expect(controller.insertIndexForAdd(playNext: true), 2);
  });

  test('replaceWithSingle resets history and index', () {
    final state = AudioQueueState();
    state.history.add({'ytid': 'old'});
    state.currentIndex = 3;
    final controller = AudioQueueController(state);

    controller.replaceWithSingle({'ytid': 'new', 'title': 'New'});

    expect(state.items.length, 1);
    expect(state.items.first['ytid'], 'new');
    expect(state.history, isEmpty);
    expect(state.currentIndex, 0);
    expect(state.items.first['queueEntryId'], isNotNull);
  });

  test('clearKeepingCurrent preserves queue entry id', () {
    final state = AudioQueueState();
    final current = <String, dynamic>{
      'ytid': 'keep',
      'queueEntryId': 'queue-stable',
    };
    state.items.addAll([
      current,
      {'ytid': 'drop'},
    ]);
    state.currentIndex = 0;
    final controller = AudioQueueController(state);

    controller.clearKeepingCurrent(currentClone: Map<String, dynamic>.from(current));

    expect(state.items.length, 1);
    expect(state.items.first['queueEntryId'], 'queue-stable');
    expect(state.history, isEmpty);
    expect(state.currentIndex, 0);
  });
}
