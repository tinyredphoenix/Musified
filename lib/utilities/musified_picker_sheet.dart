import 'package:flutter/cupertino.dart';
import 'package:musified/theme/app_themes.dart';
import 'package:musified/theme/musified_style.dart';
import 'package:musified/utilities/flutter_bottom_sheet.dart';

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
  final isDark = isAppDarkMode(context);

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
                        : const Color(0xFFFF2D55),
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
            style: TextStyle(
              fontFamily: MusifiedStyle.displayFont,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? CupertinoColors.white : CupertinoColors.black,
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
                  ? const Color(0xFF2C2C2E)
                  : const Color(0xFFE5E5EA),
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
                        : const Color(0xFFFF2D55),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      action.label,
                      style: TextStyle(
                        fontFamily: MusifiedStyle.uiFont,
                        color: action.isDestructive
                            ? CupertinoColors.destructiveRed
                            : (isDark ? CupertinoColors.white : CupertinoColors.black),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Icon(
                    CupertinoIcons.chevron_forward,
                    size: 16,
                    color: CupertinoColors.systemGrey,
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
