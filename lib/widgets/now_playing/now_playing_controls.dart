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

import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/mediaitem.dart';
import 'package:musify/widgets/now_playing/marquee_text_widget.dart';

import 'package:musify/widgets/playback_icon_button.dart';
import 'package:musify/widgets/position_slider.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
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
                horizontal: isDesktop ? 16 : 4,
                vertical: spacing,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MarqueeTextWidget(
                          text: metadata.title,
                          fontColor: colorScheme.onSurface,
                          fontSize: titleFontSize * fontScale,
                          fontWeight: FontWeight.w700,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (metadata.artist != null)
                              Flexible(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: canOpenArtist
                                      ? () => _openArtistPage(context, metadata)
                                      : null,
                                  child: Text(
                                    metadata.artist!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.8),
                                      fontSize: artistFontSize * fontScale,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            _AudioSourceChip(metadata: metadata),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<List>(
                    valueListenable: userLikedSongsList,
                    builder: (context, likedSongs, _) {
                      final ytid = metadata.extras?['ytid']?.toString();
                      final isLiked = ytid != null && isSongAlreadyLiked(ytid);
                      return CupertinoButton(
                        padding: const EdgeInsets.all(8),
                        minSize: 36,
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
                              : colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.6),
                          size: 24,
                        ),
                      );
                    },
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
    final colorScheme = Theme.of(context).colorScheme;
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

        const controlIconSize = 28.0;
        const miniControlSize = 20.0;
        const playPadding = EdgeInsets.all(
          (52.0 - 28.0) / 2, // to make total size 52
        );
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Row(
            children: <Widget>[
              _buildShuffleButton(
                context,
                colorScheme,
                miniControlSize,
                buttonConstraints,
                buttonPadding,
              ),
              SizedBox(width: buttonSpacing),
              Expanded(
                child: Center(
                  child: _PlaybackControlsRow(
                    colorScheme: colorScheme,
                    buttonConstraints: buttonConstraints,
                    buttonPadding: buttonPadding,
                    controlIconSize: controlIconSize,
                    buttonSpacing: buttonSpacing,
                    minButtonSize: minButtonSize,
                    playPadding: playPadding,
                  ),
                ),
              ),
              SizedBox(width: buttonSpacing),
              _buildRepeatButton(
                context,
                colorScheme,
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
    ColorScheme colorScheme,
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
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            size: size * 0.9,
          ),
        );
      },
    );
  }

  Widget _buildRepeatButton(
    BuildContext context,
    ColorScheme colorScheme,
    double size,
    BoxConstraints buttonConstraints,
    EdgeInsets buttonPadding,
  ) {
    return StreamBuilder<List<MediaItem>>(
      stream: audioHandler.queue,
      builder: (context, snapshot) {
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
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                size: size * 0.9,
              ),
            );
          },
        );
      },
    );
  }
}

class _PlaybackControlsRow extends StatelessWidget {
  const _PlaybackControlsRow({
    required this.colorScheme,
    required this.buttonConstraints,
    required this.buttonPadding,
    required this.controlIconSize,
    required this.buttonSpacing,
    required this.minButtonSize,
    required this.playPadding,
  });

  final ColorScheme colorScheme;
  final BoxConstraints buttonConstraints;
  final EdgeInsets buttonPadding;
  final double controlIconSize;
  final double buttonSpacing;
  final double minButtonSize;
  final EdgeInsets playPadding;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MediaItem>>(
      stream: audioHandler.queue,
      builder: (context, snapshot) {
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
                    colorScheme: colorScheme,
                    buttonConstraints: buttonConstraints,
                    buttonPadding: buttonPadding,
                    controlIconSize: controlIconSize,
                    minButtonSize: minButtonSize,
                  ),
                  SizedBox(width: buttonSpacing),
                  PlaybackIconButton(
                    iconColor: colorScheme.onPrimary,
                    backgroundColor: colorScheme.primary,
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
                    colorScheme: colorScheme,
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
    required this.colorScheme,
    required this.buttonConstraints,
    required this.buttonPadding,
    required this.controlIconSize,
    required this.minButtonSize,
  });

