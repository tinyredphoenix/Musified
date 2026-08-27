import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:musified/constants/app_constants.dart';
import 'package:musified/services/common_services.dart';
import 'package:musified/services/playlist_download_service.dart';
import 'package:musified/services/playlists_manager.dart';
import 'package:musified/services/router_service.dart';
import 'package:musified/services/settings_manager.dart';
import 'package:musified/services/youtube_auth_service.dart';
import 'package:musified/services/youtube_music_sync_service.dart';
import 'package:musified/theme/app_themes.dart';
import 'package:musified/theme/musified_style.dart';
import 'package:musified/utilities/flutter_toast.dart';
import 'package:musified/utilities/playlist_dialogs.dart';
import 'package:musified/widgets/mini_player_bottom_space.dart';
import 'package:musified/widgets/playlist_bar.dart';
import 'package:musified/widgets/section_header.dart';

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
    final isDark = isAppDarkMode(context);
    final navBarColor = isDark ? const Color(0xB3121214) : const Color(0xB3FFFFFF);

    return CupertinoPageScaffold(
      backgroundColor: musifiedCanvas(isDark),
      child: AnimatedBuilder(
        animation: Listenable.merge([
          pinnedPlaylistIds,
          offlineMode,
          usePureBlackColor,
          userCustomPlaylists,
          userPlaylistFolders,
          offlinePlaylistService.offlinePlaylists,
          userLikedPlaylists,
          onlinePlaylists,
          userPlaylists,
          userOfflineSongs,
        ]),
        builder: (context, _) {
          return CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              CupertinoSliverNavigationBar(
                largeTitle: const Text(
                  'Library',
                  style: TextStyle(
                    fontFamily: MusifiedStyle.displayFont,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                backgroundColor: navBarColor,
                trailing: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => showCreatePlaylistDialog(context),
                  child: const Icon(CupertinoIcons.plus, size: 22),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0x26FFFFFF) : const Color(0x1F000000),
                    width: 0.5,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: commonSingleChildScrollViewPadding,
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      ..._buildTopLibrarySections(isDark),
                      if (!offlineMode.value) ..._buildYouTubePlaylistsSections(isDark),
                      ..._buildCustomPlaylistsSections(isDark),
                      const MiniPlayerBottomSpace(),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildTopLibrarySections(bool isDark) {
    return [
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            ValueListenableBuilder<List>(
              valueListenable: userOfflineSongs,
              builder: (context, offline, _) {
                return PlaylistBar(
                  'Downloaded Songs',
                  subtitle: '${offline.length} tracks',
                  onPressed: () => NavigationManager.router.go('/library/userSongs/offline'),
                  cubeIcon: CupertinoIcons.arrow_down_circle_fill,
                  borderRadius: commonCustomBarRadiusFirst,
                  showBuildActions: false,
                );
              },
            ),
            ValueListenableBuilder<List>(
              valueListenable: userLikedSongsList,
              builder: (context, liked, _) {
                return PlaylistBar(
                  'Favorite Tracks',
                  subtitle: '${liked.length} tracks',
                  onPressed: () => NavigationManager.router.go('/library/userSongs/liked'),
                  cubeIcon: CupertinoIcons.heart_fill,
                  showBuildActions: false,
                );
              },
            ),
            ValueListenableBuilder<List>(
              valueListenable: userRecentlyPlayed,
              builder: (context, recents, _) {
                return PlaylistBar(
                  'Recently Played',
                  subtitle: '${recents.length} tracks',
                  onPressed: () => NavigationManager.router.go('/library/userSongs/recents'),
                  cubeIcon: CupertinoIcons.clock_fill,
                  borderRadius: commonCustomBarRadiusLast,
                  showBuildActions: false,
                );
              },
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildYouTubePlaylistsSections(bool isDark) {
    return [
      ValueListenableBuilder<bool>(
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
                  child: const Icon(CupertinoIcons.refresh, size: 20),
                  onPressed: () {
                    unawaited(YouTubeMusicSyncService().fullSync());
                    showToast(context, 'Syncing with YouTube Music...');
                  },
                ),
              ),
              const SizedBox(height: 10),
              ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: YouTubeMusicSyncService().ytMusicPlaylists,
                builder: (context, playlists, _) {
                  if (playlists.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No playlists found'),
                    );
                  }
                  return SizedBox(
                    height: 190,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: playlists.length,
                      itemBuilder: (context, index) {
                        final playlist = playlists[index];
                        final title = playlist['title'] ?? 'Unknown';
                        final image = playlist['image'] ?? '';
                        final id = playlist['playlistId']?.toString();

                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
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
                            margin: const EdgeInsets.only(right: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: image.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: image,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) => Container(
                                              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                                              child: const Icon(CupertinoIcons.music_albums, color: CupertinoColors.systemGrey),
                                            ),
                                          )
                                        : Container(
                                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                                            child: const Icon(CupertinoIcons.music_albums, color: CupertinoColors.systemGrey),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: MusifiedStyle.uiFont,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? CupertinoColors.white : CupertinoColors.black,
                                  ),
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
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    ];
  }

  List<Widget> _buildCustomPlaylistsSections(bool isDark) {
    final custom = userCustomPlaylists.value;
    if (custom.isEmpty) return [];

    return [
      const SectionHeader(
        title: 'Custom Playlists',
        icon: CupertinoIcons.folder_fill,
      ),
      const SizedBox(height: 8),
      ...custom.map((p) => PlaylistBar(
        p['title']?.toString() ?? 'Playlist',
        playlistData: p,
      )),
    ];
  }
}
