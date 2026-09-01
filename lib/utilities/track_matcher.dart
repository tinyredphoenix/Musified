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
      'remix',
      'nightcore',
      'slowed',
      'reverb',
    ];

    for (final word in noiseWords) {
      t = t.replaceAll(RegExp(r'\b' + RegExp.escape(word) + r'\b', caseSensitive: false), ' ');
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
    for (final sep in [' - ', ' – ', ' — ', ' | ', ': ']) {
      if (!title.contains(sep)) continue;
      for (final p in title.split(sep)) {
        final cp = cleanText(p);
        if (cp.isNotEmpty) list.add(cp);
      }
    }
    return list.where((e) => e.isNotEmpty).toList();
  }

  static Set<String> _tokens(String cleaned) {
    return cleaned
        .split(' ')
        .where((t) => t.length > 1)
        .toSet();
  }

  /// Check if two titles match based on candidates.
  static bool titlesMatch(String a, String b) {
    final candA = getTitleCandidates(a);
    final candB = getTitleCandidates(b);
    for (final ca in candA) {
      for (final cb in candB) {
        if (ca == cb) return true;
        final ta = _tokens(ca);
        final tb = _tokens(cb);
        if (ta.isEmpty || tb.isEmpty) continue;
        if (ta.containsAll(tb) || tb.containsAll(ta)) {
          final shorter = ta.length <= tb.length ? ta : tb;
          // Single short tokens ("love") matching inside longer titles
          // ("beloved") is too loose; require 2+ tokens or one long token.
          if (shorter.length >= 2) return true;
          if (shorter.length == 1 && shorter.first.length >= 6) return true;
          continue;
        }
        final inter = ta.intersection(tb).length;
        final union = ta.union(tb).length;
        if (union > 0 && inter / union >= 0.75 && inter >= 2) return true;
      }
    }
    return false;
  }

  /// Parse various duration formats to seconds.
  static int? parseDurationInSeconds(dynamic duration) {
    if (duration == null) return null;
    if (duration is Duration) return duration.inSeconds;
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

    final cleanArtA = _normalizeArtist(artistA);
    final cleanArtB = _normalizeArtist(artistB);
    final artistMatches = (cleanArtA.isEmpty && cleanArtB.isEmpty) ||
        (cleanArtA.isNotEmpty &&
            cleanArtB.isNotEmpty &&
            (cleanArtA == cleanArtB || _artistTokensOverlap(cleanArtA, cleanArtB)));

    if (!artistMatches) return false;

    final durA = parseDurationInSeconds(durationA);
    final durB = parseDurationInSeconds(durationB);
    if (durA != null && durB != null && durA > 0 && durB > 0) {
      if ((durA - durB).abs() > 12) return false;
    }

    return true;
  }

  static String _normalizeArtist(String artist) {
    var t = cleanText(artist);
    t = t.replaceAll(RegExp(r'vevo$'), '').trim();
    return t;
  }

  static bool _artistTokensOverlap(String a, String b) {
    final ta = a.split(' ').where((t) => t.length > 2).toSet();
    final tb = b.split(' ').where((t) => t.length > 2).toSet();
    return ta.isNotEmpty && tb.isNotEmpty && ta.intersection(tb).isNotEmpty;
  }
}
