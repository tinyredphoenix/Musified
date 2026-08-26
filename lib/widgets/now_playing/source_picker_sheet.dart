import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/services.dart';
import 'package:musify/main.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/utilities/flutter_toast.dart';

/// Compact iOS list for picking JioSaavn / YouTube / offline.
/// Tap never switches immediately — the user must pick a row.
void showAudioSourcePicker(BuildContext context, MediaItem metadata) {
  final extras = metadata.extras ?? {};
  final currentSource = extras['resolvedSource'] as String? ?? 'youtube';
  final ytid = extras['ytid']?.toString() ?? '';
  final isOffline = extras['isOffline'] == true || hasPlayableOfflineFile(ytid);

  showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) {
      final brightness = MediaQuery.platformBrightnessOf(ctx);
      final sheetBg = brightness == Brightness.dark
          ? const Color(0xFF1C1C1E)
          : const Color(0xFFF2F2F7);
      final rowBg = brightness == Brightness.dark
          ? const Color(0xFF2C2C2E)
          : CupertinoColors.white;
      final label = CupertinoDynamicColor.resolve(
        CupertinoColors.label,
        ctx,
      );
      final secondary = CupertinoDynamicColor.resolve(
        CupertinoColors.secondaryLabel,
        ctx,
      );
      final separator = CupertinoDynamicColor.resolve(
        CupertinoColors.separator,
        ctx,
      );

      Widget row({
        required IconData icon,
        required Color iconColor,
        required String title,
        required String subtitle,
        required bool selected,
        required bool enabled,
        required VoidCallback? onTap,
      }) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.45,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, color: iconColor, size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: label,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(fontSize: 13, color: secondary, decoration: TextDecoration.none),
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    const Icon(
                      CupertinoIcons.checkmark_alt,
                      size: 20,
                      color: CupertinoColors.activeBlue,
                    ),
                ],
              ),
            ),
          ),
        );
      }

      Future<void> select(String source) async {
        Navigator.pop(ctx);
        if (currentSource == source) return;
        HapticFeedback.selectionClick();
        final success = await audioHandler.switchSource(source);
        if (!success && context.mounted) {
          showToast(
            context,
            source == 'jiosaavn'
                ? 'Track not available on JioSaavn'
                : 'Track not available on YouTube',
          );
        }
      }

      return SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Material(
          type: MaterialType.transparency,
          child: DefaultTextStyle(
            style: TextStyle(
              fontFamily: '.SF Pro Text',
              decoration: TextDecoration.none,
              color: label,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: sheetBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                        child: Text(
                          'Audio source',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: secondary,
                            letterSpacing: 0.2,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        decoration: BoxDecoration(
                          color: rowBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            row(
                              icon: CupertinoIcons.music_note_2,
                              iconColor: CupertinoColors.systemGreen,
                              title: 'JioSaavn',
                              subtitle: isOffline
                                  ? 'Unavailable while playing offline'
                                  : '320k AAC Lossless',
                              selected: !isOffline && currentSource == 'jiosaavn',
                              enabled: !isOffline,
                              onTap: () => select('jiosaavn'),
                            ),
                            Container(height: 0.5, color: separator),
                            row(
                              icon: CupertinoIcons.play_circle_fill,
                              iconColor: const Color(0xFFFF0033),
                              title: 'YouTube Music',
                              subtitle: isOffline
                                  ? 'Unavailable while playing offline'
                                  : '160k AAC',
                              selected: !isOffline && currentSource == 'youtube',
                              enabled: !isOffline,
                              onTap: () => select('youtube'),
                            ),
                            Container(height: 0.5, color: separator),
                            row(
                              icon: CupertinoIcons.arrow_down_circle_fill,
                              iconColor: CupertinoColors.systemBlue,
                              title: 'Downloaded',
                              subtitle: isOffline
                                  ? 'Playing from this device'
                                  : 'Download this track to use offline',
                              selected: isOffline,
                              enabled: false,
                              onTap: null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: rowBg,
                    borderRadius: BorderRadius.circular(14),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                        color: CupertinoDynamicColor.resolve(
                          CupertinoColors.activeBlue,
                          ctx,
                        ),
                      ),
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
}

IconData audioSourceIcon(MediaItem metadata) {
  final extras = metadata.extras ?? {};
  if (extras['resolvedSource'] == 'jiosaavn') {
    return CupertinoIcons.music_note_2;
  }
  return CupertinoIcons.play_circle_fill;
}

Color audioSourceColor(MediaItem metadata) {
  final extras = metadata.extras ?? {};
  if (extras['resolvedSource'] == 'jiosaavn') {
    return CupertinoColors.systemGreen;
  }
  return const Color(0xFFFF0033);
}
