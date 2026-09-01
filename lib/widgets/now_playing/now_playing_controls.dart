import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:musified/extensions/l10n.dart';
import 'package:musified/main.dart';
import 'package:musified/services/common_services.dart';
import 'package:musified/services/router_service.dart';
import 'package:musified/services/settings_manager.dart';
import 'package:musified/utilities/app_utils.dart';
import 'package:musified/utilities/mediaitem.dart';
import 'package:musified/widgets/now_playing/marquee_text_widget.dart';

import 'package:musified/widgets/playback_icon_button.dart';
import 'package:musified/widgets/position_slider.dart';

class NowPlayingControls extends StatelessWidget {
  const NowPlayingControls({
    super.key,
    required this.size,
    required this.audioId,
    required this.adjustedIconSize,
    required this.adjustedMiniIconSize,
    required this.metadata,
  });

  final Size size;
  final dynamic audioId;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;
  final MediaItem metadata;

  @override
  Widget build(BuildContext context) {
    final isDesktop = size.width > 800;

    final titleFontSize = getResponsiveTitleFontSize(size);
    final artistFontSize = getResponsiveArtistFontSize(size);
    final canOpenArtist = _canOpenArtist(metadata);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final isCompact = availableHeight < 280;
        final isVeryCompact = availableHeight < 200;

        final spacing = isVeryCompact
            ? 2.0
            : isCompact
            ? 4.0
            : 8.0;
        final iconScale = isVeryCompact
            ? 0.65
            : isCompact
            ? 0.75
            : 1.0;
        final fontScale = isCompact ? 0.9 : 1.0;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isCompact) const Spacer(),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 8 : 0,
                vertical: spacing,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 44),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MarqueeTextWidget(
                          text: metadata.title,
                          fontColor: CupertinoDynamicColor.resolve(
                            CupertinoColors.label,
                            context,
                          ),
                          fontSize: titleFontSize * fontScale,
                          fontWeight: FontWeight.w700,
                        ),
                        const SizedBox(height: 4),
                        if (metadata.artist != null)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: canOpenArtist
                                ? () => _openArtistPage(context, metadata)
                                : null,
                            child: Text(
                              metadata.artist!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: canOpenArtist
                                    ? CupertinoDynamicColor.resolve(
                                        CupertinoColors.activeBlue,
                                        context,
                                      )
                                    : CupertinoDynamicColor.resolve(
                                        CupertinoColors.secondaryLabel,
                                        context,
                                      ),
                                fontSize: artistFontSize * fontScale,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 0,
                    child: ValueListenableBuilder<List>(
                      valueListenable: userLikedSongsList,
                      builder: (context, likedSongs, _) {
                        final ytid = metadata.extras?['ytid']?.toString();
                        final isLiked =
                            ytid != null && isSongAlreadyLiked(ytid);
                        return CupertinoButton(
                          padding: const EdgeInsets.all(8),
                          minimumSize: const Size(36, 36),
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            if (ytid != null) {
                              updateSongLikeStatus(
                                ytid,
                                !isLiked,
                                songData: mediaItemToMap(metadata),
                              );
                            }
                          },
                          child: Icon(
                            isLiked
                                ? CupertinoIcons.heart_fill
                                : CupertinoIcons.heart,
                            color: isLiked
                                ? CupertinoColors.systemPink
                                : CupertinoDynamicColor.resolve(
                                    CupertinoColors.secondaryLabel,
                                    context,
                                  ),
                            size: 22,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (!isCompact) const Spacer(),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 450 : double.infinity,
              ),
              child: const PositionSlider(),
            ),
            SizedBox(height: spacing),
            PlayerControlButtons(
              metadata: metadata,
              iconSize: adjustedIconSize * iconScale,
              miniIconSize: adjustedMiniIconSize * iconScale,
            ),
            if (!isCompact) const Spacer(),
          ],
        );
      },
    );
  }

  bool _canOpenArtist(MediaItem metadata) {
    final info = _extractArtistInfo(metadata);
    return !offlineMode.value &&
        (info.artist.isNotEmpty ||
            info.artistId.isNotEmpty ||
            info.sourceSongId.isNotEmpty);
  }

  void _openArtistPage(BuildContext context, MediaItem metadata) {
    final info = _extractArtistInfo(metadata);
    final lookup = info.artistId.isNotEmpty
        ? info.artistId
        : info.artist.isNotEmpty
        ? info.artist
        : info.sourceSongId;

    if (lookup.isEmpty) return;

    final router = GoRouter.of(context);
    final artistPath = NavigationManager.artistPath(context, lookup);
    final artistData = {
      'ytid': info.artistId.isNotEmpty ? info.artistId : lookup,
      if (info.artist.isNotEmpty) 'title': info.artist,
      if (info.sourceSongId.isNotEmpty) 'sourceSongId': info.sourceSongId,
      if (info.videoAuthor.isNotEmpty) 'videoAuthor': info.videoAuthor,
      'source': 'youtube-artist',
      'isArtist': true,
      'list': [],
    };

    Navigator.of(context).pop();
    unawaited(router.push(artistPath, extra: artistData));
  }

  ({String artist, String artistId, String sourceSongId, String videoAuthor})
  _extractArtistInfo(MediaItem metadata) {
    return (
      artist: metadata.artist?.trim() ?? '',
      artistId: metadata.extras?['artistId']?.toString().trim() ?? '',
      sourceSongId: metadata.extras?['ytid']?.toString().trim() ?? '',
      videoAuthor: metadata.extras?['videoAuthor']?.toString().trim() ?? '',
    );
  }
}

