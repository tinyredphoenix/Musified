/*
 * Transient HUD toast — Cupertino-feeling, theme-aware, no Material SnackBar.
 */

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/main.dart';
import 'package:musify/theme/musified_style.dart';
import 'package:musify/widgets/mini_player.dart';

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

  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final isDark = theme.brightness == Brightness.dark;
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
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isDark
                      ? MusifiedStyle.surfaceHigh
                      : MusifiedStyle.lightOnSurface,
                  borderRadius: BorderRadius.circular(MusifiedStyle.radiusPill),
                  border: Border.all(
                    color: isDark
                        ? MusifiedStyle.hairline
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon ?? CupertinoIcons.checkmark_alt_circle_fill,
                        size: 18,
                        color: isDark
                            ? scheme.primary
                            : Colors.white.withValues(alpha: 0.92),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          text,
                          style: TextStyle(
                            color: isDark ? scheme.onSurface : Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.15,
                          ),
                        ),
                      ),
                    ],
                  ),
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

  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final isDark = theme.brightness == Brightness.dark;
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
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isDark
                  ? MusifiedStyle.surfaceHigh
                  : MusifiedStyle.lightOnSurface,
              borderRadius: BorderRadius.circular(MusifiedStyle.radiusPill),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon ?? CupertinoIcons.info_circle_fill,
                    size: 18,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      text,
                      style: TextStyle(
                        color: isDark ? scheme.onSurface : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
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
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
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

void _dismissToast() {
  _toastTimer?.cancel();
  _toastTimer = null;
  _activeToast?.remove();
  _activeToast = null;
}
