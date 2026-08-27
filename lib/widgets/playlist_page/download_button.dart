import 'package:flutter/cupertino.dart';
import 'package:musified/services/common_services.dart';
import 'package:musified/services/playlist_download_service.dart';
import 'package:musified/services/settings_manager.dart';
import 'package:musified/utilities/flutter_toast.dart';
import 'package:musified/utilities/offline_playlist_dialogs.dart';

class PlaylistDownloadButton extends StatefulWidget {
  const PlaylistDownloadButton({
    super.key,
    required this.playlistId,
    required this.resolvePlaylist,
    this.songs,
    this.requireSnapshotMatch = false,
  });

  final String playlistId;
  final Future<Map?> Function() resolvePlaylist;
  final List? songs;
  final bool requireSnapshotMatch;

  @override
  State<PlaylistDownloadButton> createState() => _PlaylistDownloadButtonState();
}

class _PlaylistDownloadButtonState extends State<PlaylistDownloadButton> {
  bool _isResolving = false;

  String get playlistId => widget.playlistId;

  bool get _isOffline {
    final songs = widget.songs;
    if (songs == null) {
      return offlinePlaylistService.isPlaylistDownloaded(playlistId);
    }
    if (!isPlaylistFullyOffline(songs)) return false;
    if (!widget.requireSnapshotMatch) return true;

    final snapshot = offlinePlaylistService.getOfflinePlaylist(playlistId);
    if (snapshot == null) return false;
    final snapshotIds = (snapshot['list'] as List? ?? const [])
        .map((song) => song['ytid'])
        .toSet();
    return songs.every((song) => snapshotIds.contains(song['ytid']));
  }

  @override
  Widget build(BuildContext context) {
    if (playlistId.isEmpty) return const SizedBox.shrink();

    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;

    return ValueListenableBuilder<List>(
      valueListenable: userOfflineSongs,
      builder: (context, _, __) => ValueListenableBuilder<List>(
        valueListenable: offlinePlaylistService.offlinePlaylists,
        builder: (context, __, ___) {
          if (_isOffline) {
            return CupertinoButton(
              padding: const EdgeInsets.all(10),
              color: const Color(0xFFFF2D55),
              borderRadius: BorderRadius.circular(22),
              onPressed: () =>
                  showRemoveOfflinePlaylistDialog(context, playlistId),
              child: const Icon(
                CupertinoIcons.arrow_down_circle_fill,
                color: CupertinoColors.white,
                size: 20,
              ),
            );
          }

          return ValueListenableBuilder<DownloadProgress>(
            valueListenable: offlinePlaylistService.getProgressNotifier(
              playlistId,
            ),
            builder: (context, progress, _) {
              if (offlinePlaylistService.isPlaylistDownloading(playlistId)) {
                return _buildProgress(context, progress);
              }

              if (offlineMode.value) return const SizedBox.shrink();

              if (_isResolving) {
                return const SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: CupertinoActivityIndicator(),
                  ),
                );
              }

              return CupertinoButton(
                padding: const EdgeInsets.all(10),
                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(22),
                onPressed: () => _download(context),
                child: const Icon(
                  CupertinoIcons.arrow_down_to_line,
                  size: 20,
                  color: Color(0xFFFF2D55),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildProgress(BuildContext context, DownloadProgress progress) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CupertinoActivityIndicator(),
          ),
          if (!progress.isCancelled)
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () =>
                  offlinePlaylistService.cancelDownload(context, playlistId),
              child: const Icon(CupertinoIcons.xmark, size: 14, color: CupertinoColors.destructiveRed),
            ),
        ],
      ),
    );
  }

  Future<void> _download(BuildContext context) async {
    if (_isResolving) return;

    setState(() => _isResolving = true);
    Map? playlist;
    try {
      playlist = await widget.resolvePlaylist();
    } catch (_) {
      if (context.mounted) showToast(context, 'Error loading playlist');
      return;
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
    if (!context.mounted) return;

    if (playlist == null) {
      showToast(context, 'Error loading playlist');
      return;
    }

    await offlinePlaylistService.downloadPlaylist(context, playlist);
  }
}
