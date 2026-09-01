import 'dart:convert';
import 'package:dart_des/dart_des.dart';
import 'package:http/http.dart' as http;
import 'package:musified/main.dart' show logger;

class JioSaavnService {
  factory JioSaavnService() => _instance;
  JioSaavnService._();
  
  static final JioSaavnService _instance = JioSaavnService._();

  /// Search for tracks matching a query
  Future<List<Map<String, dynamic>>> searchTracks(String query, {int limit = 5}) async {
    try {
      final url = Uri.parse(
          'https://www.jiosaavn.com/api.php?__call=search.getResults&_format=json&_marker=0&api_version=4&ctx=web6dot0&n=$limit&q=${Uri.encodeComponent(query)}');
      final response = await http
          .get(url, headers: {
            'User-Agent':
                'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
            'Accept': 'application/json, text/plain, */*',
            'Referer': 'https://www.jiosaavn.com/',
          })
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty) return [];
        final jsonStart = body.indexOf('{');
        if (jsonStart == -1) return [];
        final jsonStr = body.substring(jsonStart);
        final json = jsonDecode(jsonStr);
        final rawResults = json['results'];
        if (rawResults is List) {
          return rawResults
              .whereType<Map<String, dynamic>>()
              .map(_formatTrack)
              .where((t) => (t['encrypted_media_url'] as String).isNotEmpty)
              .toList();
        }
        // Fallback: some responses nest under data/results
        if (json['data'] is Map && json['data']['results'] is List) {
          return (json['data']['results'] as List)
              .whereType<Map<String, dynamic>>()
              .map(_formatTrack)
              .where((t) => (t['encrypted_media_url'] as String).isNotEmpty)
              .toList();
        }
      }
    } catch (e) {
      // Ignore, let caller handle timeout
    }
    return [];
  }

  /// Get the direct streaming URL for a JioSaavn track
  /// quality: '96', '160', '320' (map 128->96 for Saavn compatibility)
  Future<String?> getStreamUrl(String encryptedMediaUrl, {String quality = '320'}) async {
    try {
      if (encryptedMediaUrl.isEmpty) return null;
      final q = quality == '128' ? '96' : quality;
      final decrypted = _decryptUrl(encryptedMediaUrl);
      if (decrypted.isEmpty) return null;
      final uri = Uri.tryParse(decrypted);
      if (uri == null || !uri.hasScheme) return null;
      // Replace bitrate only in the path so signed query tokens stay intact.
      final newPath = uri.path.replaceFirst(RegExp(r'_(\d+)\.mp4$'), '_$q.mp4');
      return uri.replace(path: newPath).toString();
    } catch (e) {
      return null;
    }
  }

  /// Decrypt the encrypted media URL using DES-ECB
  String _decryptUrl(String encryptedUrl) {
    try {
      final key = utf8.encode('38346591');
      final input = base64Decode(encryptedUrl);

      final des = DES(key: key, paddingType: DESPaddingType.PKCS7);
      final decrypted = des.decrypt(input);
      return utf8.decode(decrypted);
    } catch (e) {
      logger.log('JioSaavn URL decrypt failed: $e');
      return '';
    }
  }

  /// Convert a JioSaavn API response track to a standardized map
  Map<String, dynamic> _formatTrack(Map<String, dynamic> rawTrack) {
    var title = rawTrack['title']?.toString() ?? '';
    title = title
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&#039;', "'")
        .trim();

    final subtitle = rawTrack['subtitle']?.toString() ?? '';
    final moreInfo = rawTrack['more_info'] as Map<String, dynamic>?;
    // primary_artists can be string or list; extract properly
    var artist = '';
    final primary = moreInfo?['primary_artists'];
    if (primary is String && primary.isNotEmpty) {
      artist = primary;
    } else if (primary is List && primary.isNotEmpty) {
      artist = primary.map((e) => e is Map ? e['name']?.toString() ?? '' : e.toString()).join(', ');
    }
    if (artist.isEmpty) {
      final artistMap = moreInfo?['artistMap'];
      if (artistMap is Map) {
        final mapped = artistMap['primary_artists'];
        if (mapped is List && mapped.isNotEmpty) {
          artist = mapped
              .map((e) => e is Map ? e['name']?.toString() ?? '' : e.toString())
              .where((n) => n.isNotEmpty)
              .join(', ');
        }
      }
    }
    if (artist.isEmpty) artist = subtitle;
    artist = artist.replaceAll('&amp;', '&').replaceAll('&quot;', '"').replaceAll('&#039;', "'").trim();

    var image = rawTrack['image']?.toString() ?? moreInfo?['image']?.toString() ?? '';
    if (image.contains('150x150')) {
      image = image.replaceAll('150x150', '500x500');
    }
    if (image.contains('50x50')) {
      image = image.replaceAll('50x50', '500x500');
    }

    final encryptedUrl = moreInfo?['encrypted_media_url']?.toString() ?? rawTrack['encrypted_media_url']?.toString() ?? '';

    // duration may be string seconds or int
    final rawDur = moreInfo?['duration'] ?? rawTrack['duration'] ?? '0';
    final duration = int.tryParse(rawDur.toString()) ?? 0;

    return {
      'saavnId': rawTrack['id']?.toString() ?? '',
      'ytid': rawTrack['id']?.toString() ?? '',
      'title': title,
      'artist': artist,
      'image': image,
      'duration': duration,
      'encrypted_media_url': encryptedUrl,
      'source': 'saavn',
    };
  }
}
