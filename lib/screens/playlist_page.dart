import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:musified/constants/app_constants.dart';
import 'package:musified/extensions/l10n.dart';
import 'package:musified/main.dart';
import 'package:musified/services/artist_service.dart';
import 'package:musified/services/data_manager.dart';
import 'package:musified/services/playlist_download_service.dart';
import 'package:musified/services/playlist_sharing.dart';
import 'package:musified/services/playlists_manager.dart';
import 'package:musified/services/settings_manager.dart';
import 'package:musified/theme/app_themes.dart';
import 'package:musified/theme/musified_style.dart';
import 'package:musified/utilities/flutter_toast.dart';
import 'package:musified/utilities/playlist_utils.dart';
import 'package:musified/utilities/song_filtering.dart';
import 'package:musified/utilities/sort_utils.dart';
import 'package:musified/widgets/edit_playlist_dialog.dart';
import 'package:musified/widgets/mini_player_bottom_space.dart';
import 'package:musified/widgets/playlist_cube.dart';
import 'package:musified/widgets/playlist_page/add_to_playlist_button.dart';
import 'package:musified/widgets/playlist_page/download_button.dart';
import 'package:musified/widgets/playlist_page/empty_playlist_state.dart';
import 'package:musified/widgets/playlist_page/like_button.dart';
import 'package:musified/widgets/playlist_page/playlist_action_buttons.dart';
import 'package:musified/widgets/playlist_page/playlist_header.dart';
import 'package:musified/widgets/song_tile.dart';
import 'package:musified/widgets/sort_chips.dart';

enum PlaylistSortType { default_, title, artist, dateAdded }

class PlaylistPage extends StatefulWidget {
  const PlaylistPage({
    super.key,
    this.playlistId,
    this.playlistData,
    this.cubeIcon = CupertinoIcons.list_bullet,
    this.isArtist = false,
  });

  final String? playlistId;
  final dynamic playlistData;
  final IconData cubeIcon;
  final bool isArtist;

  @override
  _PlaylistPageState createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  dynamic _playlist;
  List<dynamic> _originalPlaylistList = []; // Keep original order separately

  bool _isInitializingPlaylist = true;

  String? get _resolvedPlaylistId =>
      _playlist?['ytid']?.toString() ??
      widget.playlistData?['ytid']?.toString() ??
      widget.playlistId;

  // Sorting
  late PlaylistSortType _sortType = PlaylistSortType.values.firstWhere(
    (e) => e.name == playlistSortSetting,
    orElse: () => PlaylistSortType.default_,
  );

  // Search
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier('');
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  List _getSourceList(String searchQuery) {
    final list = _playlist?['list'] as List? ?? [];
    return filterSongsByQuery(list, searchQuery);
  }

