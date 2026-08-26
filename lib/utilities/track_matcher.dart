class TrackMatcher {
  /// Clean a string from parentheses, brackets, noise words, and punctuation.
  static String cleanText(String s) {
    if (s.isEmpty) return '';
    var t = s.toLowerCase();

    // Remove ALL content in parentheses (), brackets [], braces {}
    t = t.replaceAll(RegExp(r'\([^)]*\)'), ' ');
    t = t.replaceAll(RegExp(r'\[[^\]]*\]'), ' ');
    t = t.replaceAll(RegExp(r'\{[^}]*\}'), ' ');

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
      'visualizer',
      'prod',
      'feat',
      'ft',
    ];

    for (final word in noiseWords) {
      t = t.replaceAll(RegExp('\\b$word\\b'), ' ');
    }

    // Keep only alphanumeric characters and spaces
    t = t.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t;
  }

  /// Get candidate titles (e.g. from "Artist - Song", both the full and sub parts).
  static List<String> getTitleCandidates(String title) {
    final full = cleanText(title);
    final list = <String>[full];
    if (title.contains(' - ')) {
      final parts = title.split(' - ');
      for (final p in parts) {
        final cp = cleanText(p);
        if (cp.isNotEmpty) list.add(cp);
      }
    }
    return list.where((e) => e.isNotEmpty).toList();
  }

  /// Check if two titles match based on candidates.
  static bool titlesMatch(String a, String b) {
    final candA = getTitleCandidates(a);
    final candB = getTitleCandidates(b);
    for (final ca in candA) {
      for (final cb in candB) {
        if (ca == cb) return true;
        if (ca.length >= 3 && cb.length >= 3) {
          if (ca.contains(cb) || cb.contains(ca)) return true;
        }
      }
    }
    return false;
  }

  /// Parse various duration formats to seconds.
  static int? parseDurationInSeconds(dynamic duration) {
    if (duration == null) return null;
    if (duration is int) return duration;
    final str = duration.toString().trim();
    if (str.isEmpty) return null;
    final asInt = int.tryParse(str);
    if (asInt != null) return asInt;
    if (str.contains(':')) {
      final parts = str.split(':');
      if (parts.length == 2) {
        final m = int.tryParse(parts[0]) ?? 0;
        final s = int.tryParse(parts[1]) ?? 0;
        return m * 60 + s;
      } else if (parts.length == 3) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        final s = int.tryParse(parts[2]) ?? 0;
        return h * 3600 + m * 60 + s;
      }
    }
    return null;
  }

  /// Check if two tracks match.
  static bool isExactMatch({
    required String titleA,
    required String artistA,
    dynamic durationA,
    required String titleB,
    required String artistB,
    dynamic durationB,
  }) {
    if (!titlesMatch(titleA, titleB)) return false;

    // Artist check: flexible substring or combined matching
    final cleanArtA = cleanText(artistA);
    final cleanArtB = cleanText(artistB);
    final combinedA = cleanText('$titleA $artistA');
    final combinedB = cleanText('$titleB $artistB');

    final artistMatches = cleanArtA.isEmpty ||
        cleanArtB.isEmpty ||
        cleanArtA.contains(cleanArtB) ||
        cleanArtB.contains(cleanArtA) ||
        combinedA.contains(cleanArtB) ||
        combinedB.contains(cleanArtA);

    if (!artistMatches) return false;

    // Duration check
    final durA = parseDurationInSeconds(durationA);
    final durB = parseDurationInSeconds(durationB);
    if (durA != null && durB != null && durA > 0 && durB > 0) {
      if ((durA - durB).abs() > 8) return false;
    }

    return true;
  }
}
