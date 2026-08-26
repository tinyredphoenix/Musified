// ignore_for_file: deprecated_member_use
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:musify/services/settings_manager.dart';

class DownloadPickerSheet extends StatefulWidget {
  const DownloadPickerSheet({
    required this.song,
    required this.onDownload,
    super.key,
  });

  final Map song;
  final void Function(String source, String quality) onDownload;

  @override
  State<DownloadPickerSheet> createState() => _DownloadPickerSheetState();
}

class _DownloadPickerSheetState extends State<DownloadPickerSheet> {
  late String _selectedSource = downloadSource.value == 'jiosaavn'
      ? 'saavn'
      : downloadSource.value;
  late String _selectedQuality = downloadQuality.value;

  @override
  Widget build(BuildContext context) {
    final title = widget.song['title']?.toString() ?? 'Song';
    final artist = widget.song['artist']?.toString() ?? '';
    final colorScheme = Theme.of(context).colorScheme;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    // Keep the sheet's selection state recognisably iOS even when the app's
    // user accent is yellow or another high-contrast color.
    final selectionColor = isIOS
        ? CupertinoColors.activeBlue
        : colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Download',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            artist.isEmpty ? title : '$title • $artist',
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          Text(
            'Source',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          _buildSourceOption(
            'best',
            'Best Quality',
            'JioSaavn 320k if available, YouTube otherwise',
            colorScheme,
            isIOS,
            selectionColor,
          ),
          _buildSourceOption(
            'saavn',
            'JioSaavn',
            '320k AAC',
            colorScheme,
            isIOS,
            selectionColor,
          ),
          _buildSourceOption(
            'youtube',
            'YouTube',
            'Up to 160k Opus',
            colorScheme,
            isIOS,
            selectionColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Quality',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                for (final q in ['128', '160', '320'])
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedQuality = q),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedQuality == q
                              ? selectionColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$q kbps',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: _selectedQuality == q
                                ? (isIOS
                                      ? CupertinoColors.white
                                      : colorScheme.onPrimary)
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: isIOS
                ? CupertinoButton.filled(
                    borderRadius: BorderRadius.circular(12),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onDownload(_selectedSource, _selectedQuality);
                    },
                    child: const Text(
                      'Download',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  )
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onDownload(_selectedSource, _selectedQuality);
                    },
                    child: const Text(
                      'Download',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    ),
  );
}

  Widget _buildSourceOption(
    String value,
    String title,
    String subtitle,
    ColorScheme cs,
    bool isIOS,
    Color selectionColor,
  ) {
    final selected = _selectedSource == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedSource = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? selectionColor.withValues(alpha: 0.10)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? selectionColor.withValues(alpha: 0.4)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? (isIOS
                        ? CupertinoIcons.checkmark_alt_circle_fill
                        : Icons.check_circle)
                  : (isIOS
                        ? CupertinoIcons.circle
                        : Icons.radio_button_unchecked),
              color: selected
                  ? selectionColor
                  : cs.onSurfaceVariant.withValues(alpha: 0.5),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: selected ? selectionColor : cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showDownloadPicker(
  BuildContext context,
  Map song,
  void Function(String source, String quality) onDownload,
) {
  final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
  if (isIOS) {
    return showCupertinoModalPopup(
      context: context,
      builder: (ctx) => DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          top: false,
          child: DownloadPickerSheet(song: song, onDownload: onDownload),
        ),
      ),
    );
  }
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) =>
        DownloadPickerSheet(song: song, onDownload: onDownload),
  );
}
