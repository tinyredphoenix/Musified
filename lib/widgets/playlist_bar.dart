/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Musify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Musify, including how to contribute,
 *     please visit: https://github.com/gokadzev/Musify
 */

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/services/artist_service.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/utilities/artwork_provider.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/musified_picker_sheet.dart';
import 'package:musify/utilities/offline_playlist_dialogs.dart';
import 'package:musify/utilities/playlist_dialogs.dart';
import 'package:musify/utilities/playlist_utils.dart';
import 'package:musify/widgets/edit_playlist_dialog.dart';
import 'package:musify/widgets/overflow_menu_button.dart';
import 'package:musify/widgets/popup_menu_item.dart';
import 'package:musify/widgets/spinner.dart';

class PlaylistBar extends StatelessWidget {
  PlaylistBar(
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

  static const double artworkSize = 60;
  static const double iconSize = 27;

  static const likeStatusToIconMapper = {
    true: CupertinoIcons.heart_slash,
    false: CupertinoIcons.heart,
  };

  // Helper to determine if this is a folder
  bool get isFolder =>
      playlistData != null && PlaylistUtils.isFolder(playlistData!);

  bool get isArtist {
    final data = playlistData;
    return data != null && isArtistPlaylist(data);
  }

  String? get _resolvedPlaylistId =>
      playlistId ?? playlistData?['ytid']?.toString();

  bool get _canAddToPlaylist => !isFolder && _resolvedPlaylistId != null;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayTitle = isArtist
        ? normalizeArtistDisplayTitle(playlistTitle)
        : playlistTitle;
    Map<dynamic, dynamic>? updatedPlaylist;
    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed ?? _getDefaultOnPressed(context, updatedPlaylist),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          child: Row(
            children: [
              if (isFolder)
                _buildFolderIcon(colorScheme)
              else
                _buildPlaylistIcon(colorScheme),
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
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                  child: Icon(
                                    CupertinoIcons.pin_fill,
                                    size: 13,
                                    color: colorScheme.primary,
                                  ),
                              );
                            },
                          ),
                        Expanded(
                          child: Text(
                            displayTitle,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: colorScheme.onSurface,
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
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (isFolder) ...[
                      const SizedBox(height: 3),
                      _buildFolderSubtitle(context) ?? const SizedBox.shrink(),
                    ],
                  ],
                ),
              ),
              if (showBuildActions) ...[
                const SizedBox(width: 4),
                OverflowMenuButton<String>(
                  onSelected: (String value) {
                    switch (value) {
                      case 'like':
                        if (_resolvedPlaylistId != null) {
                          final isLiked = isPlaylistAlreadyLiked(
                            _resolvedPlaylistId,
                          );
                          unawaited(
                            updatePlaylistLikeStatus(
                              _resolvedPlaylistId!,
                              !isLiked,
                              playlistData: playlistData,
                            ),
                          );
                        }
                        break;
                      case 'pin':
                        if (_resolvedPlaylistId != null) {
                          final pinned = togglePinnedPlaylist(
                            _resolvedPlaylistId!,
                            context,
                          );
                          if (!pinned &&
                              !isPlaylistPinned(_resolvedPlaylistId!) &&
                              pinnedPlaylistIds.value.length >=
                                  pinnedPlaylistsLimit) {
                            showToast(
                              context,
                              context.l10n.pinnedPlaylistsLimit,
                            );
                          }
                        }
                        break;
                      case 'delete':
                        if (onDelete != null) onDelete!();
                        break;
                      case 'moveToFolder':
                        _showMoveToFolderDialog(context);
                        break;
                      case 'edit':
                        if (isFolder) {
                          _handleEditFolder(context);
                        } else {
                          _handleEdit(context);
                        }
                        break;
                      case 'add_to_playlist':
                        _handleAddPlaylistToPlaylist(context);
                        break;
                      case 'remove_offline':
                        if (playlistData != null &&
                            playlistData!['ytid'] != null) {
                          showRemoveOfflinePlaylistDialog(
                            context,
                            playlistData!['ytid'].toString(),
                          );
                        }
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    final isUserCreated =
                        playlistData?['source'] == 'user-created';
                    final pinnedIds = pinnedPlaylistIds.value;

                    final isPinned =
                        _resolvedPlaylistId != null &&
                        pinnedIds.contains(_resolvedPlaylistId);

                    final isLiked =
                        _resolvedPlaylistId != null &&
                        isPlaylistAlreadyLiked(_resolvedPlaylistId);

                    final isOffline =
                        playlistData != null &&
                        (playlistData!['downloadedAt'] != null ||
                            playlistData!['isOffline'] == true);

                    return [
                      if (!isFolder && _resolvedPlaylistId != null)
                        buildPopupMenuItem<String>(
                          value: 'pin',
                          icon: isPinned
                              ? CupertinoIcons.pin_slash
                              : CupertinoIcons.pin,
                          label: isPinned
                              ? context.l10n.unpinFromLibrary
                              : context.l10n.pinToLibrary,
                          colorScheme: colorScheme,
                        ),
                      if (!isFolder && (onDelete == null || !isUserCreated))
                        buildPopupMenuItem<String>(
                          value: 'like',
                          icon: isLiked
                              ? CupertinoIcons.heart_fill
                              : CupertinoIcons.heart,
                          label: isLiked
                              ? context.l10n.removeFromLikedPlaylists
                              : context.l10n.addToLikedPlaylists,
                          colorScheme: colorScheme,
                        ),
                      if (_canAddToPlaylist)
                        buildPopupMenuItem<String>(
                          value: 'add_to_playlist',
                          icon: CupertinoIcons.plus_rectangle,
                          label: context.l10n.addToPlaylist,
                          colorScheme: colorScheme,
                        ),
                      if (isOffline)
                        buildPopupMenuItem<String>(
                          value: 'remove_offline',
                          icon: CupertinoIcons.cloud_download,
                          label: context.l10n.removeOffline,
                          colorScheme: colorScheme,
                          iconColor: colorScheme.error,
                        ),
                      if (playlistData != null &&
                          !isFolder &&
                          (playlistData!['source'] == 'user-created' ||
                              playlistData!['source'] == 'user-youtube'))
                        buildPopupMenuItem<String>(
                          value: 'moveToFolder',
                          icon: CupertinoIcons.folder,
                          label: context.l10n.moveToFolder,
                          colorScheme: colorScheme,
                        ),
                      if (playlistData != null &&
                          (isFolder ||
                              playlistData!['source'] == 'user-created'))
                        buildPopupMenuItem<String>(
                          value: 'edit',
                          icon: CupertinoIcons.pencil,
                          label: isFolder
                              ? context.l10n.editFolder
                              : context.l10n.editPlaylist,
                          colorScheme: colorScheme,
                        ),
                      if (onDelete != null)
                        buildPopupMenuItem<String>(
                          value: 'delete',
                          icon: CupertinoIcons.trash,
                          label: isFolder
                              ? context.l10n.deleteFolder
                              : context.l10n.deletePlaylist,
                          colorScheme: colorScheme,
                          iconColor: isFolder
                              ? colorScheme.error
                              : colorScheme.primary,
                          labelStyle: isFolder
                              ? TextStyle(color: colorScheme.error)
                              : null,
                        ),
                    ];
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistIcon(ColorScheme colorScheme) {
    final artwork = isArtist
        ? normalizeArtistThumbnailUrl(playlistArtwork)
        : playlistArtwork;
    if (artwork != null && artwork.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(isArtist ? 26 : 12),
        child: Image(
          image: ArtworkProvider.get(artwork),
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildIconFallback(colorScheme),
        ),
      );
    }
    return _buildIconFallback(colorScheme);
  }

  Widget _buildIconFallback(ColorScheme colorScheme) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        shape: isArtist ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isArtist ? null : BorderRadius.circular(12),
      ),
      child: Icon(cubeIcon, size: 26, color: colorScheme.onSecondaryContainer),
    );
  }

  void _showMoveToFolderDialog(BuildContext context) {
    final folders = userPlaylistFolders.value;

    String? currentFolderId;
    if (playlistData != null) {
      for (final folder in folders) {
        final folderPlaylists = folder['playlists'] as List? ?? [];
        if (folderPlaylists.any((p) => p['ytid'] == playlistData!['ytid'])) {
          currentFolderId = folder['id']?.toString();
          break;
        }
      }
    }

    final availableFolders = folders
        .where((folder) => folder['id'] != currentFolderId)
        .toList();

    final actions = <PickerSheetAction>[
      if (currentFolderId != null)
        PickerSheetAction(
          label: context.l10n.library,
          icon: CupertinoIcons.music_albums,
          onTap: () {
            if (playlistData != null) {
              movePlaylistToFolder(playlistData!, null, context);
            }
          },
        ),
      ...availableFolders.map(
        (folder) => PickerSheetAction(
          label: folder['name']?.toString() ?? '',
          onTap: () {
            if (playlistData != null) {
              movePlaylistToFolder(playlistData!, folder['id'], context);
            }
          },
        ),
      ),
    ];

    unawaited(
      showMusifiedPickerSheet(
        context,
        title: context.l10n.moveToFolder,
        emptyMessage: context.l10n.noFolders,
        actions: actions,
      ),
    );
  }

  // Helper methods for folder display
  Widget _buildFolderIcon(ColorScheme colorScheme) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        CupertinoIcons.folder,
        size: 26,
        color: colorScheme.onSecondaryContainer,
      ),
    );
  }

  Widget? _buildFolderSubtitle(BuildContext context) {
    if (!isFolder || playlistData == null) return null;

    final playlistCount = (playlistData!['playlists'] as List?)?.length ?? 0;
    return Text(
      playlistCount == 1
          ? '1 ${context.l10n.playlist.toLowerCase()}'
          : '$playlistCount ${context.l10n.playlists.toLowerCase()}',
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  VoidCallback? _getDefaultOnPressed(
    BuildContext context,
    Map<dynamic, dynamic>? updatedPlaylist,
  ) {
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
        showToast(context, context.l10n.error);
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

  Future<void> _handleAddPlaylistToPlaylist(BuildContext context) async {
    if (_resolvedPlaylistId == null) {
      showToast(context, context.l10n.error);
      return;
    }

    final navContext = NavigationManager().context;
    unawaited(
      showDialog(
        context: navContext,
        barrierDismissible: false,
        builder: (_) => const Center(child: Spinner()),
      ),
    );

    try {
      final fullPlaylist = await getPlaylistInfoForWidget(
        _resolvedPlaylistId,
        isArtist: isArtist,
        artistName: isArtist ? playlistTitle : null,
        artistImage: isArtist ? playlistArtwork : null,
        preferredVerified:
            isArtist && playlistData?['isVerifiedArtist'] == true,
      );
      if (!navContext.mounted) return;
      Navigator.pop(navContext);

      if (fullPlaylist == null || fullPlaylist['list'] == null) {
        showToast(navContext, navContext.l10n.error);
        return;
      }

      final tracks = fullPlaylist['list'] as List<dynamic>;
      if (tracks.isEmpty) {
        showToast(navContext, navContext.l10n.noSongsInPlaylist);
        return;
      }

      showAddToPlaylistDialog(navContext, songs: tracks);
    } catch (e) {
      if (navContext.mounted) {
        Navigator.pop(navContext);
        showToast(navContext, navContext.l10n.error);
      }
    }
  }

  Future<void> _handleEdit(BuildContext context) async {
    if (playlistData == null) return;

    final result = await showDialog<Map?>(
      context: context,
      builder: (context) => EditPlaylistDialog(playlistData: playlistData!),
    );

    if (result != null) {
      final index = userCustomPlaylists.value.indexOf(playlistData!);
      if (index != -1) {
        final updatedPlaylists = List<Map>.from(userCustomPlaylists.value);
        updatedPlaylists[index] = result;
        userCustomPlaylists.value = updatedPlaylists;
        unawaited(
          addOrUpdateData<List<Map>>(
            'user',
            'customPlaylists',
            userCustomPlaylists.value,
          ),
        );

        // Update offline playlist if it exists
        unawaited(syncOfflinePlaylistMetadata(result));

        final appCtx = NavigationManager().context;
        showToast(appCtx, appCtx.l10n.playlistUpdated);
      }
    }
  }

  void _handleEditFolder(BuildContext context) {
    if (playlistData == null) return;
    final folderId = playlistData!['id'];
    var folderName = playlistTitle;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(context.l10n.editFolder),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            placeholder: context.l10n.folderName,
            controller: TextEditingController(text: folderName),
            autofocus: true,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? CupertinoColors.tertiarySystemFill
                  : CupertinoColors.systemGrey6,
              borderRadius: BorderRadius.circular(8),
            ),
            onChanged: (value) => folderName = value,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(context);
              final result = renamePlaylistFolder(
                folderId,
                folderName,
                context,
              );
              showToast(context, result);
            },
            child: Text(context.l10n.update),
          ),
        ],
      ),
    );
  }
}
