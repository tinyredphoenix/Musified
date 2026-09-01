import 'package:flutter/cupertino.dart';
import 'package:musified/main.dart';
import 'package:musified/theme/app_themes.dart';

class ShufflePlayButton extends StatelessWidget {
  const ShufflePlayButton({super.key, required this.songs});

  final List songs;

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDarkMode(context);

    return CupertinoButton(
      padding: const EdgeInsets.all(10),
      color: musifiedSecondarySurface(isDark),
      borderRadius: BorderRadius.circular(22),
      onPressed: () async {
        if (songs.isEmpty) return;
        final shuffledSongs = List<Map>.from(songs.whereType<Map>());
        if (shuffledSongs.isEmpty) return;
        shuffledSongs.shuffle();
        await audioHandler.addPlaylistToQueue(
          shuffledSongs,
          replace: true,
          startIndex: 0,
          resetShuffle: false,
        );
      },
      child: const Icon(CupertinoIcons.shuffle, size: 20, color: Color(0xFFFF2D55)),
    );
  }
}
