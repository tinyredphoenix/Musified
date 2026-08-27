import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:musified/constants/app_constants.dart';
import 'package:musified/main.dart' show audioHandler;
import 'package:musified/services/common_services.dart';
import 'package:musified/services/data_manager.dart';
import 'package:musified/services/settings_manager.dart';
import 'package:musified/theme/app_themes.dart';
import 'package:musified/theme/musified_style.dart';
import 'package:musified/utilities/flutter_toast.dart';
import 'package:musified/utilities/song_filtering.dart';
import 'package:musified/widgets/mini_player_bottom_space.dart';
import 'package:musified/widgets/playlist_cube.dart';
import 'package:musified/widgets/playlist_page/empty_playlist_state.dart';
import 'package:musified/widgets/playlist_page/playlist_header.dart';
import 'package:musified/widgets/song_tile.dart';

enum OfflineSortType { default_, title, artist, dateAdded }

class UserSongsPage extends StatefulWidget {
  const UserSongsPage({super.key, required this.page});

  final String page;

  @override
  State<UserSongsPage> createState() => _UserSongsPageState();
}

class _UserSongsPageState extends State<UserSongsPage> {
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier('');
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  List _getDisplayList(List songsList) {
    var list = filterSongsByQuery(songsList, _searchQueryNotifier.value);
    if (widget.page == 'offline') {
      list = _sortOfflineSongsLocal(list, _getCurrentOfflineSortType());
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchQueryNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = getTitle(widget.page, context);
    final icon = getIcon(widget.page);
    final isOfflineSongs = widget.page == 'offline';
    final isDark = isAppDarkMode(context);
    final navBarColor = isDark ? const Color(0xB3121214) : const Color(0xB3FFFFFF);

    return CupertinoPageScaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          title,
          style: const TextStyle(
            fontFamily: MusifiedStyle.displayFont,
            fontWeight: FontWeight.w700,
          ),
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
        child: Padding(
          padding: commonSingleChildScrollViewPadding,
          child: ValueListenableBuilder<List>(
            valueListenable: widget.page == 'liked'
                ? userLikedSongsList
                : widget.page == 'offline'
                ? userOfflineSongs
                : userRecentlyPlayed,
            builder: (_, songsList, __) => _buildCustomScrollView(
              title,
              icon,
              songsList.length,
              isOfflineSongs,
              isDark,
            ),
          ),
        ),
      ),
    );
  }

  OfflineSortType _getCurrentOfflineSortType() {
    return OfflineSortType.values.firstWhere(
      (e) => e.name == offlineSortSetting,
      orElse: () => OfflineSortType.default_,
    );
  }

  Widget _buildCustomScrollView(
    String title,
    IconData icon,
    int songsLength,
    bool isOfflineSongs,
    bool isDark,
  ) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverToBoxAdapter(
          child: _buildHeaderSection(title, icon, songsLength, isOfflineSongs, isDark),
        ),
        buildSongList(title),
        const SliverMiniPlayerBottomSpace(),
      ],
    );
  }

  String getTitle(String page, BuildContext context) {
    return switch (page) {
      'liked' => 'Favorite Tracks',
      'offline' => 'Downloaded Songs',
      'recents' => 'Recently Played',
      _ => 'Playlist',
    };
  }

  IconData getIcon(String page) {
    return switch (page) {
      'liked' => CupertinoIcons.heart_fill,
      'offline' => CupertinoIcons.arrow_down_circle_fill,
      'recents' => CupertinoIcons.clock_fill,
      _ => CupertinoIcons.heart_fill,
    };
  }

  Widget _buildHeaderSection(
    String title,
    IconData icon,
    int songsLength,
    bool isOfflineSongs,
    bool isDark,
  ) {
    final isRecentlyPlayed = widget.page == 'recents';

    return Column(
      children: [
        PlaylistHeader(
          _buildPlaylistImage(title, icon),
          title,
          songsLength: songsLength,
          showTitle: false,
        ),
        if (songsLength > 0) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: CupertinoButton.filled(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    borderRadius: BorderRadius.circular(12),
                    onPressed: () {
                      final songsList = widget.page == 'liked'
                          ? userLikedSongsList.value
                          : widget.page == 'offline'
                          ? userOfflineSongs.value
                          : userRecentlyPlayed.value;
                      var sortedList = songsList;
                      if (isOfflineSongs) {
                        sortedList = _sortOfflineSongsLocal(
                          songsList,
                          _getCurrentOfflineSortType(),
                        );
                      }
                      final playlist = {
                        'ytid': '',
                        'title': title,
                        'source': 'user-created',
                        'list': sortedList,
                      };
                      audioHandler.playPlaylistSong(
                        playlist: playlist,
                        songIndex: 0,
                      );
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.play_fill, size: 18),
                        SizedBox(width: 8),
                        Text('Play', style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CupertinoButton(
                    color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    borderRadius: BorderRadius.circular(12),
                    onPressed: () async {
                      final songs = widget.page == 'liked'
                          ? userLikedSongsList.value
                          : widget.page == 'offline'
                          ? userOfflineSongs.value
                          : userRecentlyPlayed.value;
                      if (songs.isEmpty) return;
                      final shuffled = List<Map>.from(songs.whereType<Map>())..shuffle();
                      await audioHandler.addPlaylistToQueue(
                        shuffled,
                        replace: true,
                        startIndex: 0,
                        resetShuffle: false,
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.shuffle, size: 18, color: isDark ? CupertinoColors.white : CupertinoColors.black),
                        const SizedBox(width: 8),
                        Text(
                          'Shuffle',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? CupertinoColors.white : CupertinoColors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isRecentlyPlayed) ...[
            const SizedBox(height: 8),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () async {
                await deleteData('user', 'recentlyPlayed');
                userRecentlyPlayed.value = [];
                if (mounted) showToast(context, 'History cleared');
              },
              child: const Text('Clear History', style: TextStyle(color: CupertinoColors.destructiveRed, fontSize: 14)),
            ),
          ],
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildPlaylistImage(String title, IconData icon) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isLandscape = screenWidth > MediaQuery.sizeOf(context).height;
    return PlaylistCube(
      {'title': title},
      size: isLandscape ? 250 : screenWidth / commonPlaylistArtworkDivision,
      cubeIcon: icon,
      showTypeLabel: false,
    );
  }

  Widget buildSongList(String title) {
    final isLikedSongs = widget.page == 'liked';
    final isRecentSongs = widget.page == 'recents';

    return ValueListenableBuilder<List>(
      valueListenable: isLikedSongs
          ? userLikedSongsList
          : widget.page == 'offline'
          ? userOfflineSongs
          : userRecentlyPlayed,
      builder: (context, rawSongs, _) {
        final songs = _getDisplayList(rawSongs);
        if (songs.isEmpty) {
          return EmptyPlaylistState(
            icon: getIcon(widget.page),
            message: 'No tracks found in $title',
          );
        }

        final playlist = {
          'ytid': '',
          'title': title,
          'source': 'user-created',
          'list': songs,
        };

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final song = songs[index] as Map;
              return SongTile(
                song: song,
                key: ValueKey('user_song_${song['ytid']}_$index'),
                isRecent: isRecentSongs,
                onTap: () {
                  HapticFeedback.selectionClick();
                  audioHandler.playPlaylistSong(
                    playlist: playlist,
                    songIndex: index,
                  );
                },
              );
            },
            childCount: songs.length,
          ),
        );
      },
    );
  }

  List _sortOfflineSongsLocal(List list, OfflineSortType type) {
    final sortedList = List<dynamic>.from(list);
    switch (type) {
      case OfflineSortType.default_:
        return sortedList;
      case OfflineSortType.title:
        sortedList.sort((a, b) {
          final titleA = (a['title'] ?? '').toString().toLowerCase();
          final titleB = (b['title'] ?? '').toString().toLowerCase();
          return titleA.compareTo(titleB);
        });
        break;
      case OfflineSortType.artist:
        sortedList.sort((a, b) {
          final artistA = (a['artist'] ?? '').toString().toLowerCase();
          final artistB = (b['artist'] ?? '').toString().toLowerCase();
          return artistA.compareTo(artistB);
        });
        break;
      case OfflineSortType.dateAdded:
        sortedList.sort((a, b) {
          final dateA = a['dateAdded'] as int? ?? 0;
          final dateB = b['dateAdded'] as int? ?? 0;
          return dateB.compareTo(dateA);
        });
        break;
    }
    return sortedList;
  }
}
