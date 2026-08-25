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
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/async_loader.dart';
import 'package:musify/widgets/flip_card.dart';
import 'package:musify/widgets/song_artwork.dart';

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

    const borderRadius = 16.0;

    return FlipCard(
      rotateSide: RotateSide.right,
      onTapFlipping: !offlineMode.value,
      controller: lyricsController,
      frontWidget: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.15),
              blurRadius: 32,
              offset: const Offset(0, 16),
              spreadRadius: 4,
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
              color: colorScheme.shadow.withValues(alpha: 0.15),
              blurRadius: 32,
              offset: const Offset(0, 16),
              spreadRadius: 4,
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
                  FluentIcons.text_quote_24_regular,
                  size: 48,
                  color: colorScheme.onSecondaryContainer.withValues(
                    alpha: 0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n!.lyricsNotAvailable,
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
                  FluentIcons.text_quote_24_regular,
                  size: 48,
                  color: colorScheme.onSecondaryContainer.withValues(
                    alpha: 0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n!.lyricsNotAvailable,
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
          builder: (context, lyrics) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            physics: const BouncingScrollPhysics(),
            child: Text(
              lyrics ?? context.l10n!.lyricsNotAvailable,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSecondaryContainer,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final currentSource = metadata.extras?['resolvedSource'] as String? ?? 'youtube';
        final ytid = metadata.extras?['ytid']?.toString() ?? '';
        final isOffline = getOfflineSongByYtid(ytid).isNotEmpty;
        
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text(
                    'Switch Audio Source',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                if (isOffline)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Text('Playing offline - source switching disabled'),
                  )
                else ...[
                  ListTile(
                    leading: const Icon(FluentIcons.music_note_1_24_regular),
                    title: const Text('JioSaavn'),
                    subtitle: const Text('High Quality (AAC)'),
                    trailing: currentSource == 'jiosaavn' 
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      if (currentSource != 'jiosaavn') {
                        _replayWithSource('jiosaavn');
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(FluentIcons.video_clip_24_regular),
                    title: const Text('YouTube'),
                    subtitle: const Text('Standard Quality (Opus/AAC)'),
                    trailing: currentSource == 'youtube' 
                        ? const Icon(Icons.check_circle, color: Colors.blue)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      if (currentSource != 'youtube') {
                        _replayWithSource('youtube');
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _replayWithSource(String source) {
    final currentSong = audioHandler.currentSong;
    if (currentSong != null) {
      currentSong['forceSource'] = source;
      audioHandler.playSong(currentSong);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!showAudioQualityBadge.value) return const SizedBox.shrink();

    final extras = metadata.extras ?? {};
    final ytid = extras['ytid']?.toString() ?? '';
    final offlineSong = getOfflineSongByYtid(ytid);
    final isOffline = offlineSong.isNotEmpty;

    String label;
    Color color;
    
    if (isOffline) {
      label = 'Offline';
      color = Colors.grey;
    } else {
      final source = extras['resolvedSource'] as String? ?? 'youtube';
      final bitrate = extras['resolvedBitrate'] as int?;
      final format = extras['resolvedFormat'] as String?;
      
      final codecStr = format != null ? _normalizeCodec(format) : '';
      final bitrateStr = bitrate != null ? '${bitrate}k' : '';
      final qualityStr = [bitrateStr, codecStr].where((s) => s.isNotEmpty).join(' ');

      if (source == 'jiosaavn') {
        label = qualityStr.isNotEmpty ? 'JioSaavn $qualityStr' : 'JioSaavn';
        color = Colors.green;
      } else {
        label = qualityStr.isNotEmpty ? 'YouTube $qualityStr' : 'YouTube';
        color = Colors.blue;
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
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
