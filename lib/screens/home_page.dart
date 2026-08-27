import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:musified/constants/app_constants.dart';
import 'package:musified/main.dart';
import 'package:musified/services/common_services.dart';
import 'package:musified/services/playlists_manager.dart';
import 'package:musified/services/settings_manager.dart';
import 'package:musified/services/youtube_auth_service.dart';
import 'package:musified/services/youtube_music_sync_service.dart';
import 'package:musified/theme/app_themes.dart';
import 'package:musified/theme/musified_style.dart';
import 'package:musified/widgets/mini_player_bottom_space.dart';
import 'package:musified/widgets/playlist_cube.dart';
import 'package:musified/widgets/section_header.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    announcementURL.value = null;
  }

  Future<void> _handleRefresh() async {
    unawaited(HapticFeedback.mediumImpact());
    if (YouTubeAuthService().isSignedIn.value) {
      await YouTubeMusicSyncService().fullSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDarkMode(context);
    final navBarColor = isDark ? const Color(0xB3121214) : const Color(0xB3FFFFFF);

    return CupertinoPageScaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text(
              'Musified',
              style: TextStyle(
                fontFamily: MusifiedStyle.displayFont,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
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
          CupertinoSliverRefreshControl(
            onRefresh: _handleRefresh,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: commonSingleChildScrollViewPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  _buildLikedSongsSection(isDark),
                  _buildMostPlayedSection(isDark),
                  _buildPlaylistsSection(isDark),
                  _buildEmptyStateIfNeeded(isDark),
                  const MiniPlayerBottomSpace(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLikedSongsSection(bool isDark) {
    return ValueListenableBuilder<List>(
      valueListenable: userLikedSongsList,
      builder: (context, rawSongs, _) {
        final songs = rawSongs.whereType<Map>().toList();
        if (songs.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Favorites',
              icon: CupertinoIcons.heart_fill,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 205,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: songs.length > 25 ? 25 : songs.length,
                itemBuilder: (context, index) {
                  final song = songs[index];
                  return _HomeSongCard(
                    song: song,
                    isDark: isDark,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      audioHandler.playPlaylistSong(
                        playlist: {'title': 'Favorites', 'list': songs},
                        songIndex: index,
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildMostPlayedSection(bool isDark) {
    return ValueListenableBuilder<List>(
      valueListenable: userRecentlyPlayed,
      builder: (context, rawSongs, _) {
        final songs = rawSongs.whereType<Map>().toList();
        if (songs.isEmpty) return const SizedBox.shrink();

        final displayCount = songs.length.clamp(0, 25);
        final displayList = songs.take(displayCount).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Heavy Rotation',
              icon: CupertinoIcons.flame_fill,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 205,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: displayList.length,
                itemBuilder: (context, index) {
                  final song = displayList[index];
                  return _HomeSongCard(
                    song: song,
                    isDark: isDark,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      audioHandler.playPlaylistSong(
                        playlist: {
                          'title': 'Heavy Rotation',
                          'list': displayList,
                        },
                        songIndex: index,
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildPlaylistsSection(bool isDark) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        userCustomPlaylists,
        userLikedPlaylists,
        YouTubeMusicSyncService().ytMusicPlaylists,
      ]),
      builder: (context, _) {
        final allPlaylists = <Map>[
          ...userCustomPlaylists.value,
          ...userLikedPlaylists.value,
          ...YouTubeMusicSyncService().ytMusicPlaylists.value,
        ];

        if (allPlaylists.isEmpty) return const SizedBox.shrink();

        final playlistHeight = MediaQuery.sizeOf(context).height * 0.25 / 1.1;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Playlists & Mixes',
              icon: CupertinoIcons.music_albums_fill,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: playlistHeight,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: allPlaylists.length,
                itemBuilder: (context, index) {
                  final playlist = allPlaylists[index];
                  final id = playlist['playlistId'] ?? playlist['ytid'] ?? playlist['id'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        if (id != null) {
                          context.push(
                            '/home/playlist/$id',
                            extra: {
                              'title': playlist['title'],
                              'image': playlist['image'],
                            },
                          );
                        }
                      },
                      child: PlaylistCube(playlist, size: playlistHeight),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildEmptyStateIfNeeded(bool isDark) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        userLikedSongsList,
        userRecentlyPlayed,
        userCustomPlaylists,
        userLikedPlaylists,
        YouTubeMusicSyncService().ytMusicPlaylists,
      ]),
      builder: (context, _) {
        final hasAny = userLikedSongsList.value.isNotEmpty ||
            userRecentlyPlayed.value.isNotEmpty ||
            userCustomPlaylists.value.isNotEmpty ||
            userLikedPlaylists.value.isNotEmpty ||
            YouTubeMusicSyncService().ytMusicPlaylists.value.isNotEmpty;

        if (hasAny) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons.music_note_2,
                  size: 56,
                  color: Color(0xFFFF2D55),
                ),
                const SizedBox(height: 16),
                Text(
                  'Your Music Library',
                  style: TextStyle(
                    fontFamily: MusifiedStyle.displayFont,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? CupertinoColors.white : CupertinoColors.black,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Songs you like and play will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: MusifiedStyle.uiFont,
                    fontSize: 14,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HomeSongCard extends StatelessWidget {
  const _HomeSongCard({
    required this.song,
    required this.onTap,
    required this.isDark,
  });

  final Map song;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final title = song['title']?.toString() ?? 'Unknown';
    final artist = song['artist']?.toString() ?? '';
    final imageUrl = song['highResImage'] ?? song['image'] ?? song['lowResImage'] ?? '';
    final primaryColor = isDark ? CupertinoColors.white : CupertinoColors.black;
    final secondaryColor = CupertinoColors.systemGrey;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: imageUrl.toString().isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl.toString(),
                            fit: BoxFit.cover,
                            memCacheWidth: 280,
                            memCacheHeight: 280,
                            errorWidget: (_, __, ___) => Container(
                              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                              child: const Icon(
                                CupertinoIcons.music_note,
                                size: 36,
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                          )
                        : Container(
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                            child: const Icon(
                              CupertinoIcons.music_note,
                              size: 36,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0x99000000),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.play_fill,
                      size: 13,
                      color: CupertinoColors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: MusifiedStyle.uiFont,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: MusifiedStyle.uiFont,
                fontSize: 12,
                color: secondaryColor,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
