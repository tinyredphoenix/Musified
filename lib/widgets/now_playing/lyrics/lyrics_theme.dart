import 'package:flutter/cupertino.dart';
import 'package:musified/theme/musified_style.dart';

/// Visual tokens for live / synced lyrics — Apple Music style.
///
/// Active line: full opacity, large, heavy weight, subtle glow.
/// Past lines:  muted ~40% — clearly read, clearly behind.
/// Future lines: very dim ~20% — readable but receding.
/// No accent colour on text; always white (dark) or black (light).
/// No progress underline bar — Apple Music does not have one.
class LyricsTheme {
  LyricsTheme({
    required this.isDark,
    required Color accent,
  }) : accent = accent == CupertinoColors.activeBlue
      ? const Color(0xFFFF2D55)
      : accent;

  final bool isDark;
  final Color accent;

  Color get canvas => isDark ? const Color(0xFF0A0A0E) : const Color(0xFFF2F2F7);

  Color get onCanvas =>
      isDark ? CupertinoColors.white : CupertinoColors.black;

  /// Past lines — clearly visible but receded.
  Color get pastColor =>
      onCanvas.withValues(alpha: isDark ? 0.42 : 0.38);

  /// Future / upcoming lines — very dim.
  Color get futureColor =>
      onCanvas.withValues(alpha: isDark ? 0.20 : 0.18);

  // Keep muted/faint/hairline/chipFill for other widgets that use LyricsTheme.
  Color get muted =>
      onCanvas.withValues(alpha: isDark ? 0.45 : 0.40);

  Color get faint =>
      onCanvas.withValues(alpha: isDark ? 0.28 : 0.25);

  Color get hairline =>
      isDark ? const Color(0x1AFFFFFF) : const Color(0x14000000);

  Color get chipFill =>
      isDark ? const Color(0x22FFFFFF) : const Color(0x12000000);

  Color lineColor({
    required bool isActive,
    required bool isPast,
  }) {
    if (isActive) return onCanvas;
    if (isPast) return pastColor;
    return futureColor;
  }

  double fontSize({
    required bool isActive,
    required LyricsLayout layout,
  }) {
    switch (layout) {
      case LyricsLayout.compact:
        // Mini-player: active line noticeably larger.
        return isActive ? 22 : 15;
      case LyricsLayout.stage:
        // Full-screen: Apple Music uses ~34–38pt active, ~22pt inactive.
        return isActive ? 36 : 22;
    }
  }

  FontWeight fontWeight({required bool isActive}) =>
      isActive ? FontWeight.w800 : FontWeight.w600;

  double letterSpacing({required bool isActive, required LyricsLayout layout}) {
    if (layout == LyricsLayout.stage && isActive) return -1.2;
    if (isActive) return -0.5;
    return -0.2;
  }

  TextStyle lineStyle({
    required bool isActive,
    required bool isPast,
    required LyricsLayout layout,
  }) {
    final color = lineColor(isActive: isActive, isPast: isPast);
    return TextStyle(
      fontFamily: MusifiedStyle.displayFont,
      fontSize: fontSize(isActive: isActive, layout: layout),
      fontWeight: fontWeight(isActive: isActive),
      letterSpacing: letterSpacing(isActive: isActive, layout: layout),
      height: layout == LyricsLayout.stage ? 1.25 : 1.20,
      color: color,
      decoration: TextDecoration.none,
      // Subtle glow on the active line in full-screen mode only.
      shadows: isActive && layout == LyricsLayout.stage
          ? [
              Shadow(
                color: onCanvas.withValues(alpha: isDark ? 0.22 : 0.12),
                blurRadius: 20,
              ),
            ]
          : null,
    );
  }

  TextStyle plainBodyStyle(LyricsLayout layout) => TextStyle(
    fontFamily: MusifiedStyle.displayFont,
    fontSize: layout == LyricsLayout.compact ? 15 : 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.55,
    color: onCanvas.withValues(alpha: 0.88),
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
