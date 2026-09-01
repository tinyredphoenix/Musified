import 'package:musified/utilities/map_utils.dart';

import 'package:musified/services/audio/audio_queue_state.dart';

/// Pure queue list mutations — no playback, no streams.
/// Handler owns [AudioQueueState] and calls these for predictable queue edits.
class AudioQueueController {
  AudioQueueController(this.state);

  final AudioQueueState state;

  static bool isValidSong(Map song) {
    final ytid = song['ytid']?.toString();
    return ytid != null && ytid.isNotEmpty;
  }

  int insertIndexForAdd({required bool playNext}) {
    if (playNext) {
      var index = state.currentIndex + 1;
      if (index < 0) index = 0;
      if (index > state.items.length) index = state.items.length;
      return index;
    }
    return state.items.length;
  }

  Map<String, dynamic> manualEntry(Map song) {
    final entry = state.entryIds.createSong(song);
    entry['isManuallyAdded'] = true;
    return entry;
  }

  Map<String, dynamic> autoPickedEntry(Map song) {
    final entry = state.entryIds.createSong(song);
    entry['isAutoPicked'] = true;
    return entry;
  }

  void insertManual(Map song, {required bool playNext}) {
    final insertIndex = insertIndexForAdd(playNext: playNext);
    state.items.insert(insertIndex, manualEntry(song));
    if (state.currentIndex < 0) state.currentIndex = 0;
  }

  /// Replace queue with a single track (search / tile tap).
  void replaceWithSingle(Map song) {
    final entry = state.entryIds.createSong(cloneMap(song));
    entry['isManuallyAdded'] = true;
    state.items
      ..clear()
      ..add(entry);
    state.originalItems
      ..clear()
      ..add(cloneMap(entry));
    state.history.clear();
    state.currentIndex = 0;
  }

  int? indexForYtid(String ytid, String? Function(Map) songYtid) {
    final index = state.items.indexWhere((entry) => songYtid(entry) == ytid);
    return index >= 0 ? index : null;
  }

  /// Clear queue but keep the currently playing row (stable queueEntryId).
  void clearKeepingCurrent({Map<String, dynamic>? currentClone}) {
    state.items.clear();
    state.originalItems.clear();
    if (currentClone != null) {
      state.entryIds.ensureId(currentClone);
      final kept = cloneMap(currentClone);
      state.items.add(kept);
      state.originalItems.add(cloneMap(kept));
    }
    state.history.clear();
    state.currentIndex = 0;
    state.loadingIndex = -1;
  }

  void adjustIndicesAfterReorder(int oldIndex, int newIndex) {
    void shiftCurrent(int delta) {
      state.currentIndex += delta;
    }

    if (oldIndex == state.currentIndex) {
      state.currentIndex = newIndex;
    } else if (oldIndex < state.currentIndex && newIndex >= state.currentIndex) {
      shiftCurrent(-1);
    } else if (oldIndex > state.currentIndex && newIndex <= state.currentIndex) {
      shiftCurrent(1);
    }

    if (oldIndex == state.loadingIndex) {
      state.loadingIndex = newIndex;
    } else if (oldIndex < state.loadingIndex &&
        newIndex >= state.loadingIndex) {
      state.loadingIndex--;
    } else if (oldIndex > state.loadingIndex &&
        newIndex <= state.loadingIndex) {
      state.loadingIndex++;
    }
  }

  /// Returns removed entry id for shuffle-original sync, or null if invalid index.
  String? removeAt(int index) {
    if (!state.containsIndex(index)) return null;
    final removed = state.items.removeAt(index);
    return state.entryIds.ensureId(removed);
  }

  void adjustIndicesAfterRemove(int removedIndex) {
    if (removedIndex == state.loadingIndex) {
      state.loadingIndex = -1;
    } else if (removedIndex < state.loadingIndex) {
      state.loadingIndex--;
    }

    if (removedIndex < state.currentIndex) {
      state.currentIndex--;
    }
  }

  bool reorder(int oldIndex, int newIndex) {
    state.entryIds.ensureIds(state.items);
    if (oldIndex < 0 ||
        oldIndex >= state.items.length ||
        newIndex < 0 ||
        newIndex > state.items.length - 1) {
      return false;
    }

    final song = state.items.removeAt(oldIndex);
    state.items.insert(newIndex, song);
    adjustIndicesAfterReorder(oldIndex, newIndex);
    return true;
  }

  bool reorderById(String queueEntryId, int targetIndex) {
    state.entryIds.ensureIds(state.items);

    final oldIndex = state.items.indexWhere(
      (s) => state.entryIds.ensureId(s) == queueEntryId,
    );
    if (oldIndex == -1) return false;

    if (targetIndex < 0) targetIndex = 0;
    if (targetIndex > state.items.length) targetIndex = state.items.length;

    final song = state.items.removeAt(oldIndex);
    var newIndex = targetIndex;
    if (oldIndex < newIndex) newIndex--;
    if (newIndex < 0) newIndex = 0;
    if (newIndex > state.items.length) newIndex = state.items.length;
    state.items.insert(newIndex, song);
    adjustIndicesAfterReorder(oldIndex, newIndex);
    return true;
  }
}
