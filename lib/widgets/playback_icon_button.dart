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

import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';

Widget buildPlaybackIconButton(
  double iconSize,
  Color iconColor,
  Color backgroundColor, {
  EdgeInsets? padding,
}) {
  // `audioHandler` throws until AudioService finishes initializing (see
  // main.dart). Callers of this widget are usually gated behind that check
  // already (e.g. the mini player only appears once a media item exists),
  // but guard here too so this can never crash into the red error screen if
  // it's ever reached a beat early - show the same loading spinner used
  // below instead.
  if (!isAudioHandlerInitialized) {
    return RawMaterialButton(
      elevation: 0,
      onPressed: null,
      fillColor: backgroundColor,
      padding: padding ?? EdgeInsets.all(iconSize * 0.35),
      shape: const CircleBorder(),
      constraints: BoxConstraints.tightFor(
        width: iconSize * 2,
        height: iconSize * 2,
      ),
      child: SizedBox(
        width: iconSize,
        height: iconSize,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(iconColor),
        ),
      ),
    );
  }

  return StreamBuilder<PlaybackState>(
    stream: audioHandler.playbackState.distinct((previous, current) {
      // Only rebuild if relevant state changes
      return previous.playing == current.playing &&
          previous.processingState == current.processingState;
    }),
    builder: (context, snapshot) {
      final playbackState = snapshot.data;
      final processingState = playbackState?.processingState;
      final isPlaying = playbackState?.playing ?? false;

      Widget iconWidget;
      VoidCallback? onPressed;
      String? semanticLabel;

      if (processingState == AudioProcessingState.loading ||
          processingState == AudioProcessingState.buffering) {
        iconWidget = SizedBox(
          width: iconSize,
          height: iconSize,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(iconColor),
          ),
        );
        // Loading can be cancelled so a slow source never traps the user in
        // a disabled play button. The next tap can then retry or choose the
        // other service.
        onPressed = audioHandler.stop;
        semanticLabel = 'Cancel loading';
      } else if (processingState == AudioProcessingState.completed) {
        iconWidget = Icon(
          CupertinoIcons.arrow_counterclockwise,
          color: iconColor,
          size: iconSize,
        );
        onPressed = () => audioHandler.playAgain();
        semanticLabel = context.l10n.replay;
      } else {
        iconWidget = Icon(
          isPlaying
              ? CupertinoIcons.pause_fill
              : CupertinoIcons.play_fill,
          color: iconColor,
          size: iconSize,
        );
        onPressed = isPlaying ? audioHandler.pause : audioHandler.play;
        semanticLabel = isPlaying ? context.l10n.pause : context.l10n.play;
      }

      return RawMaterialButton(
        elevation: 0,
        onPressed: onPressed,
        fillColor: backgroundColor,
        splashColor: Colors.transparent,
        padding: padding ?? EdgeInsets.all(iconSize * 0.35),
        shape: const CircleBorder(),
        constraints: BoxConstraints.tightFor(
          width: iconSize * 2,
          height: iconSize * 2,
        ),
        materialTapTargetSize: MaterialTapTargetSize.padded,
        child: Semantics(label: semanticLabel, button: true, child: iconWidget),
      );
    },
  );
}

class PlaybackIconButton extends StatelessWidget {
  const PlaybackIconButton({
    super.key,
    required this.iconSize,
    required this.iconColor,
    required this.backgroundColor,
    this.padding,
  });

  final double iconSize;
  final Color iconColor;
  final Color backgroundColor;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return buildPlaybackIconButton(
      iconSize,
      iconColor,
      backgroundColor,
      padding: padding,
    );
  }
}
