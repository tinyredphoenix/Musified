import 'package:flutter/cupertino.dart';
import 'package:musified/widgets/section_title.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.actionButton,
  });
  final String title;
  final IconData? icon;
  final Widget? actionButton;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: SectionTitle(
            title,
            const Color(0xFFFF2D55),
            icon: icon,
          ),
        ),
        if (actionButton != null) actionButton!,
      ],
    );
  }
}
