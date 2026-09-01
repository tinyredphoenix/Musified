import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// User-selectable InnerTube client (built-in or synced from yt-dlp).
class YoutubeInnertubeClientEntry {
  const YoutubeInnertubeClientEntry({
    required this.id,
    required this.clientName,
    required this.clientVersion,
    required this.host,
    required this.payload,
    required this.apiUrl,
    this.userAgent,
    this.requiresAuth = false,
    this.isBuiltin = false,
  });

  final String id;
  final String clientName;
  final String clientVersion;
  final String host;
  final Map<String, dynamic> payload;
  final String apiUrl;
  final String? userAgent;
  final bool requiresAuth;
  final bool isBuiltin;

  String get displayLabel => '$clientName $clientVersion';

  String get pickerSubtitle {
    final parts = <String>[id.replaceAll('_', ' ')];
    if (requiresAuth) parts.add('login required');
    if (isBuiltin) parts.add('built-in');
    return parts.join(' · ');
  }

  YoutubeApiClient toYoutubeApiClient() {
    final headers = <String, String>{};
    if (clientName == 'TVHTML5') {
      headers.addAll({
        'Sec-Fetch-Mode': 'navigate',
        'Content-Type': 'application/json',
        'Origin': 'https://www.youtube.com',
      });
    }
    return YoutubeApiClient(
      Map<String, dynamic>.from(payload),
      apiUrl,
      headers: headers,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'clientName': clientName,
        'clientVersion': clientVersion,
        'host': host,
        'payload': payload,
        'apiUrl': apiUrl,
        'userAgent': userAgent,
        'requiresAuth': requiresAuth,
        'isBuiltin': isBuiltin,
      };

  factory YoutubeInnertubeClientEntry.fromJson(Map<String, dynamic> json) {
    return YoutubeInnertubeClientEntry(
      id: json['id']?.toString() ?? '',
      clientName: json['clientName']?.toString() ?? '',
      clientVersion: json['clientVersion']?.toString() ?? '',
      host: json['host']?.toString() ?? 'www.youtube.com',
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
      apiUrl: json['apiUrl']?.toString() ?? '',
      userAgent: json['userAgent']?.toString(),
      requiresAuth: json['requiresAuth'] == true,
      isBuiltin: json['isBuiltin'] == true,
    );
  }
}
