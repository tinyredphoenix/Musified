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
  late String _selectedSource = downloadSource.value;
  late String _selectedQuality = downloadQuality.value;

  @override
  Widget build(BuildContext context) {
    final title = widget.song['title'] ?? 'Song';
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
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
          Text(
            'Download "$title"',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text('Source:', style: TextStyle(fontSize: 16)),
          RadioListTile<String>(
            title: const Text('Best Quality (JioSaavn 320k if available, YouTube otherwise)'),
            value: 'best',
            groupValue: _selectedSource,
            activeColor: colorScheme.primary,
            onChanged: (value) => setState(() => _selectedSource = value!),
            contentPadding: EdgeInsets.zero,
          ),
          RadioListTile<String>(
            title: const Text('JioSaavn (320k AAC)'),
            value: 'saavn',
            groupValue: _selectedSource,
            activeColor: colorScheme.primary,
            onChanged: (value) => setState(() => _selectedSource = value!),
            contentPadding: EdgeInsets.zero,
          ),
          RadioListTile<String>(
            title: const Text('YouTube (160k Opus)'),
            value: 'youtube',
            groupValue: _selectedSource,
            activeColor: colorScheme.primary,
            onChanged: (value) => setState(() => _selectedSource = value!),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
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
              child: const Text('Download'),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showDownloadPicker(
  BuildContext context,
  Map song,
  void Function(String source, String quality) onDownload,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => DownloadPickerSheet(
      song: song,
      onDownload: onDownload,
    ),
  );
}
