import 'package:musified/services/ytdlp_client_sync_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// The single InnerTube client selected in Settings (no automatic fallback).
YoutubeApiClient? selectedYoutubeStreamClient() =>
    YtdlpClientSyncService.instance.selectedYoutubeClient();

/// One client for manifest requests; empty when none is configured.
List<YoutubeApiClient> get customClients {
  final client = selectedYoutubeStreamClient();
  if (client == null) return [];
  return [client];
}
