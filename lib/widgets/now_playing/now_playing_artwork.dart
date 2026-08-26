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
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/async_loader.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/widgets/flip_card.dart';
import 'package:musify/widgets/song_artwork.dart';
import 'package:musify/widgets/now_playing/synced_lyrics_view.dart';

class NowPlayingArtwork extends StatelessWidget {
  const NowPlayingArtwork({
    super.key,
    required this.size,
    required this.metadata,
    required this.lyricsController,
  });
  final Size size;
  final MediaItem metadata;
  final FlipCardController lyricsController;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = size.width;
    final screenHeight = size.height;
    final isLandscape = screenWidth > screenHeight;
    final isDesktop = screenWidth > 800;
    final imageSize = isDesktop
        ? screenHeight * 0.38
        : isLandscape
        ? screenHeight * 0.45
        : screenWidth < 360
        ? screenWidth * 0.82
        : screenWidth < 600
        ? screenWidth * 0.88
        : screenWidth * 0.70;

    const borderRadius = 22.0;

    return FlipCard(
      rotateSide: RotateSide.right,
      onTapFlipping: !offlineMode.value,
      controller: lyricsController,
      frontWidget: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 36,
              offset: const Offset(0, 18),
              spreadRadius: -2,
            ),
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: SongArtworkWidget(
            metadata: metadata,
            size: imageSize,
            errorWidgetIconSize: size.width / 8,
            borderRadius: borderRadius,
          ),
        ),
      ),
      backWidget: Container(
        width: imageSize,
        height: imageSize,
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 36,
              offset: const Offset(0, 18),
              spreadRadius: -2,
            ),
          ],
        ),
        child: AsyncLoader<String?>(
          future: getSongLyrics(metadata.artist, metadata.title),
          emptyWidget: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.quote_bubble,
                  size: 48,
                  color: colorScheme.onSecondaryContainer.withValues(
                    alpha: 0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.lyricsNotAvailable,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSecondaryContainer,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          errorBuilder: (ctx, error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.quote_bubble,
                  size: 48,
                  color: colorScheme.onSecondaryContainer.withValues(
                    alpha: 0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.lyricsNotAvailable,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSecondaryContainer,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          builder: (context, lyrics) => ValueListenableBuilder<bool>(
            valueListenable: lyricsController.isFront,
            builder: (context, isFront, _) => SyncedLyricsView(
              metadata: metadata,
              lyrics: lyrics ?? context.l10n.lyricsNotAvailable,
              isActive: !isFront,
            ),
          ),
        ),
      ),
    );
  }
}

String _normalizeCodec(String codec) => switch (codec) {
  final c when c.startsWith('opus') => 'Opus',
  final c when c.startsWith('mp4a') => 'AAC',
  final c => c,
};

class AudioQualityBadge extends StatelessWidget {
  const AudioQualityBadge({super.key, required this.metadata});
  final MediaItem metadata;

  void _showSourcePicker(BuildContext context) {
    final currentSource =
        metadata.extras?['resolvedSource'] as String? ?? 'youtube';
    // Use the playback snapshot, not the mutable global download list. A
    // download completing in the background must not relabel the currently
    // playing online stream as offline or hide the source switcher.
    final isOffline = metadata.extras?['isOffline'] == true;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Audio source'),
        message: Text(
          isOffline
              ? 'Downloaded tracks use the local file.'
              : 'Choose the service for this same track.',
        ),
        actions: [
          if (!isOffline)
            CupertinoActionSheetAction(
              isDefaultAction: currentSource == 'jiosaavn',
              onPressed: () {
                Navigator.pop(context);
                if (currentSource != 'jiosaavn') {
                  unawaited(_replayWithSource(context, 'jiosaavn'));
                }
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.music_note_2, size: 18),
                  SizedBox(width: 8),
                  Text('JioSaavn · AAC'),
                ],
              ),
            ),
          if (!isOffline)
            CupertinoActionSheetAction(
              isDefaultAction: currentSource == 'youtube',
              onPressed: () {
                Navigator.pop(context);
                if (currentSource != 'youtube') {
                  unawaited(_replayWithSource(context, 'youtube'));
                }
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.play_rectangle, size: 18),
                  SizedBox(width: 8),
                  Text('YouTube · Opus/AAC'),
                ],
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _replayWithSource(BuildContext context, String source) async {
    final didSwitch = await audioHandler.switchSource(source);
    if (!didSwitch && context.mounted) {
      showToast(context, 'That source is unavailable for this track.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final extras = metadata.extras ?? {};
    final isOffline = extras['isOffline'] == true;

    String label;
    Color color;
    final source =
        extras['resolvedSource']?.toString() ??
        extras['downloadSource']?.toString() ??
        'youtube';

    if (isOffline) {
      label = 'Offline';
      color = Theme.of(context).colorScheme.onSurfaceVariant;
    } else {
      final bitrate = extras['resolvedBitrate'] as int?;
      final format = extras['resolvedFormat'] as String?;

      final codecStr = format != null ? _normalizeCodec(format) : '';
      final bitrateStr = bitrate != null ? '${bitrate}k' : '';
      final qualityStr = showAudioQualityBadge.value
          ? [bitrateStr, codecStr].where((s) => s.isNotEmpty).join(' ')
          : '';

      if (source == 'jiosaavn') {
        label = qualityStr.isNotEmpty ? 'JioSaavn $qualityStr' : 'JioSaavn';
        color = Theme.of(context).colorScheme.primary;
      } else {
        label = qualityStr.isNotEmpty ? 'YouTube $qualityStr' : 'YouTube';
        color = Theme.of(context).colorScheme.primary;
      }
    }

    return GestureDetector(
      onTap: () => _showSourcePicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.waveform, size: 13, color: Colors.white),
            const SizedBox(width: 5),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Semantics(
              label: label,
              button: true,
              child: Icon(
                isOffline
                    ? source == 'jiosaavn'
                          ? CupertinoIcons.music_note_2
                          : CupertinoIcons.play_rectangle_fill
                    : source == 'jiosaavn'
                    ? CupertinoIcons.music_note_2
                    : CupertinoIcons.play_rectangle_fill,
                size: 16,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
