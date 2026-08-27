import 'package:flutter/cupertino.dart';
import 'package:musified/services/settings_manager.dart';
import 'package:musified/theme/musified_style.dart';

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
    final title = widget.song['title']?.toString() ?? 'Track';
    final artist = widget.song['artist']?.toString() ?? '';
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final primaryColor = const Color(0xFFFF2D55);
    final cardBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
    final textColor = isDark ? CupertinoColors.white : CupertinoColors.black;
    final secondaryTextColor = CupertinoColors.systemGrey;

    return SafeArea(
      top: false,
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
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0x66FFFFFF) : const Color(0x33000000),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Download Track',
              style: TextStyle(
                fontFamily: MusifiedStyle.displayFont,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: textColor,
                letterSpacing: -0.3,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              artist.isEmpty ? title : '$title • $artist',
              style: TextStyle(
                fontFamily: MusifiedStyle.uiFont,
                fontSize: 13,
                color: secondaryTextColor,
                decoration: TextDecoration.none,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            Text(
              'SOURCE',
              style: TextStyle(
                fontFamily: MusifiedStyle.uiFont,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: secondaryTextColor,
                letterSpacing: 0.5,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 8),
            _buildSourceOption('saavn', 'JioSaavn 320k Lossless', 'High-definition 320 kbps AAC stream', isDark, primaryColor, cardBg, textColor, secondaryTextColor),
            _buildSourceOption('youtube', 'YouTube Music', 'Standard 160 kbps Opus/AAC stream', isDark, primaryColor, cardBg, textColor, secondaryTextColor),
            const SizedBox(height: 16),
            Text(
              'BITRATE',
              style: TextStyle(
                fontFamily: MusifiedStyle.uiFont,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: secondaryTextColor,
                letterSpacing: 0.5,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
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
                            color: _selectedQuality == q ? primaryColor : const Color(0x00000000),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$q kbps',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: MusifiedStyle.uiFont,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: _selectedQuality == q ? CupertinoColors.white : secondaryTextColor,
                              decoration: TextDecoration.none,
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
              child: CupertinoButton.filled(
                borderRadius: BorderRadius.circular(12),
                padding: const EdgeInsets.symmetric(vertical: 14),
                onPressed: () {
                  Navigator.pop(context);
                  widget.onDownload(_selectedSource, _selectedQuality);
                },
                child: const Text(
                  'Download Now',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceOption(
    String value,
    String title,
    String subtitle,
    bool isDark,
    Color primaryColor,
    Color cardBg,
    Color textColor,
    Color secondaryTextColor,
  ) {
    final selected = _selectedSource == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedSource = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? primaryColor.withValues(alpha: 0.12) : cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? primaryColor : const Color(0x00000000),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
              color: selected ? primaryColor : secondaryTextColor,
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
                      fontFamily: MusifiedStyle.uiFont,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: selected ? primaryColor : textColor,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: MusifiedStyle.uiFont,
                      fontSize: 12,
                      color: secondaryTextColor,
                      decoration: TextDecoration.none,
                    ),
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
  final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;

  return showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DownloadPickerSheet(song: song, onDownload: onDownload),
    ),
  );
}
