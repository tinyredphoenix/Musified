import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:musified/widgets/now_playing/lyrics/lrc_parser.dart';
import 'package:musified/widgets/now_playing/lyrics/lyrics_theme.dart';

/// Compact (mini-player) Apple Music-style lyrics panel.
///
/// Shows 3 lines centered vertically:
///   - Previous line: past color (~40% opacity), smaller.
///   - Active line:   full brightness, large, bold.
///   - Next line:     future color (~20% opacity), smaller.
///
/// No progress bar. Tap any line to seek. Tap expand button for full screen.
class CompactLyricsPanel extends StatelessWidget {
  const CompactLyricsPanel({
    super.key,
    required this.lines,
    required this.currentIndex,
    required this.lineProgress, // retained in signature, not displayed
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
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final slot in slots)
                  _CompactLineSlot(
                    line: lines[slot.index],
                    role: slot.role,
                    theme: theme,
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
    if (idx > 0) slots.add(_Slot(index: idx - 1, role: _SlotRole.past));
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
    required this.onTap,
  });

  final LrcLine line;
  final _SlotRole role;
  final LyricsTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = role == _SlotRole.active;
    final isPast = role == _SlotRole.past;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(vertical: isActive ? 10 : 5),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          scale: isActive ? 1.0 : 0.91,
          alignment: Alignment.centerLeft,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            style: theme.lineStyle(
              isActive: isActive,
              isPast: isPast,
              layout: LyricsLayout.compact,
            ),
            child: Text(
              line.text,
              textAlign: TextAlign.left,
              maxLines: isActive ? 4 : 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
