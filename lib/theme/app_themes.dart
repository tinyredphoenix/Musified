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
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/theme/musified_style.dart';

ThemeMode _themeModeCached = getThemeMode(_safeInitialThemeIndex());
Brightness _brightnessCached = getBrightnessFromThemeMode(_themeModeCached);

int _safeInitialThemeIndex() {
  try {
    return themeModeSetting;
  } catch (_) {
    return 0;
  }
}

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

ColorScheme getAppColorScheme({
  required Brightness forBrightness,
  ColorScheme? lightColorScheme,
  ColorScheme? darkColorScheme,
}) {
  final selectedScheme = forBrightness == Brightness.light
      ? lightColorScheme
      : darkColorScheme;

  if (useSystemColor.value && selectedScheme != null) {
    return selectedScheme;
  }

  return ColorScheme.fromSeed(
    seedColor: primaryColorSetting,
    brightness: forBrightness,
  );
}

/// Builds a full ThemeData for exactly one brightness.
/// MaterialApp must receive distinct light + dark themes so ThemeMode.system works.
ThemeData getAppTheme(ColorScheme colorScheme) {
  final base = colorScheme.brightness == Brightness.light
      ? ThemeData.light()
      : ThemeData.dark();

  final isLight = colorScheme.brightness == Brightness.light;
  final useOled =
      !isLight && usePureBlackColor.value;

  final bgColor = isLight
      ? MusifiedStyle.lightCanvas
      : (useOled ? MusifiedStyle.oledBlack : MusifiedStyle.elevated);
  final cardBgColor =
      isLight ? MusifiedStyle.lightElevated : MusifiedStyle.surface;

  final effectiveColorScheme = isLight
      ? colorScheme.copyWith(
          surface: MusifiedStyle.lightCanvas,
          surfaceContainerLowest: MusifiedStyle.lightCanvas,
          surfaceContainerLow: MusifiedStyle.lightElevated,
          surfaceContainer: MusifiedStyle.lightSurface,
          surfaceContainerHigh: MusifiedStyle.lightSurfaceHigh,
          surfaceContainerHighest: MusifiedStyle.lightSurfaceHigh,
          onSurface: MusifiedStyle.lightOnSurface,
          onSurfaceVariant: MusifiedStyle.lightSecondaryLabel,
          outlineVariant: MusifiedStyle.lightHairline,
        )
      : colorScheme.copyWith(
          surface: useOled ? MusifiedStyle.oledBlack : MusifiedStyle.elevated,
          surfaceContainerLowest:
              useOled ? MusifiedStyle.oledBlack : MusifiedStyle.elevated,
          surfaceContainerLow: MusifiedStyle.elevated,
          surfaceContainer: MusifiedStyle.surface,
          surfaceContainerHigh: MusifiedStyle.surfaceHigh,
          surfaceContainerHighest: MusifiedStyle.surfaceHigh,
          onSurface: const Color(0xFFF5F5F7),
          onSurfaceVariant: MusifiedStyle.secondaryLabel,
          outlineVariant: MusifiedStyle.hairline,
        );

  final onSurface = effectiveColorScheme.onSurface;
  final onVariant = effectiveColorScheme.onSurfaceVariant;

  final textTheme = base.textTheme.copyWith(
    displayLarge: MusifiedStyle.largeTitle(onSurface),
    displayMedium: MusifiedStyle.brandTitle(onSurface),
    headlineLarge: MusifiedStyle.sectionTitle(onSurface),
    headlineMedium: MusifiedStyle.playerTitle(onSurface),
    titleLarge: MusifiedStyle.songTitle(onSurface),
    titleMedium: MusifiedStyle.songTitle(onSurface).copyWith(fontSize: 15),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: onSurface,
      letterSpacing: -0.2,
    ),
    bodyMedium: MusifiedStyle.songSubtitle(onVariant),
    bodySmall: MusifiedStyle.caption(onVariant),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: onSurface,
      letterSpacing: -0.1,
    ),
    labelMedium: MusifiedStyle.caption(onVariant),
  );

  return ThemeData(
    scaffoldBackgroundColor: bgColor,
    colorScheme: effectiveColorScheme,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    cardColor: cardBgColor,
    cardTheme: base.cardTheme.copyWith(
      elevation: 0,
      color: cardBgColor,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MusifiedStyle.radiusMd),
      ),
    ),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: bgColor,
      foregroundColor: onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: onSurface,
        letterSpacing: -0.3,
      ),
      toolbarHeight: 48,
      iconTheme: IconThemeData(color: onVariant, size: 22),
      actionsIconTheme: IconThemeData(color: onVariant, size: 22),
    ),
    listTileTheme: base.listTileTheme.copyWith(
      textColor: onSurface,
      iconColor: onVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MusifiedStyle.radiusSm),
      ),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      year2023: false,
      trackHeight: 3,
      thumbSize: WidgetStateProperty.all(const Size(10, 10)),
      overlayShape: SliderComponentShape.noOverlay,
      activeTrackColor: onSurface,
      inactiveTrackColor: onSurface.withValues(alpha: 0.18),
      thumbColor: onSurface,
    ),
    bottomSheetTheme: base.bottomSheetTheme.copyWith(
      backgroundColor: isLight
          ? MusifiedStyle.lightElevated
          : MusifiedStyle.elevated,
      dragHandleColor: onSurface.withValues(alpha: 0.28),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(MusifiedStyle.radiusXl),
        ),
      ),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      filled: true,
      isDense: true,
      fillColor: isLight
          ? MusifiedStyle.lightSurfaceHigh
          : MusifiedStyle.surfaceHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MusifiedStyle.radiusPill),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      hintStyle: MusifiedStyle.songSubtitle(onVariant),
    ),
    dialogTheme: base.dialogTheme.copyWith(
      backgroundColor:
          isLight ? MusifiedStyle.lightElevated : MusifiedStyle.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MusifiedStyle.radiusXl),
      ),
    ),
    navigationBarTheme: base.navigationBarTheme.copyWith(
      backgroundColor: bgColor,
      elevation: 0,
      height: 56,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      indicatorColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: effectiveColorScheme.primary, size: 24);
        }
        return IconThemeData(color: onVariant.withValues(alpha: 0.55), size: 24);
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
          color: onVariant.withValues(alpha: 0.55),
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
        color: onVariant.withValues(alpha: 0.55),
        size: 24,
      ),
      selectedLabelTextStyle: TextStyle(
        color: effectiveColorScheme.primary,
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: onVariant.withValues(alpha: 0.55),
        fontSize: 10,
        fontWeight: FontWeight.w500,
      ),
    ),
    popupMenuTheme: base.popupMenuTheme.copyWith(
      color: isLight ? MusifiedStyle.lightElevated : MusifiedStyle.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MusifiedStyle.radiusMd),
      ),
    ),
    dividerTheme: base.dividerTheme.copyWith(
      color: effectiveColorScheme.outlineVariant,
      thickness: 0.5,
      space: 0.5,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isLight
          ? MusifiedStyle.lightOnSurface
          : MusifiedStyle.surfaceHigh,
      contentTextStyle: TextStyle(
        color: isLight ? Colors.white : onSurface,
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MusifiedStyle.radiusMd),
      ),
      elevation: 0,
      actionTextColor: effectiveColorScheme.primary,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: effectiveColorScheme.primary,
      linearTrackColor: onSurface.withValues(alpha: 0.12),
      circularTrackColor: onSurface.withValues(alpha: 0.12),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      },
    ),
    visualDensity: VisualDensity.standard,
    useMaterial3: true,
    // Sideloaded iOS / LiveContainer — always present native iOS chrome.
    platform: TargetPlatform.iOS,
  );
}

/// Convenience: light + dark ThemeData pair for MaterialApp.
({ThemeData light, ThemeData dark}) buildAppThemes({
  ColorScheme? lightSystemScheme,
  ColorScheme? darkSystemScheme,
}) {
  final lightScheme = getAppColorScheme(
    forBrightness: Brightness.light,
    lightColorScheme: lightSystemScheme,
    darkColorScheme: darkSystemScheme,
  );
  final darkScheme = getAppColorScheme(
    forBrightness: Brightness.dark,
    lightColorScheme: lightSystemScheme,
    darkColorScheme: darkSystemScheme,
  );
  return (light: getAppTheme(lightScheme), dark: getAppTheme(darkScheme));
}
