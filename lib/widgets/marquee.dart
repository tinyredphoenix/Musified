import 'package:flutter/cupertino.dart';

class MarqueeWidget extends StatefulWidget {
  const MarqueeWidget({
    super.key,
    required this.child,
    this.direction = Axis.horizontal,
    this.animationDuration = const Duration(milliseconds: 6000),
    this.backDuration = const Duration(milliseconds: 800),
    this.pauseDuration = const Duration(milliseconds: 800),
    this.manualScrollEnabled = true,
    this.alignment = Alignment.center,
  });

  final Widget child;
  final Axis direction;
  final Duration animationDuration, backDuration, pauseDuration;
  final bool manualScrollEnabled;

  final AlignmentGeometry alignment;

  @override
  State<MarqueeWidget> createState() => _MarqueeWidgetState();
}

class _MarqueeWidgetState extends State<MarqueeWidget>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late ScrollController _scrollController;
  bool _isAnimating = false;
  bool _isDisposed = false;

  @override
  bool get wantKeepAlive => false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAnimation());
  }

  @override
  void dispose() {
    _isDisposed = true;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return RepaintBoundary(
          child: SingleChildScrollView(
            scrollDirection: widget.direction,
            controller: _scrollController,
            physics: widget.manualScrollEnabled
                ? const AlwaysScrollableScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Align(alignment: widget.alignment, child: widget.child),
            ),
          ),
        );
      },
    );
  }

  Future<void> _startAnimation() async {
    if (_isDisposed || _isAnimating) return;

    _isAnimating = true;

    while (_scrollController.hasClients && !_isDisposed) {
      try {
        if (_scrollController.position.maxScrollExtent <= 0) {
          break;
        }

        await Future.delayed(widget.pauseDuration);
        if (_isDisposed || !_scrollController.hasClients) break;

        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: widget.animationDuration,
          curve: Curves.linear,
        );

        await Future.delayed(widget.pauseDuration);
        if (_isDisposed || !_scrollController.hasClients) break;

        await _scrollController.animateTo(
          0,
          duration: widget.backDuration,
          curve: Curves.easeOut,
        );
      } catch (e) {
        break;
      }
    }

    _isAnimating = false;
  }
}
