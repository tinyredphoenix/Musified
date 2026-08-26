/*
 * Sheet option row — Cupertino tap, Musified surfaces.
 */

import 'package:flutter/cupertino.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/theme/musified_style.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isSelected
        ? scheme.primary.withValues(alpha: isDark ? 0.18 : 0.12)
        : (isDark ? MusifiedStyle.surface : MusifiedStyle.lightSurfaceHigh);
    final fgColor = isSelected ? scheme.primary : scheme.onSurface;

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
                    color: fgColor,
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  CupertinoIcons.checkmark_alt,
                  size: 18,
                  color: scheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
