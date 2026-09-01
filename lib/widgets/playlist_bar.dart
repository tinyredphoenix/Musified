import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:musified/services/artist_service.dart';
import 'package:musified/services/common_services.dart';
import 'package:musified/services/playlists_manager.dart';
import 'package:musified/services/router_service.dart';
import 'package:musified/theme/app_themes.dart';
import 'package:musified/theme/musified_style.dart';
import 'package:musified/utilities/artwork_provider.dart';
import 'package:musified/utilities/flutter_toast.dart';
import 'package:musified/utilities/offline_playlist_dialogs.dart';
import 'package:musified/utilities/playlist_utils.dart';

class PlaylistBar extends StatelessWidget {
  const PlaylistBar(
    this.playlistTitle, {
    super.key,
    this.playlistId,
    this.playlistArtwork,
    this.playlistData,
    this.onPressed,
    this.onDelete,
    this.cubeIcon = CupertinoIcons.list_bullet,
    this.showBuildActions = true,
    this.isAlbum = false,
    this.borderRadius = BorderRadius.zero,
    this.subtitle,
  });

  final Map? playlistData;
  final String? playlistId;
  final String playlistTitle;
  final String? playlistArtwork;
  final String? subtitle;
  final VoidCallback? onPressed;
  final VoidCallback? onDelete;
  final IconData cubeIcon;
  final bool? isAlbum;
  final bool showBuildActions;
  final BorderRadius borderRadius;

  static const double artworkSize = 52;

  bool get isFolder =>
      playlistData != null && PlaylistUtils.isFolder(playlistData!);

  bool get isArtist {
    final data = playlistData;
    return data != null && isArtistPlaylist(data);
  }

  String? get _resolvedPlaylistId =>
      playlistId ?? playlistData?['ytid']?.toString();

  void _showActionSheet(BuildContext context) {
    final isUserCreated = playlistData?['source'] == 'user-created';
    final pinnedIds = pinnedPlaylistIds.value;
    final isPinned = _resolvedPlaylistId != null && pinnedIds.contains(_resolvedPlaylistId);
    final isLiked = _resolvedPlaylistId != null && isPlaylistAlreadyLiked(_resolvedPlaylistId);
    final isOffline = playlistData != null && (playlistData!['downloadedAt'] != null || playlistData!['isOffline'] == true);

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(playlistTitle),
        actions: [
          if (!isFolder && _resolvedPlaylistId != null)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                togglePinnedPlaylist(_resolvedPlaylistId!, context);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(isPinned ? CupertinoIcons.pin_slash : CupertinoIcons.pin, size: 20),
                  const SizedBox(width: 8),
                  Text(isPinned ? 'Unpin from Library' : 'Pin to Library'),
                ],
              ),
            ),
          if (!isFolder && (onDelete == null || !isUserCreated) && _resolvedPlaylistId != null)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                unawaited(updatePlaylistLikeStatus(_resolvedPlaylistId!, !isLiked, playlistData: playlistData));
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(isLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart, size: 20),
                  const SizedBox(width: 8),
                  Text(isLiked ? 'Remove from Favorites' : 'Add to Favorites'),
                ],
              ),
            ),
          if (isOffline && playlistData != null && playlistData!['ytid'] != null)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(ctx);
                showRemoveOfflinePlaylistDialog(context, playlistData!['ytid'].toString());
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.cloud_download, size: 20, color: CupertinoColors.destructiveRed),
                  SizedBox(width: 8),
                  Text('Remove Offline Download'),
                ],
              ),
            ),
          if (onDelete != null)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(ctx);
                onDelete!();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.trash, size: 20, color: CupertinoColors.destructiveRed),
                  const SizedBox(width: 8),
                  Text(isFolder ? 'Delete Folder' : 'Delete Playlist'),
                ],
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDarkMode(context);
    final displayTitle = isArtist
        ? normalizeArtistDisplayTitle(playlistTitle)
        : playlistTitle;
    final titleColor = isDark ? CupertinoColors.white : CupertinoColors.black;
    final cardBg = musifiedElevatedSurface(isDark);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: borderRadius == BorderRadius.zero ? BorderRadius.circular(12) : borderRadius,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed ?? _getDefaultOnPressed(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          child: Row(
            children: [
              if (isFolder)
                _buildFolderIcon(isDark)
              else
                _buildPlaylistIcon(isDark),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (!isFolder && _resolvedPlaylistId != null)
                          ValueListenableBuilder<List<String>>(
                            valueListenable: pinnedPlaylistIds,
                            builder: (_, ids, __) {
                              if (!ids.contains(_resolvedPlaylistId)) {
                                return const SizedBox.shrink();
                              }
                              return const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(
                                  CupertinoIcons.pin_fill,
                                  size: 13,
                                  color: Color(0xFFFF2D55),
                                ),
                              );
                            },
                          ),
                        Expanded(
                          child: Text(
                            displayTitle,
                            style: TextStyle(
                              fontFamily: MusifiedStyle.uiFont,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: titleColor,
                              decoration: TextDecoration.none,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontFamily: MusifiedStyle.uiFont,
                          fontSize: 13,
                          color: CupertinoColors.systemGrey,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showBuildActions)
                CupertinoButton(
                  padding: const EdgeInsets.all(8),
                  onPressed: () => _showActionSheet(context),
                  child: const Icon(CupertinoIcons.ellipsis, size: 20, color: CupertinoColors.systemGrey),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistIcon(bool isDark) {
    final artwork = isArtist
        ? normalizeArtistThumbnailUrl(playlistArtwork)
        : playlistArtwork;
    if (artwork != null && artwork.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(isArtist ? 26 : 10),
        child: Image(
          image: ArtworkProvider.get(artwork),
          width: artworkSize,
          height: artworkSize,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildIconFallback(isDark),
        ),
      );
    }
    return _buildIconFallback(isDark);
  }

  Widget _buildIconFallback(bool isDark) {
    return Container(
      width: artworkSize,
      height: artworkSize,
      decoration: BoxDecoration(
        color: musifiedSecondarySurface(isDark),
        shape: isArtist ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isArtist ? null : BorderRadius.circular(10),
      ),
      child: Icon(cubeIcon, size: 24, color: const Color(0xFFFF2D55)),
    );
  }

  Widget _buildFolderIcon(bool isDark) {
    return Container(
      width: artworkSize,
      height: artworkSize,
      decoration: BoxDecoration(
        color: musifiedSecondarySurface(isDark),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        CupertinoIcons.folder_fill,
        size: 24,
        color: Color(0xFFFF2D55),
      ),
    );
  }

  VoidCallback? _getDefaultOnPressed(BuildContext context) {
    if (isFolder && playlistData != null) {
      return () {
        context.push(
          '/home/folder/${playlistData!['id']}/${Uri.encodeComponent(playlistTitle)}',
        );
      };
    }

    return () {
      if (_resolvedPlaylistId == null ||
          _resolvedPlaylistId!.isEmpty ||
          _resolvedPlaylistId == 'null') {
        showToast(context, 'Unable to open playlist');
        return;
      }

      if (isArtist) {
        context.push(
          NavigationManager.artistPath(context, _resolvedPlaylistId!),
          extra: playlistData,
        );
        return;
      }

      context.push('/home/playlist/$_resolvedPlaylistId');
    };
  }
}
