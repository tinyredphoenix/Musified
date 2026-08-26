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

import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/main.dart';
import 'package:musify/widgets/flip_card.dart';
import 'package:musify/widgets/now_playing/bottom_actions_row.dart';
import 'package:musify/widgets/now_playing/now_playing_artwork.dart';
import 'package:musify/widgets/now_playing/now_playing_controls.dart';
import 'package:musify/widgets/queue_list_view.dart';
import 'package:musify/widgets/song_artwork.dart';

class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key});

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  final _lyricsController = FlipCardController();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isLargeScreen = size.width > 800 && size.height > 600;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = size.width;
    final baseIconSize = screenWidth < 360
        ? 36.0
        : screenWidth < 400
        ? 40.0
        : 44.0;
    final miniIconSize = screenWidth < 360 ? 18.0 : 22.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          StreamBuilder<MediaItem?>(
            stream: audioHandler.mediaItem,
            builder: (context, snapshot) {
              final metadata = snapshot.data;
              if (metadata == null) return const SizedBox.shrink();
              return Positioned.fill(
                child: SongArtworkWidget(
                  metadata: metadata,
                  size: size.height,
                  errorWidgetIconSize: size.width / 8,
                  borderRadius: 0,
                ),
              );
            },
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(
                color: theme.brightness == Brightness.dark
                    ? Colors.black.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ),
          SafeArea(
            child: StreamBuilder<MediaItem?>(
              stream: audioHandler.mediaItem,
              builder: (context, snapshot) {
                final metadata = snapshot.data;
                if (metadata == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return Column(
                  children: [
                    _buildAppBar(context, colorScheme),
                    Expanded(
                      child: isLargeScreen
                          ? _DesktopLayout(
                              metadata: metadata,
                              size: size,
                              adjustedIconSize: baseIconSize,
                              adjustedMiniIconSize: miniIconSize,
                              lyricsController: _lyricsController,
                            )
                          : _MobileLayout(
                              metadata: metadata,
                              size: size,
                              adjustedIconSize: baseIconSize,
                              adjustedMiniIconSize: miniIconSize,
                              isLargeScreen: isLargeScreen,
                              lyricsController: _lyricsController,
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            IconButton(
              iconSize: 22,
              icon: const Icon(CupertinoIcons.chevron_down),
              color: colorScheme.onSurface,
              tooltip: 'Close player',
              onPressed: () => Navigator.pop(context),
            ),
            const Expanded(
              child: Center(
                child: Text(
                  'Now Playing',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({
    required this.metadata,
    required this.size,
    required this.adjustedIconSize,
    required this.adjustedMiniIconSize,
    required this.lyricsController,
  });
  final MediaItem metadata;
  final Size size;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;
  final FlipCardController lyricsController;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Expanded(
                  flex: 5,
                  child: Center(
                    child: NowPlayingArtwork(
                      size: size,
                      metadata: metadata,
                      lyricsController: lyricsController,
                    ),
                  ),
                ),
                if (!(metadata.extras?['isLive'] ?? false))
                  Expanded(
                    flex: 4,
                    child: NowPlayingControls(
                      size: size,
                      audioId: metadata.extras?['ytid'],
                      adjustedIconSize: adjustedIconSize,
                      adjustedMiniIconSize: adjustedMiniIconSize,
                      metadata: metadata,
                    ),
                  ),
                BottomActionsRow(
                  metadata: metadata,
                  iconSize: adjustedMiniIconSize,
                  isLargeScreen: true,
                  lyricsController: lyricsController,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        const Expanded(child: QueueWidget()),
      ],
    );
  }
}

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({
    required this.metadata,
    required this.size,
    required this.adjustedIconSize,
    required this.adjustedMiniIconSize,
    required this.isLargeScreen,
    required this.lyricsController,
  });
  final MediaItem metadata;
  final Size size;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;
  final bool isLargeScreen;
  final FlipCardController lyricsController;

  @override
  Widget build(BuildContext context) {
    final isLandscape = size.width > size.height;

    if (isLandscape) {
      return _buildLandscapeLayout(context);
    }
    return _buildPortraitLayout(context);
  }

  Widget _buildPortraitLayout(BuildContext context) {
    final isLive = metadata.extras?['isLive'] ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Expanded(
            flex: 7,
            child: Center(
              child: NowPlayingArtwork(
                size: size,
                metadata: metadata,
                lyricsController: lyricsController,
              ),
            ),
          ),
          if (!isLive)
            Expanded(
              flex: 4,
              child: NowPlayingControls(
                size: size,
                audioId: metadata.extras?['ytid'],
                adjustedIconSize: adjustedIconSize * 1.1,
                adjustedMiniIconSize: adjustedMiniIconSize * 1.1,
                metadata: metadata,
              ),
            ),
          BottomActionsRow(
            metadata: metadata,
            iconSize: adjustedMiniIconSize,
            isLargeScreen: isLargeScreen,
            lyricsController: lyricsController,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout(BuildContext context) {
    final isLive = metadata.extras?['isLive'] ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Center(
              child: NowPlayingArtwork(
                size: size,
                metadata: metadata,
                lyricsController: lyricsController,
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!isLive)
                  Expanded(
                    child: NowPlayingControls(
                      size: size,
                      audioId: metadata.extras?['ytid'],
                      adjustedIconSize: adjustedIconSize,
                      adjustedMiniIconSize: adjustedMiniIconSize,
                      metadata: metadata,
                    ),
                  ),
                BottomActionsRow(
                  metadata: metadata,
                  iconSize: adjustedMiniIconSize,
                  isLargeScreen: isLargeScreen,
                  lyricsController: lyricsController,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
