import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:musified/extensions/l10n.dart';
import 'package:musified/main.dart';
import 'package:musified/services/common_services.dart';
import 'package:musified/services/settings_manager.dart';
import 'package:musified/theme/app_themes.dart';
import 'package:musified/theme/musified_style.dart';
import 'package:musified/utilities/async_loader.dart';
import 'package:musified/utilities/flutter_toast.dart';
import 'package:musified/widgets/flip_card.dart';
import 'package:musified/widgets/now_playing/synced_lyrics_view.dart';
import 'package:musified/widgets/song_artwork.dart';

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
    final isDark = isAppDarkMode(context);
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
      contentKey: metadata.extras?['ytid']?.toString() ?? metadata.id,
      frontWidget: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withValues(
                alpha: isDark ? 0.55 : 0.18,
              ),
              blurRadius: 28,
              offset: const Offset(0, 14),
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
          color: musifiedCanvas(isDark),
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withValues(
                alpha: isDark ? 0.45 : 0.12,
              ),
              blurRadius: 28,
              offset: const Offset(0, 14),
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
                  size: 36,
                  color: isDark
                      ? MusifiedStyle.tertiaryLabel
                      : MusifiedStyle.lightTertiaryLabel,
                ),
                const SizedBox(height: MusifiedStyle.spaceMd),
                Text(
                  'Lyrics Not Available',
                  style: MusifiedStyle.songSubtitle(
                    isDark
                        ? MusifiedStyle.secondaryLabel
                        : MusifiedStyle.lightSecondaryLabel,
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
                  size: 36,
                  color: isDark
                      ? MusifiedStyle.tertiaryLabel
                      : MusifiedStyle.lightTertiaryLabel,
                ),
                const SizedBox(height: MusifiedStyle.spaceMd),
                Text(
                  'Lyrics Not Available',
                  style: MusifiedStyle.songSubtitle(
                    isDark
                        ? MusifiedStyle.secondaryLabel
                        : MusifiedStyle.lightSecondaryLabel,
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
              isCompact: true,
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
    final ytid = metadata.extras?['ytid']?.toString() ?? '';
    // Fully downloaded tracks always use the local file.
    final isOffline =
        metadata.extras?['isOffline'] == true || hasPlayableOfflineFile(ytid);

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
    final actual = await audioHandler.switchSource(source);
    if (!context.mounted) return;
    if (actual == null) {
      showToast(context, 'That source is unavailable for this track.');
    } else if (actual != source) {
      showToast(context, 'Not available there — playing from $actual.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final extras = metadata.extras ?? {};
    final resolvedSource = extras['resolvedSource']?.toString();
    // Reflect what is actually playing. A download on disk must not force the
    // "Offline" badge once the track is streaming from a provider.
    final isOffline = resolvedSource == 'offline' ||
        (resolvedSource != 'youtube' &&
            resolvedSource != 'jiosaavn' &&
            (extras['isOffline'] == true ||
                hasPlayableOfflineFile(extras['ytid']?.toString())));

    String label;
    Color color;
    final source =
        resolvedSource ??
        extras['downloadSource']?.toString() ??
        'youtube';

    if (isOffline) {
      label = 'Offline';
      color = CupertinoColors.systemGrey;
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
        color = const Color(0xFFFF2D55);
      } else {
        label = qualityStr.isNotEmpty ? 'YouTube $qualityStr' : 'YouTube';
        color = const Color(0xFFFF2D55);
      }
    }

    return GestureDetector(
      onTap: () => _showSourcePicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: CupertinoColors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.waveform, size: 13, color: CupertinoColors.white),
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
                    ? (source == 'jiosaavn'
                        ? CupertinoIcons.music_note_2
                        : CupertinoIcons.play_rectangle_fill)
                    : (source == 'jiosaavn'
                        ? CupertinoIcons.music_note_2
                        : CupertinoIcons.play_rectangle_fill),
                size: 16,
                color: CupertinoColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
