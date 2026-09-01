import 'package:musified/services/ytdlp_client_sync_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Musified resolves YouTube streams with visionos only — no fallback chain.
YoutubeApiClient youtubeStreamClient() =>
    YtdlpClientSyncService.instance.streamClient();

List<YoutubeApiClient> youtubeStreamClients() => [youtubeStreamClient()];
