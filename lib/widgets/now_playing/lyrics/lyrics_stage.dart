import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:musified/widgets/now_playing/lyrics/lrc_parser.dart';
import 'package:musified/widgets/now_playing/lyrics/lyrics_theme.dart';

/// Full-screen cinematic synced lyrics with spotlight scroll and edge vignette.
class LyricsStage extends StatelessWidget {
  const LyricsStage({
    super.key,
    required this.lines,
    required this.currentIndex,
    required this.theme,
    required this.scrollController,
    required this.lineKeys,
    required this.onUserScroll,
    required this.onSeek,
    this.lineProgress = 0,
  });

  final List<LrcLine> lines;
  final int currentIndex;
  final LyricsTheme theme;
  final ScrollController scrollController;
  final List<GlobalKey> lineKeys;
  final VoidCallback onUserScroll;
  final ValueChanged<Duration> onSeek;
  final double lineProgress;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is UserScrollNotification) {
              onUserScroll();
            }
            return false;
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewportHeight = constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : MediaQuery.sizeOf(context).height;
              return ListView.builder(
                controller: scrollController,
                padding: EdgeInsets.symmetric(
                  vertical: viewportHeight * 0.34,
                  horizontal: 28,
                ),
                physics: const BouncingScrollPhysics(),
                itemCount: lines.length,
                itemBuilder: (context, index) {
                  final line = lines[index];
                  final isCurrent = index == currentIndex;
                  final isPast = index < currentIndex;
                  final key = index < lineKeys.length ? lineKeys[index] : null;

                  return _StageLine(
                    key: key,
                    line: line,
                    isCurrent: isCurrent,
                    isPast: isPast,
                    theme: theme,
                    lineProgress: isCurrent ? lineProgress : 0,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onSeek(line.time);
                    },
                  );
                },
              );
            },
          ),
        ),
        // Top vignette
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 120,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.canvas.withValues(alpha: theme.isDark ? 0.92 : 0.95),
                    theme.canvas.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Bottom vignette
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 100,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    theme.canvas.withValues(alpha: theme.isDark ? 0.88 : 0.92),
                    theme.canvas.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StageLine extends StatelessWidget {
  const _StageLine({
    super.key,
    required this.line,
    required this.isCurrent,
    required this.isPast,
    required this.theme,
    required this.lineProgress,
    required this.onTap,
  });

  final LrcLine line;
  final bool isCurrent;
  final bool isPast;
  final LyricsTheme theme;
  final double lineProgress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = theme.lineStyle(
      isActive: isCurrent,
      isPast: isPast,
      layout: LyricsLayout.stage,
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          vertical: isCurrent ? 16 : 9,
        ),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          scale: isCurrent ? 1.0 : 0.94,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: child,
                ),
                child: Text(
                  line.text,
                  key: ValueKey('${line.time}-${line.text}'),
                  style: style,
                  textAlign: TextAlign.center,
                ),
              ),
              if (isCurrent) ...[
                const SizedBox(height: 12),
                _LineProgressBar(
                  progress: lineProgress,
                  accent: theme.accent,
                  track: theme.hairline,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LineProgressBar extends StatelessWidget {
  const _LineProgressBar({
    required this.progress,
    required this.accent,
    required this.track,
  });

  final double progress;
  final Color accent;
  final Color track;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    return SizedBox(
      width: 72,
      height: 3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: track,
          borderRadius: BorderRadius.circular(2),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 72 * clamped,
            height: 3,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}
