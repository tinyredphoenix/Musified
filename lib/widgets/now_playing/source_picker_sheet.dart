import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:musified/main.dart';
import 'package:musified/services/common_services.dart';
import 'package:musified/theme/app_themes.dart';
import 'package:musified/theme/musified_style.dart';
import 'package:musified/utilities/flutter_toast.dart';

/// Compact iOS action sheet for selecting JioSaavn, YouTube Music, or Downloaded playback.
void showAudioSourcePicker(BuildContext context, MediaItem metadata) {
  final extras = metadata.extras ?? {};
  final ytid = extras['ytid']?.toString() ?? '';
  final hasDownload = hasPlayableOfflineFile(ytid);
  final resolvedSource = extras['resolvedSource'] as String?;
  final playingOffline = resolvedSource == 'offline' ||
      (resolvedSource == null && (extras['isOffline'] == true || hasDownload));
  final currentSource = playingOffline
      ? 'offline'
      : (resolvedSource ?? 'youtube');
  final isOffline = playingOffline;

  showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) {
      final isDark = isAppDarkMode(ctx);
      final sheetBg = musifiedElevatedSurface(isDark);
      final rowBg = isDark ? musifiedSecondarySurface(isDark) : CupertinoColors.white;
      final label = isDark ? CupertinoColors.white : CupertinoColors.black;
      final secondary = CupertinoColors.systemGrey;
      final separator = isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000);

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
                            fontFamily: MusifiedStyle.uiFont,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: label,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontFamily: MusifiedStyle.uiFont,
                            fontSize: 13,
                            color: secondary,
                            decoration: TextDecoration.none,
                          ),
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
        final actual = await audioHandler.switchSource(source);
        if (!context.mounted) return;
        if (actual == null) {
          showToast(
            context,
            switch (source) {
              'jiosaavn' => 'Track not available on JioSaavn',
              'offline' => 'No downloaded file for this track',
              _ => 'Track not available on YouTube',
            },
          );
        } else if (actual != source) {
          const names = {
            'jiosaavn': 'JioSaavn',
            'youtube': 'YouTube',
            'offline': 'the download',
          };
          showToast(
            context,
            'Not on ${names[source] ?? source} — playing from ${names[actual] ?? actual}',
          );
        }
      }

      return SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
                      'Audio Source',
                      style: TextStyle(
                        fontFamily: MusifiedStyle.uiFont,
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
                          subtitle: '320k AAC Lossless',
                          selected: currentSource == 'jiosaavn',
                          enabled: true,
                          onTap: () => select('jiosaavn'),
                        ),
                        Container(height: 0.5, color: separator),
                        row(
                          icon: CupertinoIcons.play_circle_fill,
                          iconColor: const Color(0xFFFF0033),
                          title: 'YouTube Music',
                          subtitle: '160k AAC',
                          selected: currentSource == 'youtube',
                          enabled: true,
                          onTap: () => select('youtube'),
                        ),
                        Container(height: 0.5, color: separator),
                        row(
                          icon: CupertinoIcons.arrow_down_circle_fill,
                          iconColor: CupertinoColors.systemBlue,
                          title: 'Downloaded',
                          subtitle: hasDownload
                              ? (isOffline
                                  ? 'Playing from this device'
                                  : 'Play the downloaded copy')
                              : 'Download this track to use offline',
                          selected: isOffline,
                          enabled: hasDownload && !isOffline,
                          onTap: hasDownload ? () => select('offline') : null,
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
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.activeBlue,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

bool _isPlayingOffline(Map extras) {
  final resolvedSource = extras['resolvedSource'];
  if (resolvedSource == 'offline') return true;
  if (resolvedSource == 'youtube' || resolvedSource == 'jiosaavn') return false;
  final ytid = extras['ytid']?.toString() ?? '';
  return extras['isOffline'] == true || hasPlayableOfflineFile(ytid);
}

IconData audioSourceIcon(MediaItem metadata) {
  final extras = metadata.extras ?? {};
  if (_isPlayingOffline(extras)) return CupertinoIcons.device_phone_portrait;
  if (extras['resolvedSource'] == 'jiosaavn') {
    return CupertinoIcons.music_note_2;
  }
  return CupertinoIcons.play_circle_fill;
}

Color audioSourceColor(MediaItem metadata) {
  final extras = metadata.extras ?? {};
  if (_isPlayingOffline(extras)) return CupertinoColors.systemGrey;
  if (extras['resolvedSource'] == 'jiosaavn') {
    return CupertinoColors.systemGreen;
  }
  return const Color(0xFFFF0033);
}
