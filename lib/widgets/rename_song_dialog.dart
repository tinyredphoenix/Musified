/*
 * Cupertino rename dialog — Musified light/dark aware.
 */

import 'package:flutter/cupertino.dart';
import 'package:musified/extensions/l10n.dart';
import 'package:musified/theme/app_themes.dart';
import 'package:musified/utilities/flutter_toast.dart';

class RenameSongDialog extends StatefulWidget {
  const RenameSongDialog({
    super.key,
    required this.currentTitle,
    required this.currentArtist,
    required this.onRename,
  });

  final String currentTitle;
  final String currentArtist;
  final Function(String newTitle, String newArtist) onRename;

  @override
  State<RenameSongDialog> createState() => _RenameSongDialogState();
}

class _RenameSongDialogState extends State<RenameSongDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _artistController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.currentTitle);
    _artistController = TextEditingController(text: widget.currentArtist);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    super.dispose();
  }

  void _handleRename() {
    final newTitle = _titleController.text.trim();
    final newArtist = _artistController.text.trim();

    if (newTitle.isEmpty || newArtist.isEmpty) {
      showToast(context, context.l10n.fieldsNotEmpty);
      return;
    }

    widget.onRename(newTitle, newArtist);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isAppDarkMode(context);

    return CupertinoAlertDialog(
      title: Text(context.l10n.renameSong),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          children: [
            CupertinoTextField(
              controller: _titleController,
              placeholder: context.l10n.name,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? CupertinoColors.tertiarySystemFill
                    : CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 10),
            CupertinoTextField(
              controller: _artistController,
              placeholder: context.l10n.artist,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? CupertinoColors.tertiarySystemFill
                    : CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: _handleRename,
          child: Text(context.l10n.confirm),
        ),
      ],
    );
  }
}
