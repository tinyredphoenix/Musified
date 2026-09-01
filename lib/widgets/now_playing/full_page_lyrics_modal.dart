import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:musified/services/common_services.dart';
import 'package:musified/theme/app_themes.dart';
import 'package:musified/theme/musified_style.dart';
import 'package:musified/utilities/async_loader.dart';
import 'package:musified/widgets/now_playing/synced_lyrics_view.dart';
import 'package:musified/widgets/position_slider.dart';
import 'package:musified/widgets/song_artwork.dart';

class FullPageLyricsModal extends StatelessWidget {
  const FullPageLyricsModal({
    super.key,
    required this.metadata,
  });

  final MediaItem metadata;

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDarkMode(context);
    final bg = isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    final textColor = isDark ? CupertinoColors.white : CupertinoColors.black;
    final title = metadata.title;
    final artist = metadata.artist ?? 'Musified';

    return CupertinoPageScaffold(
      backgroundColor: bg,
      child: SafeArea(
        child: Column(
          children: [
            // Top Bar with artwork thumbnail and close button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SongArtworkWidget(
                      metadata: metadata,
                      size: 42,
                      errorWidgetIconSize: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: MusifiedStyle.displayFont,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                            decoration: TextDecoration.none,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          artist,
                          style: const TextStyle(
                            fontFamily: MusifiedStyle.uiFont,
                            fontSize: 13,
                            color: CupertinoColors.systemGrey,
                            decoration: TextDecoration.none,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: musifiedSecondarySurface(isDark),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CupertinoIcons.chevron_down,
                        color: textColor,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Live Synced Lyrics Body
            Expanded(
              child: AsyncLoader<String?>(
                future: getSongLyrics(metadata.artist, metadata.title),
                emptyWidget: const Center(
                  child: Text(
                    'No Lyrics Available',
                    style: TextStyle(
                      fontFamily: MusifiedStyle.uiFont,
                      fontSize: 16,
                      color: CupertinoColors.systemGrey,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                errorBuilder: (_, __, ___) => const Center(
                  child: Text(
                    'Failed to Load Lyrics',
                    style: TextStyle(
                      fontFamily: MusifiedStyle.uiFont,
                      fontSize: 16,
                      color: CupertinoColors.systemGrey,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                builder: (context, lyrics) => SyncedLyricsView(
                  metadata: metadata,
                  lyrics: lyrics ?? 'No lyrics available',
                  isActive: true,
                  isFullScreen: true,
                ),
              ),
            ),
            // Bottom Mini Scrub Bar
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: PositionSlider(),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showFullPageLyrics(BuildContext context, MediaItem metadata) {
  HapticFeedback.selectionClick();
  return Navigator.of(context, rootNavigator: true).push<void>(
    CupertinoPageRoute(
      fullscreenDialog: true,
      builder: (ctx) => FullPageLyricsModal(metadata: metadata),
    ),
  );
}
