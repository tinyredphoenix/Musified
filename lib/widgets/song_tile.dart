import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:musified/main.dart';
import 'package:musified/theme/app_themes.dart';
import 'package:musified/theme/musified_style.dart';
import 'package:musified/widgets/song_actions_sheet.dart';

/// Clean, high-performance iOS Apple-style song row.
class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.song,
    this.onTap,
    this.showMore = true,
    this.onRemove,
    this.canRemove = false,
    this.isRecent = false,
  });

  final Map song;
  final VoidCallback? onTap;
  final bool showMore;
  final VoidCallback? onRemove;
  final bool canRemove;
  final bool isRecent;

  @override
  Widget build(BuildContext context) {
    final ytid = song['ytid']?.toString() ?? '';
    final title = song['title']?.toString() ?? 'Unknown Title';
    final artist = song['artist']?.toString() ?? 'Unknown Artist';
    final imageUrl = song['lowResImage']?.toString() ??
        song['image']?.toString() ??
        song['thumbnail']?.toString() ??
        'https://i.ytimg.com/vi/$ytid/hqdefault.jpg';

    final isDark = isAppDarkMode(context);
    final primaryColor = isDark ? CupertinoColors.white : CupertinoColors.black;
    final secondaryColor = CupertinoColors.systemGrey;

    return StreamBuilder<String?>(
      stream: audioHandler.mediaItem.map((item) => item?.extras?['ytid']?.toString()),
      builder: (context, snapshot) {
        final isPlaying = snapshot.data == ytid && ytid.isNotEmpty;

        return CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          onPressed: () {
            HapticFeedback.selectionClick();
            if (onTap != null) {
              onTap!();
            } else {
              audioHandler.playSong(song);
            }
          },
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                          child: const Icon(
                            CupertinoIcons.music_note,
                            size: 20,
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                      ),
                      if (isPlaying)
                        Container(
                          color: const Color(0x66000000),
                          child: const Center(
                            child: Icon(
                              CupertinoIcons.waveform,
                              color: CupertinoColors.white,
                              size: 22,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: MusifiedStyle.uiFont,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: isPlaying ? const Color(0xFFFF2D55) : primaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      artist,
                      style: TextStyle(
                        fontFamily: MusifiedStyle.uiFont,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: secondaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (showMore)
                CupertinoButton(
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(36, 36),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    showSongActionsSheet(
                      context,
                      song: song,
                      canRemove: canRemove,
                      onRemove: onRemove,
                      isRecent: isRecent,
                    );
                  },
                  child: const Icon(
                    CupertinoIcons.ellipsis,
                    size: 20,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
