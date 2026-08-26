/*
 * Overflow control — Cupertino action sheet (no Material popup menu).
 */

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

class OverflowMenuButton<T> extends StatelessWidget {
  const OverflowMenuButton({
    super.key,
    required this.onSelected,
    required this.itemBuilder,
    this.icon,
    this.borderRadius,
    this.iconSize = 22,
    this.color,
  });

  final void Function(T value) onSelected;
  final List<PopupMenuEntry<T>> Function(BuildContext context) itemBuilder;

  final IconData? icon;
  final double iconSize;
  final Color? color;
  final BorderRadius? borderRadius;

  void _open(BuildContext context) {
    HapticFeedback.selectionClick();
    final entries = itemBuilder(context);
    final actions = <Widget>[];

    for (final entry in entries) {
      if (entry is PopupMenuDivider) continue;
      if (entry is PopupMenuItem<T>) {
        final value = entry.value;
        if (value == null) continue;
        final enabled = entry.enabled;
        actions.add(
          CupertinoActionSheetAction(
            onPressed: enabled
                ? () {
                    Navigator.pop(context);
                    onSelected(value);
                  }
                : () {},
            child: DefaultTextStyle.merge(
              style: TextStyle(
                color: enabled
                    ? null
                    : Theme.of(context).disabledColor,
              ),
              child: entry.child ?? Text(value.toString()),
            ),
          ),
        );
      }
    }

    if (actions.isEmpty) return;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: actions,
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return CupertinoButton(
      padding: const EdgeInsets.all(6),
      minimumSize: Size.zero,
      onPressed: () => _open(context),
      child: Icon(
        icon ?? CupertinoIcons.ellipsis,
        size: iconSize,
        color: color ?? colorScheme.onSurfaceVariant,
      ),
    );
  }
}
