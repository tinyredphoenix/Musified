class TrackMatcher {
  /// Normalize a song title for matching.
  static String normalizeTitle(String title) {
    if (title.isEmpty) return '';

    var t = title.toLowerCase();

    // Remove ALL content in parentheses (), brackets [], braces {}
    t = t.replaceAll(RegExp(r'\([^)]*\)'), ' ');
    t = t.replaceAll(RegExp(r'\[[^\]]*\]'), ' ');
    t = t.replaceAll(RegExp(r'\{[^}]*\}'), ' ');

    // Remove after ' - ' suffixes
    if (t.contains(' - ')) {
      t = t.split(' - ').first;
    }

    // Remove known noise words
    final noiseWords = [
      'official music video',
      'official video',
      'official audio',
      'music video',
      'official',
      'audio',
      'video',
      'lyric',
      'lyrics',
      'hd',
      'hq',
      'full',
      'song',
    ];

    // Remove trailing noise words
    var changed = true;
    while (changed) {
      changed = false;
      for (final word in noiseWords) {
        if (t.endsWith(' $word')) {
          t = t.substring(0, t.length - word.length - 1);
          changed = true;
        }
      }
    }
    
    // Just in case, some noise words can be scattered
    for (final word in noiseWords) {
      t = t.replaceAll(RegExp('\\b$word\\b'), '');
    }

    // Collapse multiple spaces to single space and trim
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();

    return t;
  }

  /// Normalize artist names into a sorted Set for comparison.
  static Set<String> normalizeArtists(String artist) {
    if (artist.isEmpty) return <String>{};
    var a = artist.toLowerCase();

    // Remove known noise
    final noise = ['- topic', 'vevo', 'official', 'music'];
    for (final n in noise) {
      a = a.replaceAll(n, '');
    }

    // Split on delimiters
    final parts = a.split(RegExp(r' & |, | ft\. | feat\. | ft | feat | x | × | and '));

    final result = <String>{};
    for (final p in parts) {
      final clean = p.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (clean.isNotEmpty) {
        result.add(clean);
      }
    }

    final sortedList = result.toList()..sort();
    return sortedList.toSet();
  }

  /// Check if duration matches within tolerance.
  /// |a - b| <= 3 seconds
  static bool durationMatches(int? durationA, int? durationB, {int tolerance = 3}) {
    if (durationA == null || durationB == null) return false;
    return (durationA - durationB).abs() <= tolerance;
  }

  /// Check if two tracks are an EXACT match.
  static bool isExactMatch({
    required String titleA,
    required String artistA,
    int? durationA,
    required String titleB,
    required String artistB,
    int? durationB,
  }) {
    final normTitleA = normalizeTitle(titleA);
    final normTitleB = normalizeTitle(titleB);

    if (normTitleA != normTitleB) return false;

    final artistsA = normalizeArtists(artistA);
    final artistsB = normalizeArtists(artistB);

    // At least one overlap
    var overlap = false;
    for (final a in artistsA) {
      if (artistsB.contains(a)) {
        overlap = true;
        break;
      }
    }
    
    if (!overlap) return false;

    return durationMatches(durationA, durationB);
  }
}
