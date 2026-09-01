import 'package:flutter_test/flutter_test.dart';
import 'package:musified/utilities/queue_entry_utils.dart';

void main() {
  test('createSong always assigns a fresh queue entry id', () {
    final manager = QueueEntryIdManager();
    final song = {'ytid': 'abc123', 'title': 'Test'};
    final a = manager.createSong(song);
    final b = manager.createSong(song);
    expect(a['queueEntryId'], isNotNull);
    expect(b['queueEntryId'], isNotNull);
    expect(a['queueEntryId'], isNot(b['queueEntryId']));
  });

  test('ensureId preserves existing queue entry id', () {
    final manager = QueueEntryIdManager();
    final song = <String, dynamic>{
      'ytid': 'abc123',
      'queueEntryId': 'queue-stable-id',
    };
    expect(manager.ensureId(song), 'queue-stable-id');
    expect(song['queueEntryId'], 'queue-stable-id');
  });

  test('clearQueue pattern should use ensureId not createSong', () {
    final manager = QueueEntryIdManager();
    final original = <String, dynamic>{
      'ytid': 'track1',
      'title': 'Song',
      'queueEntryId': 'queue-keep-me',
    };
    manager.ensureId(original);
    final kept = Map<String, dynamic>.from(original);
    expect(kept['queueEntryId'], 'queue-keep-me');
    expect(kept['queueEntryId'], isNot(manager.createSong(original)['queueEntryId']));
  });
}
