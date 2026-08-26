import 'package:flutter/cupertino.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/constants/app_constants.dart';
import 'package:musify/theme/musified_style.dart';

class DialogItem extends StatelessWidget {
  const DialogItem({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.label,
    required this.onTap,
    this.padding = const EdgeInsets.symmetric(vertical: 6),
    this.iconRightPadding = 12,
    this.iconSize = 22,
    this.iconContainerSize = 44,
    this.fontSize = 15,
    this.showChevron = true,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String label;
  final VoidCallback onTap;
  final EdgeInsets padding;
  final double iconRightPadding;
  final double iconSize;
  final double iconContainerSize;
  final double fontSize;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: padding,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        borderRadius: commonBarRadius,
        color: isDark ? MusifiedStyle.surface : MusifiedStyle.lightSurfaceHigh,
        onPressed: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: iconRightPadding,
            vertical: 12,
          ),
          child: Row(
            children: [
              Container(
                width: iconContainerSize,
                height: iconContainerSize,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(MusifiedStyle.radiusMd),
                ),
                child: Icon(icon, color: iconColor, size: iconSize),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: fontSize,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (showChevron)
                Icon(
                  CupertinoIcons.chevron_forward,
                  color: colorScheme.onSurfaceVariant,
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
