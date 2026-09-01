import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:musified/main.dart';
import 'package:musified/theme/app_themes.dart';
import 'package:musified/theme/musified_style.dart';
import 'package:musified/widgets/mini_player.dart';

OverlayEntry? _activeToast;
Timer? _toastTimer;

void showToast(
  BuildContext context,
  String text, {
  Duration duration = const Duration(seconds: 2),
  IconData? icon,
}) {
  _dismissToast();

  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  final isDark = isAppDarkMode(context);
  final isMiniPlayerVisible =
      isAudioHandlerInitialized && audioHandler.mediaItem.valueOrNull != null;
  final bottom =
      16.0 +
      MediaQuery.paddingOf(context).bottom +
      (isMiniPlayerVisible ? MiniPlayer.playerHeight + 8 : 0);

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) {
      return IgnorePointer(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, bottom),
            child: AnimatedOpacity(
              opacity: 1,
              duration: const Duration(milliseconds: 180),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? musifiedSecondarySurface(isDark)
                      : const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon ?? CupertinoIcons.checkmark_circle_fill,
                      size: 18,
                      color: const Color(0xFFFF2D55),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        text,
                        style: const TextStyle(
                          fontFamily: MusifiedStyle.uiFont,
                          color: CupertinoColors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.15,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  _activeToast = entry;
  overlay.insert(entry);
  _toastTimer = Timer(duration, _dismissToast);
}

void showToastWithButton(
  BuildContext context,
  String text,
  String buttonName,
  VoidCallback onPressedToast, {
  Duration duration = const Duration(seconds: 3),
  IconData? icon,
}) {
  _dismissToast();

  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  final isDark = isAppDarkMode(context);
  final isMiniPlayerVisible =
      isAudioHandlerInitialized && audioHandler.mediaItem.valueOrNull != null;
  final bottom =
      16.0 +
      MediaQuery.paddingOf(context).bottom +
      (isMiniPlayerVisible ? MiniPlayer.playerHeight + 8 : 0);

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, bottom),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? musifiedSecondarySurface(isDark)
                  : const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon ?? CupertinoIcons.info_circle_fill,
                  size: 18,
                  color: const Color(0xFFFF2D55),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontFamily: MusifiedStyle.uiFont,
                      color: CupertinoColors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: Size.zero,
                  onPressed: () {
                    _dismissToast();
                    onPressedToast();
                  },
                  child: Text(
                    buttonName,
                    style: const TextStyle(
                      fontFamily: MusifiedStyle.uiFont,
                      color: Color(0xFFFF2D55),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  _activeToast = entry;
  overlay.insert(entry);
  _toastTimer = Timer(duration, _dismissToast);
}

void _dismissToast() {
  _toastTimer?.cancel();
  _toastTimer = null;
  _activeToast?.remove();
  _activeToast = null;
}
