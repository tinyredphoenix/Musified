import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// An InnerTube client definition, either compiled in or synced from yt-dlp.
class YoutubeInnertubeClientEntry {
  const YoutubeInnertubeClientEntry({
    required this.id,
    required this.clientName,
    required this.clientVersion,
    required this.host,
    required this.payload,
    required this.apiUrl,
    this.userAgent,
    this.isBuiltin = false,
  });

  final String id;
  final String clientName;
  final String clientVersion;
  final String host;
  final Map<String, dynamic> payload;
  final String apiUrl;
  final String? userAgent;
  final bool isBuiltin;

  String get displayLabel => '$clientName $clientVersion'.trim();

  bool get isUsable =>
      clientName.isNotEmpty &&
      clientVersion.isNotEmpty &&
      apiUrl.isNotEmpty &&
      payload['context'] is Map;

  YoutubeApiClient toYoutubeApiClient() =>
      YoutubeApiClient(Map<String, dynamic>.from(payload), apiUrl);

  Map<String, dynamic> toJson() => {
        'id': id,
        'clientName': clientName,
        'clientVersion': clientVersion,
        'host': host,
        'payload': payload,
        'apiUrl': apiUrl,
        'userAgent': userAgent,
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
      isBuiltin: json['isBuiltin'] == true,
    );
  }
}
