import 'package:flutter/cupertino.dart';
import 'package:musified/theme/musified_style.dart';

bool _isIOSSheetOpen = false;

bool isBottomSheetOpen() => _isIOSSheetOpen;

/// Shows a bottom sheet using the Musified pure iOS presentation style.
dynamic showCustomBottomSheet(BuildContext context, Widget content) {
  final size = MediaQuery.sizeOf(context);
  final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  final sheetColor = isDark ? MusifiedStyle.elevated : MusifiedStyle.lightElevated;

  _isIOSSheetOpen = true;
  showCupertinoModalPopup<void>(
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
                  color: isDark ? const Color(0x66FFFFFF) : const Color(0x33000000),
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
                physics: const BouncingScrollPhysics(),
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
  if (context != null) {
    Navigator.of(context, rootNavigator: true).maybePop();
  }
  _isIOSSheetOpen = false;
}
