/*
 * Lightweight artwork ↔ lyrics toggle.
 * Crossfade only — no 3D matrix flip (CPU/GPU friendly on LiveContainer).
 */

import 'package:flutter/widgets.dart';

enum RotateSide { right, left, top, bottom }

class FlipCardController {
  _FlipCardState? _state;
  final ValueNotifier<bool> isFront = ValueNotifier<bool>(true);

  Future<void> flipcard() async {
    await _state?.flipCard();
  }

  void dispose() {
    isFront.dispose();
  }
}

class FlipCard extends StatefulWidget {
  const FlipCard({
    super.key,
    required this.frontWidget,
    required this.backWidget,
    required this.controller,
    required this.rotateSide,
    this.onTapFlipping = false,
    this.animationDuration = const Duration(milliseconds: 280),
  });

  final Widget frontWidget;
  final Widget backWidget;
  final FlipCardController controller;
  final bool onTapFlipping;
  // Kept for API compatibility; unused after dropping 3D rotate.
  final RotateSide rotateSide;
  final Duration animationDuration;

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard> {
  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
  }

  @override
  void didUpdateWidget(FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller._state == this) {
        oldWidget.controller._state = null;
      }
      widget.controller._state = this;
    }
  }

  @override
  void dispose() {
    if (widget.controller._state == this) {
      widget.controller._state = null;
    }
    super.dispose();
  }

  Future<void> flipCard() async {
    widget.controller.isFront.value = !widget.controller.isFront.value;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTapFlipping ? flipCard : null,
      child: ValueListenableBuilder<bool>(
        valueListenable: widget.controller.isFront,
        builder: (context, showFront, _) {
          return AnimatedSwitcher(
            duration: widget.animationDuration,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (currentChild, previousChildren) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              );
            },
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: KeyedSubtree(
              key: ValueKey(showFront),
              child: showFront ? widget.frontWidget : widget.backWidget,
            ),
          );
        },
      ),
    );
  }
}
