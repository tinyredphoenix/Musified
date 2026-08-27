import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:musified/services/settings_manager.dart';
import 'package:musified/services/source_resolver.dart';
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

  bool _isCheckingSaavn = true;
  bool _isSaavnAvailable = true;

  @override
  void initState() {
    super.initState();
    _checkSaavnAvailability();
  }

  Future<void> _checkSaavnAvailability() async {
    try {
      if (!jiosaavnEnabled.value) {
        if (mounted) {
          setState(() {
            _isSaavnAvailable = false;
            _isCheckingSaavn = false;
            _selectedSource = 'youtube';
            _selectedQuality = '160';
          });
        }
        return;
      }

      final match = await SourceResolver()
          .resolveAudioSource(widget.song)
          .timeout(const Duration(seconds: 2), onTimeout: () => null);

      if (mounted) {
        setState(() {
          _isSaavnAvailable = match != null && match['url'] != null;
          _isCheckingSaavn = false;
          if (!_isSaavnAvailable && _selectedSource == 'saavn') {
            _selectedSource = 'youtube';
            if (_selectedQuality == '320') _selectedQuality = '160';
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaavnAvailable = false;
          _isCheckingSaavn = false;
          if (_selectedSource == 'saavn') {
            _selectedSource = 'youtube';
            if (_selectedQuality == '320') _selectedQuality = '160';
          }
        });
      }
    }
  }

  List<String> get _availableBitrates =>
      _selectedSource == 'saavn' ? ['160', '320'] : ['128', '160'];

  @override
  Widget build(BuildContext context) {
    final title = widget.song['title']?.toString() ?? 'Track';
    final artist = widget.song['artist']?.toString() ?? '';
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    const primaryColor = Color(0xFFFF2D55);
    final cardBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);
    final textColor = isDark ? CupertinoColors.white : CupertinoColors.black;
    const secondaryTextColor = CupertinoColors.systemGrey;

    // Sanitize quality for current source
    if (!_availableBitrates.contains(_selectedQuality)) {
      _selectedQuality = _availableBitrates.last;
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 14,
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
              style: const TextStyle(
                fontFamily: MusifiedStyle.uiFont,
                fontSize: 13,
                color: secondaryTextColor,
                decoration: TextDecoration.none,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 18),
            const Text(
              'AUDIO PROVIDER',
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
            _buildSourceOption(
              value: 'saavn',
              title: 'JioSaavn Lossless',
              subtitle: _isCheckingSaavn
                  ? 'Checking availability...'
                  : (_isSaavnAvailable
                      ? 'Studio Master 320 kbps AAC'
                      : 'Not available on JioSaavn for this track'),
              icon: CupertinoIcons.waveform,
              iconBg: CupertinoColors.systemGreen,
              isEnabled: !_isCheckingSaavn && _isSaavnAvailable,
              isDark: isDark,
              primaryColor: primaryColor,
              cardBg: cardBg,
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
            ),
            _buildSourceOption(
              value: 'youtube',
              title: 'YouTube Music',
              subtitle: 'Original Stream (Max 160 kbps Opus/AAC)',
              icon: CupertinoIcons.play_rectangle_fill,
              iconBg: const Color(0xFFFF0033),
              isEnabled: true,
              isDark: isDark,
              primaryColor: primaryColor,
              cardBg: cardBg,
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'BITRATE QUALITY',
                  style: TextStyle(
                    fontFamily: MusifiedStyle.uiFont,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: secondaryTextColor,
                    letterSpacing: 0.5,
                    decoration: TextDecoration.none,
                  ),
                ),
                Text(
                  _selectedSource == 'saavn' ? '320k Lossless' : 'YouTube Max 160k',
                  style: TextStyle(
                    fontFamily: MusifiedStyle.uiFont,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: primaryColor,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  for (final q in _availableBitrates)
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedQuality = q);
                        },
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
              child: CupertinoButton(
                color: primaryColor,
                borderRadius: BorderRadius.circular(14),
                padding: const EdgeInsets.symmetric(vertical: 14),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pop(context);
                  widget.onDownload(_selectedSource, _selectedQuality);
                },
                child: const Text(
                  'Download Now',
                  style: TextStyle(
                    fontFamily: MusifiedStyle.uiFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: CupertinoColors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBg,
    required bool isEnabled,
    required bool isDark,
    required Color primaryColor,
    required Color cardBg,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    final selected = _selectedSource == value;

    return GestureDetector(
      onTap: isEnabled
          ? () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedSource = value;
                if (value == 'youtube' && _selectedQuality == '320') {
                  _selectedQuality = '160';
                }
              });
            }
          : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isEnabled ? 1.0 : 0.45,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? primaryColor.withValues(alpha: 0.12) : cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? primaryColor : const Color(0x00000000),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: CupertinoColors.white, size: 18),
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
              Icon(
                selected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
                color: selected ? primaryColor : secondaryTextColor,
                size: 20,
              ),
            ],
          ),
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
