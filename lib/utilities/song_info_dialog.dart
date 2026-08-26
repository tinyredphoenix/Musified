import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:musify/services/common_services.dart';

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

  final colorScheme = Theme.of(context).colorScheme;

  showCupertinoModalPopup(
    context: context,
    builder: (context) => CupertinoActionSheet(
      title: Column(
        children: [
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            artist,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _infoRow('Source', source, isHighlight: true, color: colorScheme.primary),
                const Divider(height: 16, thickness: 0.5),
                _infoRow('Audio Bitrate', bitrate),
                const Divider(height: 16, thickness: 0.5),
                _infoRow('Audio Codec', format),
                const Divider(height: 16, thickness: 0.5),
                _infoRow('Storage Status', isOffline ? 'Downloaded ($fileSize)' : 'Streaming Online'),
                if (isOffline) ...[
                  const Divider(height: 16, thickness: 0.5),
                  _infoRow('Downloaded At', dateAdded),
                ],
              ],
            ),
          ),
        ],
      ),
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: true,
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ),
  );
}

Widget _infoRow(String label, String value, {bool isHighlight = false, Color? color}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      Flexible(
        child: Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}
