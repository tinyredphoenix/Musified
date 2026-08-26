/*
 * Full-screen player — Apple Music layout, Cupertino chrome.
 */

import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:musify/main.dart';
import 'package:musify/theme/musified_style.dart';
import 'package:musify/widgets/flip_card.dart';
import 'package:musify/widgets/now_playing/bottom_actions_row.dart';
import 'package:musify/widgets/now_playing/now_playing_artwork.dart';
import 'package:musify/widgets/now_playing/now_playing_controls.dart';
import 'package:musify/widgets/queue_list_view.dart';

class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key});

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  final _lyricsController = FlipCardController();

  @override
  void dispose() {
    _lyricsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isLargeScreen = size.width > 800 && size.height > 600;
    final brightness = MediaQuery.platformBrightnessOf(context);
    final bg = CupertinoDynamicColor.resolve(
      CupertinoColors.systemBackground,
      context,
    );
    final screenWidth = size.width;
    final baseIconSize = screenWidth < 360
        ? 36.0
        : screenWidth < 400
        ? 40.0
        : 44.0;
    final miniIconSize = screenWidth < 360 ? 18.0 : 22.0;

    return CupertinoPageScaffold(
      backgroundColor: bg,
      child: Material(
        type: MaterialType.transparency,
        child: DefaultTextStyle(
          style: TextStyle(
            fontFamily: MusifiedStyle.uiFont,
            decoration: TextDecoration.none,
            color: CupertinoDynamicColor.resolve(CupertinoColors.label, context),
          ),
          child: GestureDetector(
            onVerticalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) > 300) {
                Navigator.pop(context);
              }
            },
            child: ColoredBox(
              color: bg,
              child: SafeArea(
                child: StreamBuilder<MediaItem?>(
              stream: audioHandler.mediaItem,
              builder: (context, snapshot) {
                final metadata = snapshot.data;
                if (metadata == null) {
                  return const Center(child: CupertinoActivityIndicator());
                }
                return Column(
                  children: [
                    _Grabber(brightness: brightness),
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
        ),
      ),
    ),
  ),
);
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber({required this.brightness});
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Center(
        child: Container(
          width: 36,
          height: 5,
          decoration: BoxDecoration(
            color: CupertinoDynamicColor.resolve(
              CupertinoColors.tertiaryLabel,
              context,
            ),
            borderRadius: BorderRadius.circular(2.5),
          ),
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
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const SizedBox(height: 8),
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
                const SizedBox(height: 12),
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
    if (size.width > size.height) {
      return _buildLandscapeLayout(context);
    }
    return _buildPortraitLayout(context);
  }

  Widget _buildPortraitLayout(BuildContext context) {
    final isLive = metadata.extras?['isLive'] ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
      child: Column(
        children: [
          Expanded(
            flex: 6,
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
              flex: 5,
              child: NowPlayingControls(
                size: size,
                audioId: metadata.extras?['ytid'],
                adjustedIconSize: adjustedIconSize * 1.15,
                adjustedMiniIconSize: adjustedMiniIconSize * 1.15,
                metadata: metadata,
              ),
            ),
          BottomActionsRow(
            metadata: metadata,
            iconSize: 24,
            isLargeScreen: isLargeScreen,
            lyricsController: lyricsController,
          ),
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
          Expanded(
            flex: 5,
            child: Column(
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
