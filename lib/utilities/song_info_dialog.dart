import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:musified/services/common_services.dart';
import 'package:musified/theme/musified_style.dart';

void showSongInfoDialog(BuildContext context, Map song) async {
  final ytid = song['ytid']?.toString() ?? '';
  final offlineSong = getOfflineSongByYtid(ytid);
  final isOffline = isSongAlreadyOffline(ytid);

  final title = song['title']?.toString() ?? 'Unknown Title';
  final artist = song['artist']?.toString() ?? 'Unknown Artist';

  String source = 'YouTube Music';
  if (isOffline) {
    final s = offlineSong['downloadSource']?.toString().toLowerCase();
    source = (s == 'saavn' || s == 'jiosaavn') ? 'JioSaavn 320k' : 'YouTube Music';
  } else if (song['resolvedSource'] != null) {
    source = song['resolvedSource'] == 'jiosaavn' ? 'JioSaavn 320k' : 'YouTube Music';
  }

  String bitrate = '160 kbps';
  if (isOffline && offlineSong['audioBitrateKbps'] != null) {
    bitrate = '${offlineSong['audioBitrateKbps']} kbps';
  } else if (song['resolvedBitrate'] != null) {
    bitrate = '${song['resolvedBitrate']} kbps';
  } else if (source.contains('JioSaavn')) {
    bitrate = '320 kbps (Lossless)';
  }

  String format = 'AAC';
  if (isOffline && offlineSong['audioCodec'] != null) {
    format = offlineSong['audioCodec'].toString();
  } else if (song['resolvedFormat'] != null) {
    format = song['resolvedFormat'].toString();
  }

  String fileSize = 'Streaming';
  if (isOffline) {
    final audioPath = offlineSong['audioPath']?.toString();
    if (audioPath != null) {
      final file = File(audioPath);
      if (await file.exists()) {
        final bytes = await file.length();
        fileSize = '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
      }
    }
  }

  String dateAdded = 'Unknown';
  if (isOffline && offlineSong['dateAdded'] != null) {
    final dt = DateTime.fromMillisecondsSinceEpoch(
      offlineSong['dateAdded'] is int
          ? offlineSong['dateAdded']
          : int.tryParse(offlineSong['dateAdded'].toString()) ?? 0,
    );
    dateAdded = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  if (!context.mounted) return;

  final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  final cardBg = isDark ? const Color(0xFF2C2C2E) : CupertinoColors.white;
  const secondaryColor = CupertinoColors.systemGrey;
  final labelColor = isDark ? CupertinoColors.white : CupertinoColors.black;
  final separatorColor = isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000);

  unawaited(showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: Column(
        children: [
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontFamily: MusifiedStyle.displayFont,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: labelColor,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            artist,
            style: TextStyle(
              fontFamily: MusifiedStyle.uiFont,
              fontSize: 14,
              color: secondaryColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _infoRow('Audio Source', source, isDark, highlightColor: const Color(0xFFFF2D55)),
                Container(height: 0.5, color: separatorColor, margin: const EdgeInsets.symmetric(vertical: 8)),
                _infoRow('Audio Bitrate', bitrate, isDark),
                Container(height: 0.5, color: separatorColor, margin: const EdgeInsets.symmetric(vertical: 8)),
                _infoRow('Audio Codec', format, isDark),
                Container(height: 0.5, color: separatorColor, margin: const EdgeInsets.symmetric(vertical: 8)),
                _infoRow('Storage', isOffline ? 'Downloaded ($fileSize)' : 'Streaming Online', isDark),
                if (isOffline) ...[
                  Container(height: 0.5, color: separatorColor, margin: const EdgeInsets.symmetric(vertical: 8)),
                  _infoRow('Saved Date', dateAdded, isDark),
                ],
              ],
            ),
          ),
        ],
      ),
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: true,
        onPressed: () => Navigator.pop(ctx),
        child: const Text('Done'),
      ),
    ),
  ));
}

Widget _infoRow(String label, String value, bool isDark, {Color? highlightColor}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontFamily: MusifiedStyle.uiFont,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: CupertinoColors.systemGrey,
        ),
      ),
      Flexible(
        child: Text(
          value,
          style: TextStyle(
            fontFamily: MusifiedStyle.uiFont,
            fontSize: 13,
            fontWeight: highlightColor != null ? FontWeight.w700 : FontWeight.w600,
            color: highlightColor ?? (isDark ? CupertinoColors.white : CupertinoColors.black),
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}
