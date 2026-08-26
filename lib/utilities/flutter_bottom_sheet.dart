/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Musify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Musify, including how to contribute,
 *     please visit: https://github.com/gokadzev/Musify
 */

import 'package:flutter/cupertino.dart';
import 'package:material_ui/material_ui.dart';

PersistentBottomSheetController? _currentBottomSheetController;
bool _isIOSSheetOpen = false;

/// Shows a bottom sheet using the iOS presentation style.
dynamic showCustomBottomSheet(BuildContext context, Widget content) {
  final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
  final size = MediaQuery.sizeOf(context);
  final colorScheme = Theme.of(context).colorScheme;

  if (isIOS) {
    _isIOSSheetOpen = true;
    // Use a modal popup so it slides from bottom like iOS sheet
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: size.width,
                    maxHeight: size.height * 0.72,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: content,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() => _isIOSSheetOpen = false);
    return null;
  }

  final controller = showBottomSheet(
    enableDrag: true,
    context: context,
    builder: (context) => Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: size.width * 0.92,
              maxHeight: size.height * 0.65,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: content,
            ),
          ),
        ],
      ),
    ),
  );

  _currentBottomSheetController = controller;
  controller.closed.whenComplete(() {
    if (_currentBottomSheetController == controller) {
      _currentBottomSheetController = null;
    }
  });

  return controller;
}

void closeCurrentBottomSheet() {
  if (_isIOSSheetOpen) {
    // iOS sheet is a modal popup; try to pop if possible
    _isIOSSheetOpen = false;
    return;
  }
  try {
    _currentBottomSheetController?.close();
  } catch (_) {}
  _currentBottomSheetController = null;
}
