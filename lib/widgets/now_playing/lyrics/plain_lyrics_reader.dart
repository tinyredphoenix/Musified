import 'package:flutter/cupertino.dart';
import 'package:musified/widgets/now_playing/lyrics/lyrics_theme.dart';

/// Scrollable plain-text lyrics (no LRC timestamps).
class PlainLyricsReader extends StatelessWidget {
  const PlainLyricsReader({
    super.key,
    required this.text,
    required this.theme,
    required this.layout,
    this.onExpand,
  });

  final String text;
  final LyricsTheme theme;
  final LyricsLayout layout;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            layout == LyricsLayout.compact ? 18 : 32,
            layout == LyricsLayout.compact ? 48 : 24,
            layout == LyricsLayout.compact ? 18 : 32,
            layout == LyricsLayout.compact ? 20 : 32,
          ),
          physics: const BouncingScrollPhysics(),
          child: Text(
            text,
            style: theme.plainBodyStyle(layout),
            textAlign: TextAlign.center,
          ),
        ),
        if (onExpand != null)
          Positioned(
            top: 10,
            right: 10,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(32, 32),
              onPressed: onExpand,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: theme.chipFill,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.fullscreen,
                  size: 15,
                  color: theme.onCanvas,
                ),
              ),
            ),
          ),
        if (layout == LyricsLayout.compact)
          Positioned(
            top: 12,
            left: 14,
            child: Text(
              'LYRICS',
              style: theme.captionStyle().copyWith(
                letterSpacing: 1.4,
                color: theme.muted,
              ),
            ),
          ),
      ],
    );
  }
}
