import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

class LyricsManager {
  Future<String?> fetchLyrics(String artistName, String title) async {
    // Aggressive cleaning of YouTube title metadata
    var cleanTitle = title
        .replaceAll(RegExp(r'\s*\(.*?video.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\[.*?video.*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(.*?audio.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\[.*?audio.*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(.*?lyrics.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\[.*?lyrics.*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(.*?official.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\[.*?official.*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(.*?feat.*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(.*?ft\..*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\[.*?prod\..*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(.*?prod\..*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*4k|hd|8k|hq', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*lyrics', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*karaoke', caseSensitive: false), '')
        .trim();

    if (cleanTitle.contains(' - ')) {
      final parts = cleanTitle.split(' - ');
      if (parts.length == 2) {
        // Could be "Artist - Track" or "Track - Artist"
        if (parts[0].toLowerCase().contains(artistName.toLowerCase())) {
          cleanTitle = parts[1].trim();
        } else if (parts[1].toLowerCase().contains(artistName.toLowerCase())) {
          cleanTitle = parts[0].trim();
        }
      }
    } else if (cleanTitle.contains(' | ')) {
      cleanTitle = cleanTitle.split(' | ').first.trim();
    }

    if (cleanTitle.isEmpty) cleanTitle = title;
    final primaryArtist = artistName
        .split(RegExp('[,&|/]'))
        .first
        .replaceAll(RegExp(' - Topic', caseSensitive: false), '')
        .replaceAll(RegExp('VEVO', caseSensitive: false), '')
        .trim();

    // 1. Primary open lyrics catalog: LrcLib (exact query)
    final lrcLibLyrics = await _fetchLyricsFromLrcLib(primaryArtist, cleanTitle);
    if (lrcLibLyrics != null && lrcLibLyrics.isNotEmpty) {
      return lrcLibLyrics;
    }

    // 2. Try swapped or clean title search
    final lrcLibSearchLyrics =
        await _searchLyricsFromLrcLib('$cleanTitle $primaryArtist');
    if (lrcLibSearchLyrics != null && lrcLibSearchLyrics.isNotEmpty) {
      return lrcLibSearchLyrics;
    }

    // 3. Try searching with just clean title
    final lrcLibTitleOnly = await _searchLyricsFromLrcLib(cleanTitle);
    if (lrcLibTitleOnly != null && lrcLibTitleOnly.isNotEmpty) {
      return lrcLibTitleOnly;
    }

    // 4. Fallbacks (plain text)
    final lyricsFromLyricsOvh = await _fetchLyricsFromLyricsOvh(
      primaryArtist,
      cleanTitle,
    );
    if (lyricsFromLyricsOvh != null) {
      return lyricsFromLyricsOvh;
    }

    final lyricsFromParolesNet = await _fetchLyricsFromParolesNet(
      primaryArtist,
      cleanTitle,
    );
    if (lyricsFromParolesNet != null) {
      return lyricsFromParolesNet;
    }

    return null;
  }

  Future<String?> _fetchLyricsFromLrcLib(String artist, String title) async {
    try {
      final uri = Uri.https('lrclib.net', '/api/get', {
        'artist_name': artist,
        'track_name': title,
      });
      final response =
          await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final plainLyrics = json['plainLyrics'] as String?;
        final syncedLyrics = json['syncedLyrics'] as String?;
        if (syncedLyrics != null && syncedLyrics.trim().isNotEmpty) {
          return syncedLyrics.trim();
        }
        if (plainLyrics != null && plainLyrics.trim().isNotEmpty) {
          return plainLyrics.trim();
        }
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _searchLyricsFromLrcLib(String query) async {
    try {
      final uri = Uri.https('lrclib.net', '/api/search', {'q': query});
      final response =
          await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body);
        if (list is List && list.isNotEmpty) {
          // PASS 1: Prioritize synced karaoke lyrics
          for (final item in list) {
            if (item is Map) {
              final synced = item['syncedLyrics'] as String?;
              if (synced != null && synced.trim().isNotEmpty) {
                return synced.trim();
              }
            }
          }
          // PASS 2: Fall back to plain lyrics
          for (final item in list) {
            if (item is Map) {
              final plain = item['plainLyrics'] as String?;
              if (plain != null && plain.trim().isNotEmpty) {
                return plain.trim();
              }
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _fetchLyricsFromLyricsOvh(
    String artistName,
    String title,
  ) async {
    try {
      final artistFormatted = _lyricsUrl(artistName.split(',')[0]);
      final titleFormatted = _lyricsUrl(title);
      final uri = Uri.parse(
        'https://api.lyrics.ovh/v1/$artistFormatted/$titleFormatted',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final lyrics = json['lyrics'] as String?;
        if (lyrics != null && lyrics.isNotEmpty) {
          return addCopyright(lyrics, 'lyrics.ovh');
        }
      }
    } catch (e) {
      // Silently fail and return null to try next source
      return null;
    }
    return null;
  }

  Future<String?> _fetchLyricsFromParolesNet(
    String artistName,
    String title,
  ) async {
    try {
      final uri = Uri.parse(
        'https://www.paroles.net/${_lyricsUrl(artistName)}/paroles-${_lyricsUrl(title)}',
      );
      final response = await http
          .get(uri)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => http.Response('', 408),
          );

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        final songTextElements = document.querySelectorAll('.song-text');

        if (songTextElements.isNotEmpty) {
          final lyricsLines = songTextElements.first.text.split('\n');
          if (lyricsLines.length > 1) {
            lyricsLines.removeAt(0);

            final finalLyrics = addCopyright(
              lyricsLines.join('\n'),
              'www.paroles.net',
            );
            return _removeSpaces(finalLyrics);
          }
        }
      }
    } catch (e) {
      // Silently fail and return null to try next source
      return null;
    }

    return null;
  }

  String _lyricsUrl(String input) {
    var result = input.replaceAll(' ', '-').toLowerCase();
    // Remove special characters
    result = result.replaceAll(RegExp('[^a-z0-9-]'), '');
    // Clean up multiple/trailing dashes
    result = result.replaceAll(RegExp('-+'), '-');
    if (result.isNotEmpty && result.endsWith('-')) {
      result = result.substring(0, result.length - 1);
    }
    if (result.isNotEmpty && result.startsWith('-')) {
      result = result.substring(1);
    }
    return result;
  }

  String _removeSpaces(String input) {
    return input.replaceAll(RegExp(' {2,}'), ' ');
  }

  String addCopyright(String input, String copyright) {
    return '$input\n\n© $copyright';
  }
}
