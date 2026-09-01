import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:musified/widgets/now_playing/lyrics/lrc_parser.dart';
import 'package:musified/widgets/now_playing/lyrics/lyrics_theme.dart';

/// Flip-card synced lyrics — centered spotlight stack matching full-screen stage.
class CompactLyricsPanel extends StatelessWidget {
  const CompactLyricsPanel({
    super.key,
    required this.lines,
    required this.currentIndex,
    required this.lineProgress,
    required this.theme,
    required this.onSeek,
    required this.onExpand,
  });

  final List<LrcLine> lines;
  final int currentIndex;
  final double lineProgress;
  final LyricsTheme theme;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final slots = _visibleSlots();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
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
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (final slot in slots)
                  _CompactLineSlot(
                    line: lines[slot.index],
                    role: slot.role,
                    theme: theme,
                    lineProgress: slot.role == _SlotRole.active ? lineProgress : 0,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onSeek(lines[slot.index].time);
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<_Slot> _visibleSlots() {
    if (lines.isEmpty) return const [];

    final idx = currentIndex < 0 ? 0 : currentIndex;
    final slots = <_Slot>[];

    if (idx > 0) {
      slots.add(_Slot(index: idx - 1, role: _SlotRole.past));
    }
    slots.add(_Slot(index: idx, role: _SlotRole.active));
    if (idx + 1 < lines.length) {
      slots.add(_Slot(index: idx + 1, role: _SlotRole.future));
    }
    return slots;
  }
}

enum _SlotRole { past, active, future }

class _Slot {
  const _Slot({required this.index, required this.role});
  final int index;
  final _SlotRole role;
}

class _CompactLineSlot extends StatelessWidget {
  const _CompactLineSlot({
    required this.line,
    required this.role,
    required this.theme,
    required this.lineProgress,
    required this.onTap,
  });

  final LrcLine line;
  final _SlotRole role;
  final LyricsTheme theme;
  final double lineProgress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = role == _SlotRole.active;
    final isPast = role == _SlotRole.past;

    final style = theme.lineStyle(
      isActive: isActive,
      isPast: isPast,
      layout: LyricsLayout.compact,
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(vertical: isActive ? 8 : 4),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          scale: isActive ? 1.0 : 0.94,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.08),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Text(
                  line.text,
                  key: ValueKey('${line.time}-${line.text}'),
                  style: style,
                  textAlign: TextAlign.center,
                  maxLines: isActive ? 4 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isActive) ...[
                const SizedBox(height: 10),
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
      width: 56,
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
            width: 56 * clamped,
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
