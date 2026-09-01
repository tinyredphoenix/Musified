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
    final bg = musifiedCanvas(isDark);
    final titleColor = isDark ? CupertinoColors.white : MusifiedStyle.lightOnSurface;
    final subtitleColor =
        isDark ? MusifiedStyle.secondaryLabel : MusifiedStyle.lightSecondaryLabel;
    final title = metadata.title;
    final artist = metadata.artist ?? 'Musified';

    return CupertinoPageScaffold(
      backgroundColor: bg,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MusifiedStyle.spaceLg,
                vertical: MusifiedStyle.spaceSm,
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(MusifiedStyle.radiusSm),
                    child: SongArtworkWidget(
                      metadata: metadata,
                      size: 44,
                      errorWidgetIconSize: 20,
                    ),
                  ),
                  const SizedBox(width: MusifiedStyle.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: MusifiedStyle.songTitle(titleColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          artist,
                          style: MusifiedStyle.songSubtitle(subtitleColor),
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
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: musifiedSecondarySurface(isDark),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CupertinoIcons.chevron_down,
                        color: titleColor,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AsyncLoader<String?>(
                future: getSongLyrics(metadata.artist, metadata.title),
                emptyWidget: Center(
                  child: Text(
                    'No Lyrics Available',
                    style: MusifiedStyle.songSubtitle(subtitleColor),
                  ),
                ),
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    'Failed to Load Lyrics',
                    style: MusifiedStyle.songSubtitle(subtitleColor),
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
