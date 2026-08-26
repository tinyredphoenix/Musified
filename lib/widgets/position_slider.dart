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
            final metadataDuration = mediaSnapshot.data?.duration;
            // The metadata duration is canonical from YouTube/JioSaavn catalog.
            // On iOS CoreAudio, HE-AAC/SBR stream timescales often cause AVPlayer to report
            // exactly double the duration. Prefer the canonical metadata duration.
            final displayDuration = (metadataDuration != null && metadataDuration > Duration.zero)
                ? metadataDuration
                : (_positionData.duration > Duration.zero
                    ? _positionData.duration
                    : Duration.zero);
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
                  height: 24, // reduced height for a tighter layout
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 2.5,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 4,
                        elevation: 0,
                        pressedElevation: 0,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 14,
                      ),
                      activeTrackColor: CupertinoDynamicColor.resolve(
                        CupertinoColors.label,
                        context,
                      ),
                      inactiveTrackColor: CupertinoDynamicColor.resolve(
                        CupertinoColors.tertiaryLabel,
                        context,
                      ).withValues(alpha: 0.35),
                      thumbColor: CupertinoDynamicColor.resolve(
                        CupertinoColors.label,
                        context,
                      ),
                      overlayColor: CupertinoDynamicColor.resolve(
                        CupertinoColors.label,
                        context,
                      ).withValues(alpha: 0.08),
                    ),
                    child: Slider(
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
                    ),
                  ),
                ),
                const SizedBox(height: 4),
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
              color: CupertinoDynamicColor.resolve(
                CupertinoColors.secondaryLabel,
                context,
              ),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            remainingText,
            style: TextStyle(
              fontSize: 11,
              fontFeatures: const [ui.FontFeature.tabularFigures()],
              color: CupertinoDynamicColor.resolve(
                CupertinoColors.secondaryLabel,
                context,
              ),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
