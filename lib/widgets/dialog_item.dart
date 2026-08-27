import 'package:flutter/cupertino.dart';
import 'package:musified/constants/app_constants.dart';
import 'package:musified/theme/app_themes.dart';
import 'package:musified/theme/musified_style.dart';

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
    final isDark = isAppDarkMode(context);
    final textColor = isDark ? CupertinoColors.white : CupertinoColors.black;

    return Padding(
      padding: padding,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        borderRadius: commonBarRadius,
        color: isDark ? MusifiedStyle.surface : const Color(0xFFE5E5EA),
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
                    fontFamily: MusifiedStyle.uiFont,
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: fontSize,
                    letterSpacing: -0.2,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              if (showChevron)
                const Icon(
                  CupertinoIcons.chevron_forward,
                  color: CupertinoColors.systemGrey,
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
