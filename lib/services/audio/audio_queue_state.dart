import 'package:musified/utilities/queue_entry_utils.dart';

/// Mutable queue/history state for [MusifiedAudioHandler].
/// Centralizes index bounds checks so queue bugs are easier to trace.
class AudioQueueState {
  static const int maxHistorySize = 50;

  final List<Map> items = [];
  final List<Map> originalItems = [];
  final List<Map> history = [];
  final QueueEntryIdManager entryIds = QueueEntryIdManager();

  int currentIndex = 0;
  int loadingIndex = -1;

  bool containsIndex(int index) => index >= 0 && index < items.length;

  Map? songAt(int index) => containsIndex(index) ? items[index] : null;

  Map? get currentSong => songAt(currentIndex);

  void resetIndices() {
    loadingIndex = -1;
  }

  void addToHistory(Map song) {
    history.insert(0, song);
    if (history.length > maxHistorySize) {
      history.removeRange(maxHistorySize, history.length);
    }
  }
}
