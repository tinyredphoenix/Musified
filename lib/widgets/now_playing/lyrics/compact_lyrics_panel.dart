import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:musified/theme/musified_style.dart';
import 'package:musified/widgets/now_playing/lyrics/lrc_parser.dart';
import 'package:musified/widgets/now_playing/lyrics/lyrics_theme.dart';

/// Flip-card synced lyrics — tight spotlight stack (no scroll list).
class CompactLyricsPanel extends StatelessWidget {
  const CompactLyricsPanel({
    super.key,
    required this.lines,
    required this.currentIndex,
    required this.theme,
    required this.onSeek,
    required this.onExpand,
  });

  final List<LrcLine> lines;
  final int currentIndex;
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
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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

    final baseStyle = theme.lineStyle(
      isActive: isActive,
      isPast: isPast,
      layout: LyricsLayout.compact,
    );
    final style = baseStyle;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          vertical: isActive ? 6 : 3,
        ),
        child: isActive
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 3,
                    height: (style.fontSize ?? 18) * 1.15,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: theme.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.12),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: Text(
                        line.text,
                        key: ValueKey(line.text),
                        style: style,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              )
            : Text(
                line.text,
                style: style,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.left,
              ),
      ),
    );
  }
}