  bool get _isArtistCatalogFailed =>
      widget.isArtist && _playlist?['catalogStatus'] == 'failed';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _initializePlaylist();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchQueryNotifier.dispose();
    super.dispose();
  }

  Future<void> _initializePlaylist() async {
    try {
      final initialPlaylist = widget.playlistData;
      final resolvedId =
          initialPlaylist?['ytid']?.toString() ?? widget.playlistId;

      if (initialPlaylist != null) {
        _playlist = initialPlaylist;
        final playlistList = _playlist?['list'] as List?;
        final shouldFetchInitialPlaylist =
            playlistList == null || playlistList.isEmpty;
        if (shouldFetchInitialPlaylist && resolvedId != null) {
          _playlist =
              await getPlaylistInfoForWidget(
                resolvedId,
                isArtist: widget.isArtist,
                artistName: initialPlaylist?['title']?.toString(),
                artistImage: initialPlaylist?['image']?.toString(),
                sourceSongId: initialPlaylist?['sourceSongId']?.toString(),
                sourceVideoAuthor: initialPlaylist?['videoAuthor']?.toString(),
                preferredVerified: initialPlaylist?['isVerifiedArtist'] == true,
              ) ??
              initialPlaylist;
        }
      } else {
        _playlist = await getPlaylistInfoForWidget(
          resolvedId,
          isArtist: widget.isArtist,
          artistName: initialPlaylist?['title']?.toString(),
          artistImage: initialPlaylist?['image']?.toString(),
          sourceSongId: initialPlaylist?['sourceSongId']?.toString(),
          sourceVideoAuthor: initialPlaylist?['videoAuthor']?.toString(),
          preferredVerified: initialPlaylist?['isVerifiedArtist'] == true,
        );
      }

      if (_playlist != null && _playlist['list'] != null) {
        _originalPlaylistList = List<dynamic>.from(_playlist['list'] as List);
        _sortPlaylist(_sortType);
      }
    } catch (e, stackTrace) {
      logger.log(
        'Error initializing playlist:',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        showToast(context, context.l10n.error);
      }
    } finally {
      _isInitializingPlaylist = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDarkMode(context);
    final navBarColor = isDark ? const Color(0xB3121214) : const Color(0xB3FFFFFF);

    return CupertinoPageScaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          _playlistTitle,
          style: const TextStyle(
            fontFamily: MusifiedStyle.displayFont,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: navBarColor,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0x26FFFFFF) : const Color(0x1F000000),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: _isInitializingPlaylist
            ? const Center(child: CupertinoActivityIndicator(radius: 14))
            : _playlist != null
                ? CustomScrollView(
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    slivers: [
                      SliverToBoxAdapter(child: _buildHeaderSection()),
                      if ((_playlist['list'] as List? ?? const []).isNotEmpty) ...[
                        ValueListenableBuilder<String>(
                          valueListenable: _searchQueryNotifier,
                          builder: (context, searchQuery, _) {
                            final sourceList = _getSourceList(searchQuery);
                            return SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final isRemovable = _playlist['source'] == 'user-created';
                                  return _buildSongListItem(
                                    sourceList[index] as Map,
                                    index,
                                    isRemovable,
                                    sourceList,
                                  );
                                },
                                childCount: sourceList.length,
                              ),
                            );
                          },
                        ),
                      ] else if (_isArtistCatalogFailed)
                        EmptyPlaylistState(message: context.l10n.error)
                      else
                        EmptyPlaylistState(
                          message: context.l10n.noSongsInPlaylist,
                        ),
                      const SliverMiniPlayerBottomSpace(),
                    ],
                  )
                : Center(child: EmptyPlaylistState(message: context.l10n.error)),
      ),
    );
  }

  String get _playlistTitle {
    final rawTitle = _playlist?['title']?.toString() ??
        widget.playlistData?['title']?.toString() ??
        '';
    return widget.isArtist ? normalizeArtistDisplayTitle(rawTitle) : rawTitle;
  }

  Widget _buildPlaylistImage() {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isLandscape = screenWidth > MediaQuery.sizeOf(context).height;
    final basePlaylist = _playlist ?? widget.playlistData ?? const {};
    final playlist = widget.isArtist
        ? {
            ...basePlaylist,
            'image': normalizeArtistThumbnailUrl(
              basePlaylist['image']?.toString(),
            ),
          }
        : basePlaylist;
    return GestureDetector(
      onTap: () {
        final currentPlaylist = _playlist ?? widget.playlistData;
        final songs = currentPlaylist?['list'] as List? ?? [];
        if (songs.isNotEmpty) {
          HapticFeedback.selectionClick();
          audioHandler.playPlaylistSong(
            playlist: currentPlaylist,
            songIndex: 0,
          );
        }
      },
      child: PlaylistCube(
        playlist,
        size: isLandscape ? 250 : screenWidth / commonPlaylistArtworkDivision,
        cubeIcon: widget.cubeIcon,
        showTypeLabel: false,
      ),
    );
  }

  Widget _buildHeaderSection() {
    final playlist = _playlist ?? widget.playlistData ?? const {};
    final songsLength = (playlist['list'] as List? ?? const []).length;
    final isUserCreated = playlist['source'] == 'user-created';
    final hasSecondaryActions =
        (widget.playlistId != null && !isUserCreated && !offlineMode.value) ||
        !offlineMode.value ||
        isUserCreated;

    return Column(
      children: [
        PlaylistHeader(
          _buildPlaylistImage(),
          _playlistTitle,
          songsLength: songsLength,
          isAlbum: playlist['isAlbum'] == true,
          isArtist: widget.isArtist,
          showImage: false,
          showTitle: false,
        ),
        if (songsLength > 0)
          PlaylistActionButtons(
            onPlay: () => audioHandler.playPlaylistSong(
              playlist: playlist,
              songIndex: 0,
            ),
            onShuffle: () async {
              final songs = playlist['list'] as List? ?? [];
              if (songs.isEmpty) return;
              await audioHandler.addPlaylistToQueue(
                List<Map>.from(songs.whereType<Map>())..shuffle(),
                replace: true,
                startIndex: 0,
                resetShuffle: false,
              );
            },
          ),
        if (hasSecondaryActions) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 5,
            children: [
              if (widget.playlistId != null &&
                  !isUserCreated &&
                  !offlineMode.value)
                PlaylistLikeButton(
                  playlistId: _resolvedPlaylistId ?? '',
                  playlistData: () => _playlist,
                ),
              if (!offlineMode.value) ...[
                PlaylistAddToPlaylistButton(
                  resolvePlaylist: () async => _playlist,
                ),
                if (!isUserCreated) _buildSyncButton(),
              ],
              if (songsLength > 0) _buildDownloadButton(),
              if (isUserCreated) ...[_buildShareButton(), _buildEditButton()],
            ],
          ),
        ],
        if (songsLength > 1) ...[
          const SizedBox(height: 12),
          SortChips<PlaylistSortType>(
            currentSortType: _sortType,
            sortTypes: PlaylistSortType.values,
            sortTypeToString: _getSortTypeDisplayText,
            onSelected: (type) {
              setState(() {
                _sortType = type;
                addOrUpdateData<String>(
                  'settings',
                  'playlistSortType',
                  type.name,
                );
                playlistSortSetting = type.name;
                _sortPlaylist(type);
              });
            },
          ),
        ],
        if (songsLength > 0) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CupertinoSearchTextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              placeholder: 'Search in playlist',
              onChanged: (value) => _searchQueryNotifier.value = value,
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildShareButton() {
    final isDark = isAppDarkMode(context);
    return CupertinoButton(
      padding: const EdgeInsets.all(10),
      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
      borderRadius: BorderRadius.circular(22),
      onPressed: () async {
        try {
          final encodedPlaylist = PlaylistSharingService.encodePlaylist(
            _playlist,
          );
          final url = 'musified://playlist/custom/$encodedPlaylist';
          await Clipboard.setData(ClipboardData(text: url));
          if (mounted) {
            showToast(context, 'Playlist link copied');
          }
        } catch (e, stackTrace) {
          logger.log(
            'Error sharing playlist',
            error: e,
            stackTrace: stackTrace,
          );
          if (mounted) {
            showToast(context, 'Unable to share playlist');
          }
        }
      },
      child: const Icon(CupertinoIcons.share, size: 20, color: Color(0xFFFF2D55)),
    );
  }

  Widget _buildSyncButton() {
    final isDark = isAppDarkMode(context);
    return CupertinoButton(
      padding: const EdgeInsets.all(10),
      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
      borderRadius: BorderRadius.circular(22),
      onPressed: _handleSyncPlaylist,
      child: const Icon(CupertinoIcons.arrow_2_circlepath, size: 20, color: Color(0xFFFF2D55)),
    );
  }

  Widget _buildEditButton() {
    final isDark = isAppDarkMode(context);
    return CupertinoButton(
      padding: const EdgeInsets.all(10),
      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
      borderRadius: BorderRadius.circular(22),
      onPressed: () async {
        final result = await showCupertinoDialog<Map?>(
          context: context,
          builder: (context) => EditPlaylistDialog(playlistData: _playlist),
        );

        if (result != null) {
          final resolvedPlaylistYtid =
              _playlist['ytid']?.toString() ?? widget.playlistId;
          if (resolvedPlaylistYtid == null ||
              resolvedPlaylistYtid.isEmpty ||
              resolvedPlaylistYtid == 'null') {
            showToast(context, context.l10n.error);
            return;
          }

          final updatedPlaylist = {
            ..._playlist,
            ...result,
            'ytid': resolvedPlaylistYtid,
            'source': _playlist['source'] ?? result['source'],
            'list': result['list'] ?? _playlist['list'],
          };

          // Search root list first, then inside folders.
          final rootIndex = userCustomPlaylists.value.indexWhere(
            (p) => p['ytid'] == resolvedPlaylistYtid,
          );

          if (rootIndex != -1) {
            final updatedPlaylists = List<Map>.from(userCustomPlaylists.value);
            updatedPlaylists[rootIndex] = updatedPlaylist;
            userCustomPlaylists.value = updatedPlaylists;
            unawaited(
              addOrUpdateData<List>(
                'user',
                'customPlaylists',
                userCustomPlaylists.value,
              ),
            );
          } else {
            // Playlist lives inside a folder - update it there.
            final updatedFolders = List<Map>.from(userPlaylistFolders.value);
            for (final folder in updatedFolders) {
              final folderPlaylists = List<Map>.from(
                folder['playlists'] as List? ?? [],
              );
              final fi = folderPlaylists.indexWhere(
                (p) => p['ytid'] == resolvedPlaylistYtid,
              );
              if (fi != -1) {
                folderPlaylists[fi] = updatedPlaylist;
                folder['playlists'] = folderPlaylists;
                break;
              }
            }
            userPlaylistFolders.value = updatedFolders;
            unawaited(
              addOrUpdateData<List>(
                'user',
                'playlistFolders',
                userPlaylistFolders.value,
              ),
            );
          }

          // Update offline playlist if it exists
          unawaited(syncOfflinePlaylistMetadata(updatedPlaylist));

          setState(() {
            _playlist = updatedPlaylist;
            _originalPlaylistList = List<dynamic>.from(
              updatedPlaylist['list'] as List? ?? const [],
            );
            _sortPlaylist(_sortType);
          });
          showToast(context, 'Playlist updated');
        }
      },
      child: const Icon(CupertinoIcons.pencil, size: 20, color: Color(0xFFFF2D55)),
    );
  }

  Widget _buildDownloadButton() {
    final playlistId = _playlist?['ytid']?.toString() ?? widget.playlistId;
    if (playlistId == null || playlistId.isEmpty) {
      return const SizedBox.shrink();
    }

    return PlaylistDownloadButton(
      playlistId: playlistId,
      songs: _playlist?['list'] as List? ?? const [],
      resolvePlaylist: () async => _playlist,
    );
  }

  void _handleSyncPlaylist() async {
    final playlistId = _playlist?['ytid']?.toString();
    if (playlistId == null || playlistId.isEmpty) return;

    if (offlineMode.value &&
        offlinePlaylistService.isPlaylistDownloaded(playlistId)) {
      if (mounted) {
        showToast(context, context.l10n.removeOffline);
      }
      return;
    }

    // Neither an artist nor a release is one of the built-in playlists
    // updatePlaylistList knows: they are refreshed by dropping the cache entry
    // they were read from, and they report the refresh themselves.
    final isCachedPage = widget.isArtist || playlistId.startsWith('MPRE');
    final updated = widget.isArtist
        ? await getPlaylistInfoForWidget(
            playlistId,
            isArtist: true,
            artistName: _playlist?['title']?.toString(),
            artistImage: _playlist?['image']?.toString(),
            preferredVerified: _playlist?['isVerifiedArtist'] == true,
            forceRefresh: true,
          )
        : isCachedPage
        ? await getPlaylistInfoForWidget(playlistId, forceRefresh: true)
        : await updatePlaylistList(context, playlistId);
    if (updated?['catalogStatus'] == 'failed') {
      if (mounted) showToast(context, context.l10n.error);
      return;
    }
    if (updated != null && mounted) {
      setState(() {
        _playlist = updated;
        _originalPlaylistList = List<dynamic>.from(
          _playlist['list'] as List? ?? const [],
        );
        _sortPlaylist(_sortType);
      });
      if (isCachedPage) {
        showToast(context, context.l10n.playlistUpdated);
      }
    }
  }

  void _updateSongsListOnRemove(int indexOfRemovedSong, dynamic songToRemove) {
    _originalPlaylistList.removeWhere((s) => s['ytid'] == songToRemove['ytid']);
    final playlistId = _playlist['ytid'];
    if (mounted) {
      setState(() {});
      showToastWithButton(
        context,
        context.l10n.songRemoved,
        context.l10n.undo.toUpperCase(),
        () {
          final result = addSongInCustomPlaylist(
            context,
            playlistId,
            songToRemove,
            indexToInsert: indexOfRemovedSong,
          );
          if (result == context.l10n.songAdded &&
              !_originalPlaylistList.any(
                (song) => song['ytid'] == songToRemove['ytid'],
              )) {
            final safeIndex = indexOfRemovedSong.clamp(
              0,
              _originalPlaylistList.length,
            );
            _originalPlaylistList.insert(safeIndex, songToRemove);
            _sortPlaylist(_sortType);
          }
          if (mounted) setState(() {});
        },
      );
    } else {
      logger.log(
        '(_updateSongsListOnRemove): Widget not mounted, cannot show undo toast.',
      );
    }
  }

  String _getSortTypeDisplayText(PlaylistSortType type) {
    switch (type) {
      case PlaylistSortType.default_:
        return context.l10n.default_;
      case PlaylistSortType.title:
        return context.l10n.name;
      case PlaylistSortType.artist:
        return context.l10n.artist;
      case PlaylistSortType.dateAdded:
        return context.l10n.dateAdded;
    }
  }

  void _sortPlaylist(PlaylistSortType type) {
    if (_playlist == null || _playlist['list'] == null) return;

    switch (type) {
      case PlaylistSortType.default_:
        // Restore original order from backup
        _playlist['list'] = List<dynamic>.from(_originalPlaylistList);
        break;
      case PlaylistSortType.title:
        final playlist = List<dynamic>.from(_playlist['list']);
        sortSongsByKey(playlist, 'title');
        _playlist['list'] = playlist;
        break;
      case PlaylistSortType.artist:
        final playlist = List<dynamic>.from(_playlist['list']);
        sortSongsByKey(playlist, 'artist');
        _playlist['list'] = playlist;
        break;
      case PlaylistSortType.dateAdded:
        _playlist['list'] = List<dynamic>.from(_originalPlaylistList.reversed);
        break;
    }
  }

  Widget _buildSongListItem(
    Map song,
    int index,
    bool isRemovable,
    List sourceList,
  ) {
    final isSearching = _searchQueryNotifier.value.isNotEmpty;
    final fullIndex = isSearching
        ? PlaylistUtils.findSongIndexByYtid(_playlist, song['ytid'])
        : index;

    if (isSearching && fullIndex == -1) {
      logger.log('Warning: Song ${song['ytid']} not found in full playlist');
    }

    return SongTile(
      song: song,
      key: ValueKey('playlist_${song['ytid']}_$index'),
      canRemove: isRemovable && !isSearching,
      onRemove: (isRemovable && !isSearching)
          ? () {
              if (removeSongFromPlaylist(
                _playlist,
                song,
                removeOneAtIndex: index,
              )) {
                _updateSongsListOnRemove(index, song);
              }
            }
          : null,
      onTap: () {
        HapticFeedback.selectionClick();
        audioHandler.playPlaylistSong(
          playlist: _playlist,
          songIndex: fullIndex != -1 ? fullIndex : index,
        );
      },
    );
  }
}
