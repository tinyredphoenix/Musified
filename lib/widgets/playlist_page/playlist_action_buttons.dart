import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/theme/musified_style.dart';

/// Play and shuffle — shared by playlist and artist pages.
class PlaylistActionButtons extends StatelessWidget {
  const PlaylistActionButtons({
    super.key,
    required this.onPlay,
    required this.onShuffle,
    this.isLoading = false,
  });

  final VoidCallback onPlay;
  final AsyncCallback onShuffle;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 14),
              borderRadius: BorderRadius.circular(MusifiedStyle.radiusPill),
              color: scheme.primary,
              onPressed: isLoading ? null : onPlay,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading)
                    const CupertinoActivityIndicator(radius: 9)
                  else
                    Icon(
                      CupertinoIcons.play_fill,
                      size: 18,
                      color: scheme.onPrimary,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.play,
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 14),
              borderRadius: BorderRadius.circular(MusifiedStyle.radiusPill),
              color: isDark
                  ? MusifiedStyle.surfaceHigh
                  : MusifiedStyle.lightSurfaceHigh,
              onPressed: isLoading ? null : onShuffle,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading)
                    CupertinoActivityIndicator(
                      radius: 9,
                      color: scheme.onSurface,
                    )
                  else
                    Icon(
                      CupertinoIcons.shuffle,
                      size: 18,
                      color: scheme.onSurface,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.shuffle,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
