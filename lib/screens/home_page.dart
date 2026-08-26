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
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/constants/app_constants.dart';
import 'package:musify/main.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/services/youtube_auth_service.dart';
import 'package:musify/services/youtube_music_sync_service.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';
import 'package:musify/widgets/playlist_cube.dart';
import 'package:musify/widgets/section_header.dart';

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
    HapticFeedback.mediumImpact();
    if (YouTubeAuthService().isSignedIn.value) {
      await YouTubeMusicSyncService().fullSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          'Musified',
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: _handleRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: commonSingleChildScrollViewPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLikedSongsSection(),
              _buildMostPlayedSection(),
              _buildPlaylistsSection(),
              _buildEmptyStateIfNeeded(),
              const MiniPlayerBottomSpace(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLikedSongsSection() {
    return ValueListenableBuilder<List>(
      valueListenable: userLikedSongsList,
      builder: (context, rawSongs, _) {
        final songs = rawSongs.whereType<Map>().toList();
        if (songs.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Favorites',
              icon: CupertinoIcons.heart_fill,
            ),
            const SizedBox(height: 8),
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

  Widget _buildMostPlayedSection() {
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
            SectionHeader(
              title: 'Heavy Rotation',
              icon: CupertinoIcons.flame_fill,
            ),
            const SizedBox(height: 8),
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

  Widget _buildPlaylistsSection() {
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
            SectionHeader(
              title: 'Playlists & Mixes',
              icon: CupertinoIcons.music_albums_fill,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: playlistHeight,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: allPlaylists.length,
                itemBuilder: (context, index) {
                  final playlist = allPlaylists[index];
                  final id = playlist['playlistId'] ??
                      playlist['ytid'] ??
                      playlist['id'];
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

  Widget _buildEmptyStateIfNeeded() {
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

        final colorScheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.music_note_2,
                  size: 56,
                  color: colorScheme.primary.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your Music Library',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Songs you like and play will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
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
  const _HomeSongCard({required this.song, required this.onTap});
  final Map song;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = song['title']?.toString() ?? 'Unknown';
    final artist = song['artist']?.toString() ?? '';
    final imageUrl =
        song['highResImage'] ?? song['image'] ?? song['lowResImage'] ?? '';

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
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              child: const Icon(
                                CupertinoIcons.music_note,
                                size: 36,
                              ),
                            ),
                          )
                        : Container(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            child: const Icon(
                              CupertinoIcons.music_note,
                              size: 36,
                            ),
                          ),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.play_fill,
                      size: 13,
                      color: Colors.white,
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
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.8),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
