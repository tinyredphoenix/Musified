class QueueEntryIdManager {
  int _counter = 0;

  String nextId() {
    return 'queue-${DateTime.now().microsecondsSinceEpoch}-${_counter++}';
  }

  String ensureId(Map song) {
    final existingId = song['queueEntryId']?.toString();
    if (existingId != null && existingId.isNotEmpty) {
      return existingId;
    }

    final generatedId = nextId();
    song['queueEntryId'] = generatedId;
    return generatedId;
  }

  Map<String, dynamic> createSong(Map song) {
    final queueSong = Map<String, dynamic>.from(song);
    queueSong['queueEntryId'] = nextId();
    return queueSong;
  }

  void ensureIds(Iterable<Map> songs) {
    for (final song in songs) {
      ensureId(song);
    }
  }
}
