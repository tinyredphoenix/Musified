import 'package:flutter/cupertino.dart';
import 'package:musified/theme/musified_style.dart';

class BottomSheetBar extends StatelessWidget {
  const BottomSheetBar(
    this.title,
    this.onTap,
    this.isSelected, {
    this.icon,
    super.key,
  });
  final String title;
  final VoidCallback onTap;
  final bool isSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final primary = const Color(0xFFFF2D55);
    final bgColor = isSelected
        ? primary.withValues(alpha: isDark ? 0.18 : 0.12)
        : (isDark ? MusifiedStyle.surface : const Color(0xFFE5E5EA));
    final fgColor = isSelected
        ? primary
        : (isDark ? CupertinoColors.white : CupertinoColors.black);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(MusifiedStyle.radiusMd),
        color: bgColor,
        onPressed: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 22, color: fgColor),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: MusifiedStyle.uiFont,
                    color: fgColor,
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    letterSpacing: -0.2,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  CupertinoIcons.checkmark_alt,
                  size: 18,
                  color: Color(0xFFFF2D55),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
