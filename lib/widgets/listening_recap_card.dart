import 'package:flutter/cupertino.dart';
import 'package:musified/theme/app_themes.dart';
import 'package:musified/theme/musified_style.dart';
import 'package:musified/widgets/song_tile.dart';

class ListeningRecapCard extends StatelessWidget {
  const ListeningRecapCard({
    required this.periodLabel,
    required this.minutes,
    required this.songs,
    required this.onSongTap,
    super.key,
  });

  final String periodLabel;
  final int minutes;
  final List<Map<String, dynamic>> songs;
  final ValueChanged<int> onSongTap;

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDarkMode(context);
    final cardBg = musifiedElevatedSurface(isDark);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$minutes',
                    style: const TextStyle(
                      fontFamily: MusifiedStyle.displayFont,
                      color: Color(0xFFFF2D55),
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Minutes Streamed',
                    style: TextStyle(
                      fontFamily: MusifiedStyle.uiFont,
                      color: CupertinoColors.systemGrey,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF2D55).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Musified · $periodLabel',
                  style: const TextStyle(
                    fontFamily: MusifiedStyle.uiFont,
                    color: Color(0xFFFF2D55),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (songs.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (var i = 0; i < songs.length; i++)
              SongTile(
                song: songs[i],
                key: ValueKey('recap_song_${songs[i]['ytid']}_$i'),
                onTap: () => onSongTap(i),
              ),
          ],
        ],
      ),
    );
  }
}
