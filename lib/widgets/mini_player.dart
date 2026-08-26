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


import 'dart:ui' as ui;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/main.dart';
import 'package:musify/models/full_player_state.dart';
import 'package:musify/models/position_data.dart';
import 'package:musify/screens/now_playing_page.dart';
import 'package:musify/widgets/marquee.dart';
import 'package:musify/widgets/song_artwork.dart';
import 'package:rxdart/rxdart.dart';

Stream<FullPlayerState> get _fullPlayerStateStream {
  if (!isAudioHandlerInitialized) return const Stream<FullPlayerState>.empty();
  return Rx.combineLatest3(
        audioHandler.playbackStateStream,
        audioHandler.queue.distinct(),
        audioHandler.positionDataStream,
        (PlaybackState state, List<MediaItem> queue, PositionData pos) =>
            FullPlayerState(playbackState: state, queue: queue, position: pos),
      )
      .throttleTime(const Duration(milliseconds: 120), trailing: true)
      .asBroadcastStream();
}

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  static const double playerHeight = 64;
  static const double _borderRadius = 16;
  static const double _artworkSize = 52;
  static const double _artworkRadius = 14;

  @override
  Widget build(BuildContext context) {
    if (!isAudioHandlerInitialized) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: StreamBuilder<MediaItem?>(
        stream: audioHandler.mediaItem,
        builder: (context, mediaSnapshot) {
          final metadata = mediaSnapshot.data;
          if (metadata == null) return const SizedBox.shrink();

          return StreamBuilder<FullPlayerState>(
            stream: _fullPlayerStateStream,
            builder: (context, stateSnapshot) {
              final state = stateSnapshot.data;
              if (state == null) return const SizedBox.shrink();

              final hasNext =
                  state.queue.length > 1 &&
                  (state.playbackState.queueIndex ?? 0) <
                      state.queue.length - 1;

              return _MiniPlayerBody(
                colorScheme: colorScheme,
                metadata: metadata,
                state: state,
                hasNext: hasNext,
              );
            },
          );
        },
      ),
    );
  }
}

class _MiniPlayerBody extends StatefulWidget {
  const _MiniPlayerBody({
    required this.colorScheme,
    required this.metadata,
    required this.state,
    required this.hasNext,
  });

  final ColorScheme colorScheme;
  final MediaItem metadata;
  final FullPlayerState state;
  final bool hasNext;

  @override
  State<_MiniPlayerBody> createState() => _MiniPlayerBodyState();
}

