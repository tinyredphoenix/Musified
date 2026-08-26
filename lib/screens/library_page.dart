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

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/constants/app_constants.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart' show logger;
import 'package:musify/services/common_services.dart';
import 'package:musify/services/playlist_download_service.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/services/youtube_auth_service.dart';
import 'package:musify/services/youtube_music_sync_service.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/utilities/async_loader.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/offline_playlist_dialogs.dart';
import 'package:musify/utilities/playlist_dialogs.dart';
import 'package:musify/utilities/playlist_utils.dart';
import 'package:musify/widgets/confirmation_dialog.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';
import 'package:musify/widgets/playlist_bar.dart';
import 'package:musify/widgets/section_header.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  _LibraryPageState createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  @override
  void initState() {
    super.initState();
    if (YouTubeAuthService().isSignedIn.value) {
      unawaited(YouTubeMusicSyncService().syncPlaylists());
      unawaited(YouTubeMusicSyncService().syncLikedSongs());
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show offline mode message if there is no content
    if (offlineMode.value) {
      final hasUserContent =
          userPlaylistFolders.value.isNotEmpty ||
          userPlaylists.value.isNotEmpty ||
          userCustomPlaylists.value.isNotEmpty;
      final hasOfflinePlaylists = offlinePlaylistService.offlinePlaylists.value
          .any((p) => p is Map && !PlaylistUtils.isArtistPlaylist(p));
      final hasOfflineArtists = getLikedArtistItems(
        offlineOnly: true,
      ).isNotEmpty;
      final hasOfflineSongs = userOfflineSongs.value.isNotEmpty;

      if (!hasUserContent &&
          !hasOfflinePlaylists &&
          !hasOfflineArtists &&
          !hasOfflineSongs) {
        final colorScheme = Theme.of(context).colorScheme;
        return CupertinoPageScaffold(
          
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Looking for Music?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.noOfflineLibraryContent,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return CupertinoPageScaffold(
      
      child: AnimatedBuilder(
        animation: Listenable.merge([
          pinnedPlaylistIds,
          offlineMode,
          userCustomPlaylists,
          userPlaylistFolders,
          offlinePlaylistService.offlinePlaylists,
          userLikedPlaylists,
          onlinePlaylists,
          userPlaylists,
          userOfflineSongs,
        ]),
        builder: (context, _) {
          return Padding(
            padding: commonSingleChildScrollViewPadding,
            child: CustomScrollView(
              slivers: [
                CupertinoSliverNavigationBar(
                  largeTitle: Text(context.l10n.library),
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.8),
                ),
                if (!offlineMode.value) ..._buildYouTubePlaylistsSlivers(),
                ..._buildPinnedSlivers(),
                if (!offlineMode.value) ..._buildLikedPlaylistsSlivers(),
                ..._buildLikedArtistsSlivers(),
                const SliverMiniPlayerBottomSpace(),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildYouTubePlaylistsSlivers() {
    return [
      SliverToBoxAdapter(
        child: ValueListenableBuilder<bool>(
          valueListenable: YouTubeAuthService().isSignedIn,
          builder: (context, isSignedIn, _) {
            if (!isSignedIn) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: 'YouTube Music Playlists',
                  icon: CupertinoIcons.play_rectangle,
                  actionButton: CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Icon(CupertinoIcons.refresh),
                    onPressed: () {
                      unawaited(YouTubeMusicSyncService().fullSync());
                      showToast(context, 'Sync started');
                    },
                  ),
                ),
                ValueListenableBuilder<List<Map<String, dynamic>>>(
                  valueListenable: YouTubeMusicSyncService().ytMusicPlaylists,
                  builder: (context, playlists, _) {
                    if (playlists.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No playlists found'),
                      );
                    }
                    return SizedBox(
                      height: 190,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: playlists.length,
                        itemBuilder: (context, index) {
                          final playlist = playlists[index];
                          final title = playlist['title'] ?? 'Unknown';
                          final image = playlist['image'] ?? '';
                          final count = playlist['count'] ??
                              _playlistCountFromTrackCount(playlist['trackCount']) ??
                              0;
                          
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              final id = playlist['playlistId']?.toString();
                              if (id != null) {
                                context.push(
                                  '/home/playlist/$id',
                                  extra: {
                                    'title': title,
                                    'image': image,
                                    'ytid': id,
                                    'source': 'user-youtube',
                                  },
                                );
                              }
                            },
                            child: Container(
                              width: 140,
                              margin: const EdgeInsets.only(right: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: image.toString().isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: image.toString(),
                                            width: 140,
                                            height: 140,
                                            fit: BoxFit.cover,
                                            memCacheWidth: 280,
                                            memCacheHeight: 280,
                                            errorWidget: (_, __, ___) =>
                                                _buildFallbackImage(),
                                          )
                                        : _buildFallbackImage(),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    title.toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    '$count tracks',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    ];
  }

  Widget _buildFallbackImage() {
    return Container(
      width: 140,
      height: 140,
      color: Colors.grey[800],
      child: const Icon(CupertinoIcons.music_note_list, size: 40),
    );
  }

  List<Widget> _buildPinnedSlivers() {
    final ids = pinnedPlaylistIds.value;
    if (ids.isEmpty) return [];

    final isOff = offlineMode.value;
    final items = resolvePinnedPlaylists(ids).where((p) {
      return !isOff ||
          offlinePlaylistService.isPlaylistDownloaded(
            p['ytid']?.toString() ?? '',
          );
    }).toList();

    if (items.isEmpty) return [];

    return [
      SliverToBoxAdapter(
        child: SectionHeader(
          title: context.l10n.pinnedPlaylists,
          icon: CupertinoIcons.pin_fill,
        ),
      ),
      _buildSliverPlaylistList(items),
    ];
  }

  List<Widget> _buildUserPlaylistsSlivers() {
    final colorScheme = Theme.of(context).colorScheme;
    final isOffline = offlineMode.value;

    final rawOfflinePlaylists = offlinePlaylistService.offlinePlaylists.value;
    final visibleOfflinePlaylists = rawOfflinePlaylists
        .where((p) => p is Map && !PlaylistUtils.isArtistPlaylist(p))
        .toList();
    final folders = isOffline
        ? userPlaylistFolders.value
              .where(PlaylistUtils.folderHasOfflinePlaylists)
              .toList()
        : userPlaylistFolders.value;

    final offlinePlaylistsNotInFolders =
        PlaylistUtils.filterOfflinePlaylistsNotInFolders(
          visibleOfflinePlaylists,
          folders,
        );

    final offlineIdsNotInFolders = PlaylistUtils.offlinePlaylistIdsNotInFolders(
      visibleOfflinePlaylists,
      folders,
    );

    final allPlaylistsNotInFolders = getPlaylistsNotInFolders();
    final playlistsNotInFolders = PlaylistUtils.excludePlaylistsWithIds(
      allPlaylistsNotInFolders,
      offlineIdsNotInFolders,
    );

    final hasFolders = folders.isNotEmpty;
    final hasCustomPlaylists = playlistsNotInFolders.isNotEmpty;
    final hasLibraryContent = !isOffline || hasFolders || hasCustomPlaylists;

    final slivers = <Widget>[];

    if (hasLibraryContent) {
      slivers.add(
        SliverToBoxAdapter(
          child: Column(
            children: [
              SectionHeader(
                title: context.l10n.customPlaylists,
                icon: CupertinoIcons.music_albums_fill,
                actionButton: isOffline
                    ? null
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            onPressed: _showCreateFolderDialog,
                            icon: Icon(
                              CupertinoIcons.folder_badge_plus,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            tooltip: context.l10n.createFolder,
                          ),
                          IconButton(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            onPressed: () => showCreatePlaylistDialog(context),
                            icon: Icon(
                              CupertinoIcons.plus,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
              ),
              if (!isOffline) ...[
                PlaylistBar(
                  context.l10n.recentlyPlayed,
                  onPressed: () =>
                      NavigationManager.router.go('/library/userSongs/recents'),
                  cubeIcon: CupertinoIcons.clock,
                  borderRadius: commonCustomBarRadiusFirst,
                  showBuildActions: false,
                ),
                PlaylistBar(
                  context.l10n.likedSongs,
                  onPressed: () =>
                      NavigationManager.router.go('/library/userSongs/liked'),
                  cubeIcon: CupertinoIcons.heart,
                  showBuildActions: false,
                ),
                PlaylistBar(
                  context.l10n.offlineSongs,
                  onPressed: () =>
                      NavigationManager.router.go('/library/userSongs/offline'),
                  cubeIcon: CupertinoIcons.cloud_download,
                  borderRadius: hasCustomPlaylists || hasFolders
                      ? BorderRadius.zero
                      : commonCustomBarRadiusLast,
                  showBuildActions: false,
                ),
              ],
            ],
          ),
        ),
      );

      if (hasFolders) {
        slivers.add(_buildFolderSliverList(folders, hasCustomPlaylists));
      }
      if (hasCustomPlaylists) {
        slivers.add(
          _buildSliverPlaylistList(playlistsNotInFolders, hasItemsBefore: true),
        );
      }
    }

    final offlinePlaylists = offlinePlaylistsNotInFolders;

    if (offlinePlaylists.isNotEmpty) {
      slivers
        ..add(
          SliverToBoxAdapter(
            child: SectionHeader(
              title: context.l10n.offlinePlaylists,
              icon: CupertinoIcons.cloud_download,
            ),
          ),
        )
        ..add(
          _buildSliverPlaylistList(offlinePlaylists, isOfflinePlaylists: true),
        );
    }

    if (!offlineMode.value && userPlaylists.value.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: Column(
            children: [
              SectionHeader(
                title: context.l10n.addedPlaylists,
                icon: CupertinoIcons.plus_circle_fill,
                actionButton: IconButton(
                  padding: const EdgeInsets.only(right: 5),
                  onPressed: () => showCreatePlaylistDialog(context),
                  icon: Icon(
                    CupertinoIcons.plus,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              AsyncLoader<List<dynamic>>(
                future: getUserPlaylistsNotInFolders(),
                emptyWidget: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    context.l10n.noPlaylistsAdded,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                builder: _buildPlaylistListView,
              ),
            ],
          ),
        ),
      );
    }

    return slivers;
  }

  List<Widget> _buildLikedPlaylistsSlivers() {
    final likedPlaylists = getLikedPlaylistItems();
    if (likedPlaylists.isEmpty) return [];
    return [
      SliverToBoxAdapter(
        child: SectionHeader(
          title: context.l10n.likedPlaylists,
          icon: CupertinoIcons.heart_fill,
        ),
      ),
      _buildSliverPlaylistList(likedPlaylists),
    ];
  }

  List<Widget> _buildLikedArtistsSlivers() {
    final likedArtists = getLikedArtistItems(offlineOnly: offlineMode.value);
    if (likedArtists.isEmpty) return [];
    return [
      SliverToBoxAdapter(
        child: SectionHeader(
          title: context.l10n.artist,
          icon: CupertinoIcons.person_crop_circle_fill,
        ),
      ),
      _buildSliverPlaylistList(likedArtists),
    ];
  }

  Widget _buildSliverPlaylistList(
    List playlists, {
    bool isOfflinePlaylists = false,
    bool hasItemsAfter = false,
    bool hasItemsBefore = false,
  }) {
    return SliverPadding(
      padding: hasItemsAfter ? EdgeInsets.zero : commonListViewBottomPadding,
      sliver: SliverList.builder(
        itemCount: playlists.length,
        itemBuilder: (BuildContext context, index) {
          final playlist = playlists[index];
          final isArtist = playlist['source']?.toString() == 'youtube-artist';
          final borderRadius = getItemBorderRadius(
            index,
            playlists.length,
            hasItemsBefore: hasItemsBefore,
            hasItemsAfter: hasItemsAfter,
          );
          return PlaylistBar(
            key: listItemKey('library_playlist', index, playlist),
            playlist['title'],
            playlistId: playlist['ytid'],
            playlistArtwork: playlist['image'],
            cubeIcon: isArtist
                ? CupertinoIcons.person_crop_circle_fill
                : CupertinoIcons.list_bullet,
            isAlbum: isArtist ? false : playlist['isAlbum'],
            playlistData:
                isArtist ||
                    playlist['source'] == 'user-created' ||
                    playlist['source'] == 'user-youtube' ||
                    isOfflinePlaylists
                ? playlist
                : null,
            onDelete:
                playlist['source'] == 'user-created' ||
                    playlist['source'] == 'user-youtube' ||
                    isOfflinePlaylists
                ? () => isOfflinePlaylists
                      ? _showRemoveOfflinePlaylistDialog(playlist)
                      : _showRemovePlaylistDialog(playlist)
                : null,
            borderRadius: borderRadius,
          );
        },
      ),
    );
  }

  Widget _buildFolderSliverList(List folders, bool hasPlaylistsAfter) {
    return SliverList.builder(
      itemCount: folders.length,
      itemBuilder: (BuildContext context, index) {
        final folder = folders[index];
        final isLastFolder = index == folders.length - 1;
        final borderRadius = isLastFolder && !hasPlaylistsAfter
            ? commonCustomBarRadiusLast
            : BorderRadius.zero;
        return PlaylistBar(
          folder['name'],
          playlistData: folder,
          borderRadius: borderRadius,
          onDelete: () => _showDeleteFolderDialog(folder),
        );
      },
    );
  }

  Widget _buildPlaylistListView(
    BuildContext context,
    List playlists, {
    bool isOfflinePlaylists = false,
    bool hasItemsAfter = false,
    bool hasItemsBefore = false,
  }) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: playlists.length,
      padding: hasItemsAfter ? EdgeInsets.zero : commonListViewBottomPadding,
      itemBuilder: (BuildContext context, index) {
        final playlist = playlists[index];
        final borderRadius = getItemBorderRadius(
          index,
          playlists.length,
          hasItemsBefore: hasItemsBefore,
          hasItemsAfter: hasItemsAfter,
        );
        return PlaylistBar(
          key: listItemKey('library_playlist', index, playlist),
          playlist['title'],
          playlistId: playlist['ytid'],
          playlistArtwork: playlist['image'],
          isAlbum: playlist['isAlbum'],
          playlistData:
              playlist['source'] == 'user-created' ||
                  playlist['source'] == 'user-youtube' ||
                  isOfflinePlaylists
              ? playlist
              : null,
          onDelete:
              playlist['source'] == 'user-created' ||
                  playlist['source'] == 'user-youtube' ||
                  isOfflinePlaylists
              ? () => isOfflinePlaylists
                    ? _showRemoveOfflinePlaylistDialog(playlist)
                    : _showRemovePlaylistDialog(playlist)
              : null,
          borderRadius: borderRadius,
        );
      },
    );
  }

  void _showRemoveOfflinePlaylistDialog(Map playlist) {
    final playlistId = playlist['ytid']?.toString() ?? '';
    if (playlistId.isEmpty) return;
    showRemoveOfflinePlaylistDialog(context, playlistId);
  }

  void _showRemovePlaylistDialog(Map playlist) => showDialog(
    context: context,
    builder: (BuildContext context) {
      return ConfirmationDialog(
        confirmationMessage: context.l10n.removePlaylistQuestion,
        submitMessage: context.l10n.remove,
        onCancel: () {
          Navigator.of(context).pop();
        },
        onSubmit: () {
          Navigator.of(context).pop();

          final playlistId = playlist['ytid']?.toString() ?? '';

          if (playlistId.isEmpty) {
            logger.log('Playlist ID is missing, cannot remove playlist.');
            showToast(context, context.l10n.error);
            return;
          }

          removeUserPlaylistEntry(playlist);
          if (offlinePlaylistService.isPlaylistDownloaded(playlistId)) {
            unawaited(offlinePlaylistService.removeOfflinePlaylist(playlistId));
          }
        },
      );
    },
  );

  void _showCreateFolderDialog() => showDialog(
    context: context,
    builder: (BuildContext context) {
      var folderName = '';
      final isDark = Theme.of(context).brightness == Brightness.dark;

      return CupertinoAlertDialog(
        title: Text(context.l10n.createFolder),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            placeholder: context.l10n.folderName,
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
              if (folderName.trim().isNotEmpty) {
                final result =
                    createPlaylistFolder(folderName.trim(), context);
                showToast(context, result);
              } else {
                showToast(context, context.l10n.enterFolderName);
              }
              Navigator.pop(context);
            },
            child: Text(context.l10n.create),
          ),
        ],
      );
    },
  );

  void _showDeleteFolderDialog(Map folder) => showDialog(
    context: context,
    builder: (BuildContext context) {
      return ConfirmationDialog(
        confirmationMessage: context.l10n.deleteFolderQuestion,
        submitMessage: context.l10n.delete,
        onCancel: () {
          Navigator.of(context).pop();
        },
        onSubmit: () {
          final result = deletePlaylistFolder(folder['id'], context);
          Navigator.of(context).pop();
          showToast(context, result);
        },
      );
    },
  );
}

int? _playlistCountFromTrackCount(dynamic trackCount) {
  if (trackCount is int) return trackCount;
  if (trackCount is! String || trackCount.isEmpty) return null;
  final withUnit = RegExp(
    r'(\d[\d,]*)\s*(songs?|tracks?)',
    caseSensitive: false,
  ).firstMatch(trackCount);
  final raw = withUnit?.group(1) ??
      RegExp(r'(\d[\d,]*)').firstMatch(trackCount)?.group(1);
  if (raw == null) return null;
  return int.tryParse(raw.replaceAll(',', ''));
}
