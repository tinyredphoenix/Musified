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

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/services/settings_manager.dart';

ThemeMode _themeModeCached = getThemeMode(_safeInitialThemeIndex());
Brightness _brightnessCached = getBrightnessFromThemeMode(_themeModeCached);

int _safeInitialThemeIndex() {
  try {
    return themeModeSetting;
  } catch (_) {
    return 0;
  }
}

// Mutable globals kept for backward compat, but now safely initialized
// and kept in sync via syncThemeFromSettings().
ThemeMode get themeMode => _themeModeCached;
set themeMode(ThemeMode v) {
  _themeModeCached = v;
  _brightnessCached = getBrightnessFromThemeMode(v);
}

Brightness get brightness => _brightnessCached;
set brightness(Brightness v) => _brightnessCached = v;

void syncThemeFromSettings() {
  final m = getThemeMode(themeModeSetting);
  _themeModeCached = m;
  _brightnessCached = getBrightnessFromThemeMode(m);
}

Brightness getBrightnessFromThemeMode(ThemeMode themeMode) {
  final themeBrightnessMapping = {
    ThemeMode.light: Brightness.light,
    ThemeMode.dark: Brightness.dark,
    ThemeMode.system:
        SchedulerBinding.instance.platformDispatcher.platformBrightness,
  };

  return themeBrightnessMapping[themeMode] ?? Brightness.dark;
}

ThemeMode getThemeMode(int themeModeIndex) {
  const themeModes = ThemeMode.values;
  if (themeModeIndex >= 0 && themeModeIndex < themeModes.length) {
    return themeModes[themeModeIndex];
  }
  return ThemeMode.system;
}

ColorScheme getAppColorScheme(
  ColorScheme? lightColorScheme,
  ColorScheme? darkColorScheme,
) {
  final selectedScheme = (brightness == Brightness.light)
      ? lightColorScheme
      : darkColorScheme;

  if (useSystemColor.value && selectedScheme != null) {
    return selectedScheme;
  } else {
    return ColorScheme.fromSeed(
      seedColor: primaryColorSetting,
      brightness: brightness,
    );
  }
}

ThemeData getAppTheme(ColorScheme colorScheme) {
  final base = colorScheme.brightness == Brightness.light
      ? ThemeData.light()
      : ThemeData.dark();

  final isLight = colorScheme.brightness == Brightness.light;
  final isPureBlack =
      colorScheme.brightness == Brightness.dark && usePureBlackColor.value;

  // Pure black theme colors
  const pureBlack = Color(0xFF000000);
  const pureBlackElevated = Color(0xFF0A0A0A);
  const pureBlackContainer = Color(0xFF121212);
  const pureBlackContainerHigh = Color(0xFF1A1A1A);

  final bgColor = isLight
      ? colorScheme.surface
      : (isPureBlack ? pureBlack : null);

  final cardBgColor = isLight
      ? colorScheme.surfaceContainerLow
      : (isPureBlack ? pureBlackElevated : null);

  // modified color scheme for pure black theme
  final effectiveColorScheme = isPureBlack
      ? colorScheme.copyWith(
          surface: pureBlack,
          surfaceContainerLowest: pureBlack,
          surfaceContainerLow: pureBlackElevated,
          surfaceContainer: pureBlackContainer,
          surfaceContainerHigh: pureBlackContainerHigh,
          surfaceContainerHighest: pureBlackContainerHigh,
        )
      : colorScheme;

  return ThemeData(
    scaffoldBackgroundColor: bgColor,
    colorScheme: effectiveColorScheme,
    cardColor: cardBgColor,
    cardTheme: base.cardTheme.copyWith(
      elevation: 0,
      color: cardBgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: bgColor,
      foregroundColor: effectiveColorScheme.primary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: effectiveColorScheme.primary,
        letterSpacing: -0.5,
      ),
      toolbarHeight: 56,
      iconTheme: IconThemeData(
        color: effectiveColorScheme.onSurfaceVariant,
        size: 24,
      ),
      actionsIconTheme: IconThemeData(
        color: effectiveColorScheme.onSurfaceVariant,
        size: 24,
      ),
    ),
    listTileTheme: base.listTileTheme.copyWith(
      textColor: effectiveColorScheme.primary,
      iconColor: effectiveColorScheme.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      year2023: false,
      trackHeight: 4,
      thumbSize: WidgetStateProperty.all(const Size(8, 8)),
    ),
    bottomSheetTheme: base.bottomSheetTheme.copyWith(
      backgroundColor: isLight
          ? colorScheme.surfaceContainerLow
          : (isPureBlack ? pureBlackElevated : null),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      filled: true,
      isDense: true,
      fillColor: isLight
          ? colorScheme.surfaceContainerHighest
          : (isPureBlack
                ? pureBlackContainerHigh
                : colorScheme.surfaceContainerHigh),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    ),
    dialogTheme: base.dialogTheme.copyWith(
      backgroundColor: isLight
          ? colorScheme.surfaceContainerLow
          : (isPureBlack ? pureBlackContainer : null),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    navigationBarTheme: base.navigationBarTheme.copyWith(
      backgroundColor: bgColor?.withValues(alpha: 0.85),
      elevation: 0,
      height: 49,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      indicatorColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(
            color: effectiveColorScheme.primary,
            size: 24,
          );
        }
        return IconThemeData(
          color: effectiveColorScheme.onSurfaceVariant,
          size: 24,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(
            color: effectiveColorScheme.primary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          );
        }
        return TextStyle(
          color: effectiveColorScheme.onSurfaceVariant,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        );
      }),
    ),
    navigationRailTheme: base.navigationRailTheme.copyWith(
      backgroundColor: bgColor,
      elevation: 0,
      indicatorColor: Colors.transparent,
      selectedIconTheme: IconThemeData(
        color: effectiveColorScheme.primary,
        size: 24,
      ),
      unselectedIconTheme: IconThemeData(
        color: effectiveColorScheme.onSurfaceVariant,
        size: 24,
      ),
      selectedLabelTextStyle: TextStyle(
        color: effectiveColorScheme.primary,
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: effectiveColorScheme.onSurfaceVariant,
        fontSize: 10,
        fontWeight: FontWeight.w500,
      ),
    ),
    popupMenuTheme: base.popupMenuTheme.copyWith(
      color: isLight
          ? colorScheme.surfaceContainerLow
          : (isPureBlack ? pureBlackContainer : null),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    dividerTheme: base.dividerTheme.copyWith(
      color: effectiveColorScheme.outlineVariant.withValues(alpha: 0.5),
      thickness: 0.5,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: effectiveColorScheme.secondaryContainer,
      contentTextStyle: TextStyle(
        color: effectiveColorScheme.onSecondaryContainer,
        fontWeight: FontWeight.w500,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 2,
      actionTextColor: effectiveColorScheme.secondary,
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
    useMaterial3: true,
  );
}