class PlayerControlButtons extends StatelessWidget {
  const PlayerControlButtons({
    super.key,
    required this.metadata,
    required this.iconSize,
    required this.miniIconSize,
  });
  final MediaItem metadata;
  final double iconSize;
  final double miniIconSize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final isTight = maxWidth < 360;
        final isUltraTight = maxWidth < 320;

        final horizontalPadding = isUltraTight
            ? 10.0
            : isTight
            ? 14.0
            : 20.0;
        const buttonSpacing = 24.0;
        final minButtonSize = isUltraTight
            ? 38.0
            : isTight
            ? 42.0
            : 46.0;
        final buttonPadding = EdgeInsets.all(
          isUltraTight
              ? 6.0
              : isTight
              ? 8.0
              : 10.0,
        );

        final buttonConstraints = BoxConstraints(
          minWidth: minButtonSize,
          minHeight: minButtonSize,
        );

        const controlIconSize = 32.0;
        const miniControlSize = 22.0;
        const playPadding = EdgeInsets.all(
          (64.0 - 32.0) / 2,
        );
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Row(
            children: <Widget>[
              _buildShuffleButton(
                context,
                miniControlSize,
                buttonConstraints,
                buttonPadding,
              ),
              const SizedBox(width: buttonSpacing),
              Expanded(
                child: Center(
                  child: _PlaybackControlsRow(
                    buttonConstraints: buttonConstraints,
                    buttonPadding: buttonPadding,
                    controlIconSize: controlIconSize,
                    buttonSpacing: buttonSpacing,
                    minButtonSize: minButtonSize,
                    playPadding: playPadding,
                  ),
                ),
              ),
              const SizedBox(width: buttonSpacing),
              _buildRepeatButton(
                context,
                miniControlSize,
                buttonConstraints,
                buttonPadding,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShuffleButton(
    BuildContext context,
    double size,
    BoxConstraints buttonConstraints,
    EdgeInsets buttonPadding,
  ) {
    return ValueListenableBuilder<bool>(
      valueListenable: shuffleNotifier,
      builder: (_, value, __) {
        return CupertinoButton(
          padding: buttonPadding,
          minimumSize: Size(buttonConstraints.minWidth, buttonConstraints.minHeight),
          onPressed: () {
            HapticFeedback.selectionClick();
            audioHandler.setShuffleMode(
              value
                  ? AudioServiceShuffleMode.none
                  : AudioServiceShuffleMode.all,
            );
          },
          child: Icon(
            CupertinoIcons.shuffle,
            color: value
                ? const Color(0xFFFF2D55)
                : CupertinoDynamicColor.resolve(
                    CupertinoColors.tertiaryLabel,
                    context,
                  ),
            size: size * 0.9,
          ),
        );
      },
    );
  }

  Widget _buildRepeatButton(
    BuildContext context,
    double size,
    BoxConstraints buttonConstraints,
    EdgeInsets buttonPadding,
  ) {
    return ValueListenableBuilder<AudioServiceRepeatMode>(
      valueListenable: repeatNotifier,
      builder: (_, repeatMode, __) {
        final isEnabled = repeatMode != AudioServiceRepeatMode.none;
        final isRepeatOne = repeatMode == AudioServiceRepeatMode.one;

        return CupertinoButton(
          padding: buttonPadding,
          minimumSize: Size(buttonConstraints.minWidth, buttonConstraints.minHeight),
          onPressed: () {
            HapticFeedback.selectionClick();
            final newMode = switch (repeatMode) {
              AudioServiceRepeatMode.none => AudioServiceRepeatMode.all,
              AudioServiceRepeatMode.all => AudioServiceRepeatMode.one,
              AudioServiceRepeatMode.one => AudioServiceRepeatMode.none,
              _ => AudioServiceRepeatMode.none,
            };
            repeatNotifier.value = newMode;
            audioHandler.setRepeatMode(newMode);
          },
          child: Icon(
            isRepeatOne
                ? CupertinoIcons.repeat_1
                : CupertinoIcons.repeat,
            color: isEnabled
                ? const Color(0xFFFF2D55)
                : CupertinoDynamicColor.resolve(
                    CupertinoColors.tertiaryLabel,
                    context,
                  ),
            size: size * 0.9,
          ),
        );
      },
    );
  }
}

class _PlaybackControlsRow extends StatelessWidget {
  const _PlaybackControlsRow({
    required this.buttonConstraints,
    required this.buttonPadding,
    required this.controlIconSize,
    required this.buttonSpacing,
    required this.minButtonSize,
    required this.playPadding,
  });

  final BoxConstraints buttonConstraints;
  final EdgeInsets buttonPadding;
  final double controlIconSize;
  final double buttonSpacing;
  final double minButtonSize;
  final EdgeInsets playPadding;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AudioServiceRepeatMode>(
      valueListenable: repeatNotifier,
      builder: (_, repeatMode, __) {
        return FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PlaybackControlButton(
                    icon: CupertinoIcons.backward_fill,
                    isEnabled:
                        audioHandler.hasPrevious ||
                        repeatMode != AudioServiceRepeatMode.none,
                    tooltip: context.l10n.skipToPrevious,
                    onPressed: () => audioHandler.skipToPrevious(),
                    buttonConstraints: buttonConstraints,
                    buttonPadding: buttonPadding,
                    controlIconSize: controlIconSize,
                    minButtonSize: minButtonSize,
                  ),
                  SizedBox(width: buttonSpacing),
                  PlaybackIconButton(
                    iconColor: CupertinoColors.white,
                    backgroundColor: const Color(0xFFFF2D55),
                    iconSize: controlIconSize,
                    padding: playPadding,
                  ),
                  SizedBox(width: buttonSpacing),
                  _PlaybackControlButton(
                    icon: CupertinoIcons.forward_fill,
                    isEnabled:
                        audioHandler.hasNext ||
                        repeatMode == AudioServiceRepeatMode.one,
                    tooltip: context.l10n.skipToNext,
                    onPressed: () => repeatMode == AudioServiceRepeatMode.one
                        ? audioHandler.playAgain()
                        : audioHandler.skipToNext(),
                    buttonConstraints: buttonConstraints,
                    buttonPadding: buttonPadding,
                    controlIconSize: controlIconSize,
                    minButtonSize: minButtonSize,
                  ),
                ],
              ),
            );
      },
    );
  }
}

class _PlaybackControlButton extends StatelessWidget {
  const _PlaybackControlButton({
    required this.icon,
    required this.isEnabled,
    required this.tooltip,
    required this.onPressed,
    required this.buttonConstraints,
    required this.buttonPadding,
    required this.controlIconSize,
    required this.minButtonSize,
  });

  final IconData icon;
  final bool isEnabled;
  final String tooltip;
  final VoidCallback onPressed;
  final BoxConstraints buttonConstraints;
  final EdgeInsets buttonPadding;
  final double controlIconSize;
  final double minButtonSize;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: buttonPadding,
      minimumSize: Size(minButtonSize, minButtonSize),
      onPressed: isEnabled
          ? () {
              HapticFeedback.selectionClick();
              onPressed();
            }
          : null,
      child: Icon(
        icon,
        color: isEnabled
            ? CupertinoDynamicColor.resolve(CupertinoColors.label, context)
            : CupertinoDynamicColor.resolve(
                CupertinoColors.tertiaryLabel,
                context,
              ),
        size: controlIconSize,
      ),
    );
  }
}
