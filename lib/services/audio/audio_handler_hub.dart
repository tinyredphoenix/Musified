import 'package:musified/services/audio/audio_preload_cache.dart';
import 'package:musified/services/audio/audio_preload_service.dart';
import 'package:musified/services/audio/audio_queue_controller.dart';
import 'package:musified/services/audio/audio_queue_state.dart';

/// Single composition root for the audio subsystem.
///
/// Leaf modules only depend on their own data ([AudioQueueState],
/// [AudioPreloadCache]) or pure utilities. They never import each other.
/// [MusifiedAudioHandler] orchestrates via this hub only.
class AudioHandlerHub {
  AudioHandlerHub({
    this.queueLookahead = defaultQueueLookahead,
    this.maxConcurrentPreloads = defaultMaxConcurrentPreloads,
  });

  /// Warm this many upcoming tracks so a burst of lock-screen skips still
  /// hits a resolved URL. Anything past this window is fetched while the
  /// current song keeps playing — the player is not stopped first.
  static const int defaultQueueLookahead = 5;
  static const int defaultMaxConcurrentPreloads = 2;

  final int queueLookahead;
  final int maxConcurrentPreloads;

  final AudioQueueState queue = AudioQueueState();
  final AudioPreloadCache preloadCache = AudioPreloadCache();

  late final AudioQueueController queueOps = AudioQueueController(queue);
  late final AudioPreloadService preload = AudioPreloadService(
    cache: preloadCache,
    lookahead: queueLookahead,
    maxConcurrent: maxConcurrentPreloads,
  );

  /// Fast path: ytids currently in the play queue.
  Set<String> activeQueueYtids() => preload.queueYtids(queue.items);

  void cleanupStalePreloads() {
    preload.cleanupStaleForYtids(activeQueueYtids());
  }

  List<Map> upcomingPreloadCandidates({required bool offlineModeEnabled}) {
    return preload.upcomingSongs(
      queueItems: queue.items,
      currentIndex: queue.currentIndex,
      offlineModeEnabled: offlineModeEnabled,
    );
  }

  void resetPreloads() => preloadCache.reset();
}
