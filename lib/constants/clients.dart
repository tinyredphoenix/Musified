import 'package:musified/services/ytdlp_client_sync_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Active (synced or built-in) visionos client used first for stream manifests.
YoutubeApiClient youtubeStreamClient() =>
    YtdlpClientSyncService.instance.streamClient();

/// Primary + fallback InnerTube clients for one stream request.
/// Tries each in order until audio streams are returned.
List<YoutubeApiClient> youtubeStreamClients() =>
    YtdlpClientSyncService.instance.streamClients();