  final IconData icon;
  final bool isEnabled;
  final String tooltip;
  final VoidCallback onPressed;
  final ColorScheme colorScheme;
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
            ? colorScheme.onSurface
            : colorScheme.onSurface.withValues(alpha: 0.3),
        size: controlIconSize,
      ),
    );
  }
}

class _AudioSourceChip extends StatelessWidget {
  const _AudioSourceChip({required this.metadata});
  final MediaItem metadata;

  void _showSourcePicker(BuildContext context) {
    final extras = metadata.extras ?? {};
    final currentSource = extras['resolvedSource'] as String? ?? 'youtube';
    final ytid = extras['ytid']?.toString() ?? '';
    final isOffline = getOfflineSongByYtid(ytid).isNotEmpty;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Material(
        color: Colors.transparent,
        child: CupertinoActionSheet(
          title: const Text('Audio Stream Source'),
          message: isOffline
              ? const Text('This song is playing from offline storage.')
              : const Text('Select audio provider for this track:'),
          actions: isOffline
              ? []
              : [
                  CupertinoActionSheetAction(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      if (currentSource != 'jiosaavn') {
                        HapticFeedback.selectionClick();
                        final success =
                            await audioHandler.switchSource('jiosaavn');
                        if (!success && context.mounted) {
                          showToast(
                            context,
                            'Track not available on JioSaavn (playing on YouTube)',
                          );
                        }
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          CupertinoIcons.music_note,
                          size: 18,
                          color: CupertinoColors.systemGreen,
                        ),
                        const SizedBox(width: 8),
                        const Text('JioSaavn (High Quality 320k AAC)'),
                        if (currentSource == 'jiosaavn') ...[
                          const SizedBox(width: 8),
                          const Icon(
                            CupertinoIcons.checkmark_alt_circle_fill,
                            size: 18,
                            color: CupertinoColors.systemGreen,
                          ),
                        ],
                      ],
                    ),
                  ),
                  CupertinoActionSheetAction(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      if (currentSource != 'youtube') {
                        HapticFeedback.selectionClick();
                        final success =
                            await audioHandler.switchSource('youtube');
                        if (!success && context.mounted) {
                          showToast(
                            context,
                            'Track not available on YouTube',
                          );
                        }
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          CupertinoIcons.play_rectangle_fill,
                          size: 18,
                          color: CupertinoColors.systemBlue,
                        ),
                        const SizedBox(width: 8),
                        const Text('YouTube (Standard 160k Opus)'),
                        if (currentSource == 'youtube') ...[
                          const SizedBox(width: 8),
                          const Icon(
                            CupertinoIcons.checkmark_alt_circle_fill,
                            size: 18,
                            color: CupertinoColors.systemBlue,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final extras = metadata.extras ?? {};
    final ytid = extras['ytid']?.toString() ?? '';
    final isOffline = getOfflineSongByYtid(ytid).isNotEmpty;

    final source = extras['resolvedSource'] as String? ?? 'youtube';
    final bitrate = extras['resolvedBitrate'] as int?;
    final isJioSaavn = source == 'jiosaavn';

    final label = isOffline
        ? 'Offline'
        : (isJioSaavn
            ? 'JioSaavn ${bitrate ?? 320}k AAC'
            : 'YouTube 160k Opus');

    final color = isOffline
        ? CupertinoColors.systemGrey
        : (isJioSaavn
            ? CupertinoColors.systemGreen
            : CupertinoColors.systemBlue);

    return GestureDetector(
      onTap: () => _showSourcePicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isJioSaavn
                  ? CupertinoIcons.music_note
                  : CupertinoIcons.play_rectangle_fill,
              size: 11,
              color: color,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              CupertinoIcons.chevron_down,
              size: 10,
              color: color.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}
