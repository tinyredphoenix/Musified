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
import 'package:musify/models/position_data.dart';
import 'package:musify/utilities/formatter.dart';

class PositionSlider extends StatefulWidget {
  const PositionSlider({super.key});

  @override
  State<PositionSlider> createState() => _PositionSliderState();
}

class _PositionSliderState extends State<PositionSlider> {
  bool _isDragging = false;
  double _dragValue = 0;
  Object? _currentMediaId;
  PositionData _positionData = PositionData(
    Duration.zero,
    Duration.zero,
    Duration.zero,
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, mediaSnapshot) {
        return StreamBuilder<PositionData>(
          stream: audioHandler.positionDataStream,
          builder: (context, snapshot) {
            final mediaId = mediaSnapshot.data?.id;
            final mediaChanged = mediaId != _currentMediaId;
            if (mediaChanged) {
              _currentMediaId = mediaId;
              _isDragging = false;
              _positionData = PositionData(
                Duration.zero,
                Duration.zero,
                Duration.zero,
              );
            }

            // The position stream can still contain the previous item's last
            // value in the same frame as a new MediaItem. Do not copy that
            // sample into the new track's slider.
            if (snapshot.data != null && !mediaChanged) {
              _positionData = snapshot.data!;
            }

            final processingState =
                audioHandler.playbackState.valueOrNull?.processingState;
            final isSettled =
                processingState == AudioProcessingState.ready ||
                processingState == AudioProcessingState.completed;
            final metadataDuration = mediaSnapshot.data?.duration;
            // During a source transition just_audio can briefly expose the
            // previous track's duration. Prefer the current MediaItem until
            // the new source is ready, preventing 2-minute songs from
            // showing as 4-minute tracks and producing an empty tail.
            final displayDuration =
                (mediaChanged || !isSettled) && metadataDuration != null
                ? metadataDuration
                : _positionData.duration;
            final displayPositionData = PositionData(
              processingState == AudioProcessingState.loading
                  ? Duration.zero
                  : _positionData.position,
              _positionData.bufferedPosition,
              displayDuration,
            );
            final maxDuration = displayDuration.inMilliseconds > 0
                ? displayDuration.inMilliseconds.toDouble()
                : 1.0;

            final currentValue = _isDragging
                ? _dragValue
                : displayPositionData.position.inMilliseconds.toDouble();

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: CupertinoSlider(
                    value: currentValue.clamp(0.0, maxDuration),
                    onChanged: (value) {
                      setState(() {
                        _isDragging = true;
                        _dragValue = value;
                      });
                    },
                    onChangeEnd: (value) {
                      audioHandler.seek(Duration(milliseconds: value.round()));
                      setState(() {
                        _isDragging = false;
                      });
                    },
                    max: maxDuration,
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
                _buildPositionRow(context, displayPositionData),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPositionRow(BuildContext context, PositionData positionData) {
    final positionSec = _isDragging
        ? (_dragValue / 1000).round()
        : positionData.position.inSeconds;
    final durationSec = positionData.duration.inSeconds;
    final remainingSec = (durationSec - positionSec).clamp(0, durationSec);

    final positionText = positionData.duration == Duration.zero
        ? '--:--'
        : formatDuration(positionSec);
    final remainingText = positionData.duration == Duration.zero
        ? '--:--'
        : '-${formatDuration(remainingSec)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            positionText,
            style: TextStyle(
              fontSize: 11,
              fontFeatures: const [ui.FontFeature.tabularFigures()],
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            remainingText,
            style: TextStyle(
              fontSize: 11,
              fontFeatures: const [ui.FontFeature.tabularFigures()],
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
