/*
 * iOS-style modal sheet — solid Musified surfaces, no blur tax.
 */

import 'package:flutter/cupertino.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/theme/musified_style.dart';

PersistentBottomSheetController? _currentBottomSheetController;
bool _isIOSSheetOpen = false;

/// Shows a bottom sheet using the Musified iOS presentation style.
dynamic showCustomBottomSheet(BuildContext context, Widget content) {
  final size = MediaQuery.sizeOf(context);
  final scheme = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final sheetColor =
      isDark ? MusifiedStyle.elevated : MusifiedStyle.lightElevated;

  _isIOSSheetOpen = true;
  showCupertinoModalPopup(
    context: context,
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: sheetColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(MusifiedStyle.radiusXl),
        ),
        border: Border(
          top: BorderSide(
            color: isDark ? MusifiedStyle.hairline : MusifiedStyle.lightHairline,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 8),
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: size.width,
                maxHeight: size.height * 0.72,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: content,
              ),
            ),
          ],
        ),
      ),
    ),
  ).whenComplete(() => _isIOSSheetOpen = false);
  return null;
}

void closeCurrentBottomSheet([BuildContext? context]) {
  if (_isIOSSheetOpen) {
    if (context != null) {
      Navigator.of(context, rootNavigator: true).maybePop();
    }
    _isIOSSheetOpen = false;
    return;
  }
  final controller = _currentBottomSheetController;
  if (controller != null) {
    controller.close();
    _currentBottomSheetController = null;
  } else if (context != null) {
    Navigator.of(context).maybePop();
  }
}
