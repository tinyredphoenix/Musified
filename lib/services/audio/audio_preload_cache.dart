/// Pre-resolved stream URLs for upcoming queue items.
class AudioPreloadCache {
  int activeCount = 0;
  final Set<String> preloadingYtIds = <String>{};
  final Set<String> preloadedYtIds = <String>{};
  final Map<String, String> streamUrls = <String, String>{};

  void reset() {
    activeCount = 0;
    preloadingYtIds.clear();
    preloadedYtIds.clear();
    streamUrls.clear();
  }

  void drop(String ytid) {
    preloadingYtIds.remove(ytid);
    preloadedYtIds.remove(ytid);
    streamUrls.remove(ytid);
  }
}
