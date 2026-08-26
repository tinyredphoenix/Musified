/*
 * Shared Cupertino picker sheet for list choices (folders, playlists, etc.).
 */

import 'package:flutter/cupertino.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/theme/musified_style.dart';
import 'package:musify/utilities/flutter_bottom_sheet.dart';

class PickerSheetAction {
  const PickerSheetAction({
    required this.label,
    required this.onTap,
    this.icon = CupertinoIcons.folder,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData icon;
  final bool isDestructive;
}

Future<void> showMusifiedPickerSheet(
  BuildContext context, {
  required String title,
  required List<PickerSheetAction> actions,
  String? emptyMessage,
}) {
  final scheme = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  if (actions.isEmpty) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(emptyMessage ?? 'Nothing here yet.'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Prefer action sheet when the list is short (true iOS feel).
  if (actions.length <= 8) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(title),
        actions: [
          for (final action in actions)
            CupertinoActionSheetAction(
              isDestructiveAction: action.isDestructive,
              onPressed: () {
                Navigator.pop(ctx);
                action.onTap();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    action.icon,
                    size: 18,
                    color: action.isDestructive
                        ? CupertinoColors.destructiveRed
                        : scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: Text(action.label)),
                ],
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  // Longer lists use the solid Musified sheet.
  showCustomBottomSheet(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: MusifiedStyle.sectionTitle(scheme.onSurface).copyWith(
              fontSize: 18,
            ),
          ),
        ),
        for (final action in actions)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              borderRadius: BorderRadius.circular(MusifiedStyle.radiusMd),
              color: isDark
                  ? MusifiedStyle.surface
                  : MusifiedStyle.lightSurfaceHigh,
              onPressed: () {
                Navigator.pop(context);
                action.onTap();
              },
              child: Row(
                children: [
                  Icon(
                    action.icon,
                    size: 20,
                    color: action.isDestructive
                        ? CupertinoColors.destructiveRed
                        : scheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      action.label,
                      style: TextStyle(
                        color: action.isDestructive
                            ? CupertinoColors.destructiveRed
                            : scheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    CupertinoIcons.chevron_forward,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
  return Future.value();
}
