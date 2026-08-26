import 'dart:convert';
import 'package:dart_des/dart_des.dart';
import 'package:http/http.dart' as http;

class JioSaavnService {
  factory JioSaavnService() => _instance;
  JioSaavnService._();
  
  static final JioSaavnService _instance = JioSaavnService._();

  /// Search for tracks matching a query
  Future<List<Map<String, dynamic>>> searchTracks(String query, {int limit = 5}) async {
    try {
      final url = Uri.parse(
          'https://www.jiosaavn.com/api.php?__call=search.getResults&_format=json&_marker=0&api_version=4&ctx=web6dot0&n=$limit&q=${Uri.encodeComponent(query)}');
      final response = await http.get(url, headers: {
        'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15',
      });
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['results'] != null) {
          final results = json['results'] as List<dynamic>;
          return results.map((e) => _formatTrack(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {
      // Ignore
    }
    return [];
  }

  /// Get the direct streaming URL for a JioSaavn track
  /// quality: '96', '160', '320'
  Future<String?> getStreamUrl(String encryptedMediaUrl, {String quality = '320'}) async {
    try {
      final decrypted = _decryptUrl(encryptedMediaUrl);
      return decrypted.replaceAll('_96.mp4', '_$quality.mp4');
    } catch (e) {
      return null;
    }
  }

  /// Decrypt the encrypted media URL using DES-ECB
  String _decryptUrl(String encryptedUrl) {
    final key = utf8.encode('38346591');
    final input = base64Decode(encryptedUrl);

    final des = DES(key: key, paddingType: DESPaddingType.PKCS7);
    final decrypted = des.decrypt(input);
    return utf8.decode(decrypted);
  }

  /// Convert a JioSaavn API response track to a standardized map
  Map<String, dynamic> _formatTrack(Map<String, dynamic> rawTrack) {
    var title = rawTrack['title']?.toString() ?? '';
    title = title.replaceAll('&quot;', '"');

    final subtitle = rawTrack['subtitle']?.toString() ?? '';
    var artist = rawTrack['more_info']?['primary_artists']?.toString() ?? subtitle;
    
    // Attempt to decode HTML entities just in case
    artist = artist.replaceAll('&amp;', '&').replaceAll('&quot;', '"');

    var image = rawTrack['image']?.toString() ?? '';
    if (image.contains('150x150')) {
      image = image.replaceAll('150x150', '500x500');
    }

    final encryptedUrl = rawTrack['more_info']?['encrypted_media_url']?.toString() ?? '';
    
    return {
      'saavnId': rawTrack['id']?.toString() ?? '',
      'ytid': rawTrack['id']?.toString() ?? '', // Fake ytid for compatibility if needed
      'title': title,
      'artist': artist,
      'image': image,
      'duration': int.tryParse(rawTrack['more_info']?['duration']?.toString() ?? '0') ?? 0,
      'encrypted_media_url': encryptedUrl,
      'source': 'saavn',
    };
  }
}
