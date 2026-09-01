import 'package:flutter/cupertino.dart';
import 'package:musified/theme/app_themes.dart';
import 'package:musified/theme/musified_style.dart';

class CustomBar extends StatelessWidget {
  const CustomBar(
    this.tileName,
    this.tileIcon, {
    this.description,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.backgroundColor,
    this.iconColor,
    this.textColor,
    this.borderRadius = BorderRadius.zero,
    super.key,
  });

  final String tileName;
  final IconData tileIcon;
  final String? description;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final Color? backgroundColor;
  final Color? iconColor;
  final Color? textColor;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDarkMode(context);
    final defaultBg = musifiedElevatedSurface(isDark);
    final iconContainerBg = musifiedSecondarySurface(isDark);
    final effectiveIconColor = iconColor ?? const Color(0xFFFF2D55);
    final effectiveTextColor = textColor ?? (isDark ? CupertinoColors.white : CupertinoColors.black);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor ?? defaultBg,
          borderRadius: borderRadius,
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconContainerBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(tileIcon, size: 24, color: effectiveIconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tileName,
                    style: TextStyle(
                      fontFamily: MusifiedStyle.uiFont,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: effectiveTextColor,
                      decoration: TextDecoration.none,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      description!,
                      style: const TextStyle(
                        fontFamily: MusifiedStyle.uiFont,
                        fontSize: 13,
                        color: CupertinoColors.systemGrey,
                        decoration: TextDecoration.none,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
