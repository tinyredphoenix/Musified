import 'package:flutter/cupertino.dart';
import 'package:musified/theme/musified_style.dart';
import 'package:musified/widgets/now_playing/lyrics/lyrics_theme.dart';

class LyricsEmptyState extends StatelessWidget {
  const LyricsEmptyState({
    super.key,
    required this.theme,
    required this.message,
    this.icon = CupertinoIcons.quote_bubble,
    this.compact = false,
  });

  final LyricsTheme theme;
  final String message;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? MusifiedStyle.spaceLg : MusifiedStyle.spaceXl,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: compact ? 48 : 64,
              height: compact ? 48 : 64,
              decoration: BoxDecoration(
                color: theme.chipFill,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: compact ? 22 : 28,
                color: theme.muted,
              ),
            ),
            SizedBox(height: compact ? MusifiedStyle.spaceMd : MusifiedStyle.spaceLg),
            Text(
              message,
              style: MusifiedStyle.songSubtitle(theme.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
