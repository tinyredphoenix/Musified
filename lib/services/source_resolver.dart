import 'package:hive/hive.dart';
import 'package:musify/services/jiosaavn_service.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/track_matcher.dart';

class SourceResolver {
  factory SourceResolver() => _instance;
  SourceResolver._();
  
  static final SourceResolver _instance = SourceResolver._();

  final JioSaavnService _saavnService = JioSaavnService();
  late Box _matchCache;

  Future<void> init() async {
    _matchCache = await Hive.openBox('saavn_match_cache');
  }

  /// Resolve the best audio source for a song.
  Future<Map<String, dynamic>?> resolveAudioSource(Map song) async {
    if (!jiosaavnEnabled.value) return null;
    
    // Check if user prefers youtube exclusively
    if (preferredSource.value == 'youtube') return null;

    final ytid = song['ytid']?.toString() ?? song['id']?.toString() ?? '';
    if (ytid.isEmpty) return null;

    // Check cache
    final cached = getCachedMatch(ytid);
    if (cached != null) {
      final encryptedUrl = cached['encrypted_media_url']?.toString() ?? '';
      if (encryptedUrl.isNotEmpty) {
        final streamUrl = await _saavnService.getStreamUrl(
          encryptedUrl,
          quality: jiosaavnQuality.value,
        );
        if (streamUrl != null) {
          return {
            'url': streamUrl,
            'source': 'saavn',
            'bitrate': int.tryParse(jiosaavnQuality.value) ?? 320,
            'format': 'm4a',
            'saavnId': cached['saavnId'],
          };
        }
      }
    }

    final query = '${song['title']} ${song['artist']}'.trim();
    final results = await _saavnService.searchTracks(query);

    final sDuration = song['duration'];
    final durationA = sDuration is int ? sDuration : int.tryParse(sDuration?.toString() ?? '');

    for (final track in results) {
      final tDuration = track['duration'];
      final durationB = tDuration is int ? tDuration : int.tryParse(tDuration?.toString() ?? '');

      final isMatch = TrackMatcher.isExactMatch(
        titleA: song['title']?.toString() ?? '',
        artistA: song['artist']?.toString() ?? '',
        durationA: durationA,
        titleB: track['title']?.toString() ?? '',
        artistB: track['artist']?.toString() ?? '',
        durationB: durationB,
      );

      if (isMatch) {
        cacheMatch(ytid, track);
        
        final encryptedUrl = track['encrypted_media_url']?.toString() ?? '';
        final streamUrl = await _saavnService.getStreamUrl(
          encryptedUrl,
          quality: jiosaavnQuality.value,
        );
        
        if (streamUrl != null) {
          return {
            'url': streamUrl,
            'source': 'saavn',
            'bitrate': int.tryParse(jiosaavnQuality.value) ?? 320,
            'format': 'm4a',
            'saavnId': track['saavnId'],
          };
        }
      }
    }

    return null;
  }

  Map<String, dynamic>? getCachedMatch(String ytid) {
    final data = _matchCache.get(ytid);
    if (data != null && data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  void cacheMatch(String ytid, Map<String, dynamic> saavnData) {
    _matchCache.put(ytid, saavnData);
  }
}
