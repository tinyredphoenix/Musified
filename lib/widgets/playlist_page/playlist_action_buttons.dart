import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:musified/theme/app_themes.dart';
import 'package:musified/theme/musified_style.dart';

class PlaylistActionButtons extends StatelessWidget {
  const PlaylistActionButtons({
    super.key,
    required this.onPlay,
    required this.onShuffle,
    this.isLoading = false,
  });

  final VoidCallback onPlay;
  final AsyncCallback onShuffle;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDarkMode(context);
    final secondaryBtnBg = musifiedSecondarySurface(isDark);
    final secondaryTextColor = isDark ? CupertinoColors.white : CupertinoColors.black;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 14),
              borderRadius: BorderRadius.circular(MusifiedStyle.radiusPill),
              color: const Color(0xFFFF2D55),
              onPressed: isLoading ? null : onPlay,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading)
                    const CupertinoActivityIndicator(radius: 9)
                  else
                    const Icon(
                      CupertinoIcons.play_fill,
                      size: 18,
                      color: CupertinoColors.white,
                    ),
                  const SizedBox(width: 8),
                  const Text(
                    'Play',
                    style: TextStyle(
                      fontFamily: MusifiedStyle.uiFont,
                      color: CupertinoColors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 14),
              borderRadius: BorderRadius.circular(MusifiedStyle.radiusPill),
              color: secondaryBtnBg,
              onPressed: isLoading ? null : onShuffle,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading)
                    const CupertinoActivityIndicator(radius: 9)
                  else
                    Icon(
                      CupertinoIcons.shuffle,
                      size: 18,
                      color: secondaryTextColor,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    'Shuffle',
                    style: TextStyle(
                      fontFamily: MusifiedStyle.uiFont,
                      color: secondaryTextColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
