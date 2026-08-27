/*
 * Always Cupertino — Musified is an iOS / LiveContainer app.
 */

import 'package:flutter/cupertino.dart';
import 'package:musified/extensions/l10n.dart';

class ConfirmationDialog extends StatelessWidget {
  const ConfirmationDialog({
    super.key,
    this.confirmationMessage,
    required this.submitMessage,
    required this.onCancel,
    required this.onSubmit,
    this.isDangerous = false,
  });
  final String? confirmationMessage;
  final String submitMessage;
  final VoidCallback? onCancel;
  final VoidCallback? onSubmit;
  final bool isDangerous;

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Text(context.l10n.confirmation),
      content: confirmationMessage != null
          ? Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(confirmationMessage!),
            )
          : null,
      actions: [
        CupertinoDialogAction(
          onPressed: onCancel,
          child: Text(context.l10n.cancel),
        ),
        CupertinoDialogAction(
          isDestructiveAction: isDangerous,
          isDefaultAction: !isDangerous,
          onPressed: onSubmit,
          child: Text(submitMessage),
        ),
      ],
    );
  }
}
