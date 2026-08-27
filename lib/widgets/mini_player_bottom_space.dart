import 'package:flutter/cupertino.dart';

/// Adds the current bottom [MediaQuery] padding as scrollable space for the
/// floating mini player.
class MiniPlayerBottomSpace extends StatelessWidget {
  const MiniPlayerBottomSpace({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      top: false,
      left: false,
      right: false,
      child: SizedBox(height: 70),
    );
  }
}

/// Adds the current bottom [MediaQuery] padding as sliver scrollable space for
/// the floating mini player.
class SliverMiniPlayerBottomSpace extends StatelessWidget {
  const SliverMiniPlayerBottomSpace({super.key});

  @override
  Widget build(BuildContext context) {
    return const SliverSafeArea(
      top: false,
      left: false,
      right: false,
      sliver: SliverToBoxAdapter(child: SizedBox(height: 70)),
    );
  }
}