class _MiniPlayerBodyState extends State<_MiniPlayerBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 0.98).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  static const double _dragThresholdForNavigation = 10;

  void _handleVerticalDrag(DragUpdateDetails details) {
    if ((details.primaryDelta ?? 0) < -_dragThresholdForNavigation) {
      _navigateToNowPlaying();
    }
  }

  void _navigateToNowPlaying() {
    Navigator.of(context).push(_createSlideTransition());
  }

  PageRoute<void> _createSlideTransition() {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, _) => const NowPlayingPage(),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeInOut));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = widget.colorScheme;
    final metadata = widget.metadata;
    final state = widget.state;

    final totalDuration = state.position.duration > Duration.zero
        ? state.position.duration
        : (metadata.duration ?? Duration.zero);
    final progress = totalDuration.inMilliseconds == 0
        ? 0.0
        : (state.position.position.inMilliseconds /
                  totalDuration.inMilliseconds)
              .clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: (_) => _animationController.forward(),
            onTapUp: (_) => _animationController.reverse(),
            onTapCancel: () => _animationController.reverse(),
            onVerticalDragUpdate: _handleVerticalDrag,
            onTap: _navigateToNowPlaying,
            child: Container(
              height: MiniPlayer.playerHeight,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(MiniPlayer._borderRadius),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(MiniPlayer._borderRadius),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          children: [
                            _ArtworkWidget(metadata: metadata),
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                switchInCurve: Curves.easeIn,
                                switchOutCurve: Curves.easeOut,
                                layoutBuilder:
                                    (currentChild, previousChildren) => Stack(
                                      alignment: Alignment.centerLeft,
                                      children: [
                                        ...previousChildren,
                                        if (currentChild != null) currentChild,
                                      ],
                                    ),
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                child: KeyedSubtree(
                                  key: ValueKey(metadata.id),
                                  child: _MetadataWidget(
                                    title: metadata.title,
                                    artist: metadata.artist,
                                    colorScheme: colorScheme,
                                  ),
                                ),
                              ),
                            ),
                            _ControlsWidget(
                              colorScheme: colorScheme,
                              playbackState: state.playbackState,
                              hasNext: widget.hasNext,
                              progress: progress,
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: SizedBox(
                          height: 1.0,
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              colorScheme.primary.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ArtworkWidget extends StatelessWidget {
  const _ArtworkWidget({required this.metadata});
  final MediaItem metadata;

  @override
  Widget build(BuildContext context) {
    final resolvedSource = metadata.extras?['resolvedSource'];
    var sourceColor = Colors.transparent;
    if (resolvedSource == 'jiosaavn') {
      sourceColor = Colors.green;
    } else if (resolvedSource == 'youtube') {
      sourceColor = Colors.blue;
    } else if (resolvedSource == 'offline') {
      sourceColor = Colors.grey;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Hero(
        tag: 'now_playing_artwork',
        child: Stack(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(MiniPlayer._artworkRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SongArtworkWidget(
                metadata: metadata,
                size: MiniPlayer._artworkSize,
                errorWidgetIconSize: 24,
                borderRadius: MiniPlayer._artworkRadius,
              ),
            ),
            if (sourceColor != Colors.transparent)
              Positioned(
                top: -2,
                left: -2,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: sourceColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surface,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetadataWidget extends StatelessWidget {
  const _MetadataWidget({
    required this.title,
    required this.artist,
    required this.colorScheme,
  });

  final String title;
  final String? artist;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarqueeWidget(
            manualScrollEnabled: false,
            animationDuration: const Duration(seconds: 8),
            backDuration: const Duration(seconds: 2),
            pauseDuration: const Duration(seconds: 2),
            child: Text(
              title,
              style: TextStyle(
                color: colorScheme.secondary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (artist != null && artist!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              artist!,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _ControlsWidget extends StatelessWidget {
  const _ControlsWidget({
    required this.colorScheme,
    required this.playbackState,
    required this.hasNext,
    required this.progress,
  });

  final ColorScheme colorScheme;
  final PlaybackState playbackState;
  final bool hasNext;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final isPlaying = playbackState.playing;
    final isCompleted = playbackState.processingState == AudioProcessingState.completed;
    final isLoading = playbackState.processingState == AudioProcessingState.loading || 
                      playbackState.processingState == AudioProcessingState.buffering;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading)
          CupertinoButton(
            onPressed: audioHandler.stop,
            padding: const EdgeInsets.all(8),
            minimumSize: const Size(40, 40),
            child: CupertinoActivityIndicator(
              radius: 11,
              color: colorScheme.onSurface,
            ),
          )
        else
          CupertinoButton(
            onPressed: isCompleted
                ? () => audioHandler.playAgain()
                : (isPlaying ? audioHandler.pause : audioHandler.play),
            padding: const EdgeInsets.all(8),
            minimumSize: const Size(40, 40),
            child: Icon(
              isCompleted
                  ? CupertinoIcons.arrow_counterclockwise
                  : (isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill),
              color: colorScheme.onSurface,
              size: 24,
            ),
          ),
        if (hasNext) ...[
          const SizedBox(width: 4),
          CupertinoButton(
            onPressed: audioHandler.skipToNext,
            padding: const EdgeInsets.all(8),
            minimumSize: const Size(40, 40),
            child: Icon(
              CupertinoIcons.forward_fill,
              color: colorScheme.onSurfaceVariant,
              size: 24,
            ),
          ),
        ],
      ],
    );
  }
}
