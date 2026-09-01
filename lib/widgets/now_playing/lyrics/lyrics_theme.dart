import 'package:flutter/cupertino.dart';
import 'package:musified/theme/musified_style.dart';

/// Visual tokens for live / synced lyrics (light + dark).
class LyricsTheme {
  LyricsTheme({
    required this.isDark,
    required Color accent,
  }) : accent = accent == CupertinoColors.activeBlue
      ? const Color(0xFFFF2D55)
      : accent;

  final bool isDark;
  final Color accent;

  Color get canvas => isDark ? const Color(0xFF0E0E12) : const Color(0xFFF7F7FA);

  Color get onCanvas =>
      isDark ? CupertinoColors.white : MusifiedStyle.lightOnSurface;

  Color get muted =>
      isDark ? MusifiedStyle.secondaryLabel : MusifiedStyle.lightSecondaryLabel;

  Color get faint =>
      isDark ? MusifiedStyle.tertiaryLabel : MusifiedStyle.lightTertiaryLabel;

  Color get hairline =>
      isDark ? const Color(0x1AFFFFFF) : const Color(0x14000000);

  Color get chipFill =>
      isDark ? const Color(0x22FFFFFF) : const Color(0x12000000);

  Color lineColor({
    required bool isActive,
    required bool isPast,
  }) {
    if (isActive) return onCanvas;
    if (isPast) return muted.withValues(alpha: isDark ? 0.78 : 0.82);
    return faint.withValues(alpha: isDark ? 0.62 : 0.68);
  }

  double fontSize({
    required bool isActive,
    required LyricsLayout layout,
  }) {
    switch (layout) {
      case LyricsLayout.compact:
        return isActive ? 20.5 : 14.5;
      case LyricsLayout.stage:
        return isActive ? 34 : 20;
    }
  }

  FontWeight fontWeight({required bool isActive}) =>
      isActive ? FontWeight.w700 : FontWeight.w500;

  double letterSpacing({required bool isActive, required LyricsLayout layout}) {
    if (layout == LyricsLayout.stage && isActive) return -1.1;
    if (isActive) return -0.45;
    return -0.15;
  }

  TextStyle lineStyle({
    required bool isActive,
    required bool isPast,
    required LyricsLayout layout,
  }) {
    return TextStyle(
      fontFamily: MusifiedStyle.displayFont,
      fontSize: fontSize(isActive: isActive, layout: layout),
      fontWeight: fontWeight(isActive: isActive),
      letterSpacing: letterSpacing(isActive: isActive, layout: layout),
      height: layout == LyricsLayout.stage ? 1.28 : 1.22,
      color: isActive
          ? (layout == LyricsLayout.stage ? accent : onCanvas)
          : lineColor(isActive: isActive, isPast: isPast),
      decoration: TextDecoration.none,
      shadows: isActive
          ? [
              Shadow(
                color: (layout == LyricsLayout.stage ? accent : onCanvas)
                    .withValues(alpha: layout == LyricsLayout.stage ? 0.35 : 0.18),
                blurRadius: layout == LyricsLayout.stage ? 18 : 10,
              ),
            ]
          : null,
    );
  }

  TextStyle plainBodyStyle(LyricsLayout layout) => TextStyle(
    fontFamily: MusifiedStyle.displayFont,
    fontSize: layout == LyricsLayout.compact ? 14 : 21,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
    height: 1.55,
    color: onCanvas.withValues(alpha: 0.9),
    decoration: TextDecoration.none,
  );

  TextStyle captionStyle() => TextStyle(
    fontFamily: MusifiedStyle.uiFont,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
    color: muted,
    decoration: TextDecoration.none,
  );
}

enum LyricsLayout { compact, stage }
