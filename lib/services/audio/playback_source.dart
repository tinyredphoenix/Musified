/// Resolved playback target for a queue item (local file or remote URL).
class PlaybackSource {
  const PlaybackSource({required this.songUrl, required this.isOffline});

  final String songUrl;
  final bool isOffline;
}
