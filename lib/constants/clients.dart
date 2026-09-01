import 'package:musified/services/ytdlp_client_sync_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// The single InnerTube client Musified resolves streams with. See
/// [YtdlpClientSyncService] for why there is no fallback chain.
YoutubeApiClient selectedYoutubeStreamClient() =>
    YtdlpClientSyncService.instance.activeClient();

List<YoutubeApiClient> get customClients => [selectedYoutubeStreamClient()];
