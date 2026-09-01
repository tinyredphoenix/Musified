import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:musified/services/settings_manager.dart';
import 'package:musified/theme/musified_style.dart';

enum ThemeMode { system, light, dark }

ThemeMode _themeModeCached = getThemeMode(_safeInitialThemeIndex());
Brightness _brightnessCached = getBrightnessFromThemeMode(_themeModeCached);

int _safeInitialThemeIndex() {
  try {
    return themeModeSetting.value;
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
  final m = getThemeMode(themeModeSetting.value);
  _themeModeCached = m;
  _brightnessCached = getBrightnessFromThemeMode(m);
}

Brightness getBrightnessFromThemeMode(ThemeMode mode) {
  final themeBrightnessMapping = {
    ThemeMode.light: Brightness.light,
    ThemeMode.dark: Brightness.dark,
    ThemeMode.system:
        SchedulerBinding.instance.platformDispatcher.platformBrightness,
  };

  return themeBrightnessMapping[mode] ?? Brightness.dark;
}

ThemeMode getThemeMode(int themeModeIndex) {
  const themeModes = ThemeMode.values;
  if (themeModeIndex >= 0 && themeModeIndex < themeModes.length) {
    return themeModes[themeModeIndex];
  }
  return ThemeMode.system;
}

bool isAppDarkMode(BuildContext context) {
  return CupertinoTheme.brightnessOf(context) == Brightness.dark;
}

/// Scaffold / page canvas. OLED on = `#000000`, OLED off = elevated `#121214`.
Color musifiedCanvas(bool isDark) => isDark
    ? (usePureBlackColor.value ? MusifiedStyle.oledBlack : MusifiedStyle.elevated)
    : MusifiedStyle.lightCanvas;

/// Card / grouped-row fill that still contrasts with [musifiedCanvas].
Color musifiedCard(bool isDark) => isDark
    ? (usePureBlackColor.value ? const Color(0xFF0A0A0A) : MusifiedStyle.surface)
    : MusifiedStyle.lightSurface;

/// Placeholder / chip / secondary control surface (OLED-aware).
Color musifiedSecondarySurface(bool isDark) => isDark
    ? (usePureBlackColor.value ? const Color(0xFF0A0A0A) : MusifiedStyle.surfaceHigh)
    : const Color(0xFFE5E5EA);

/// Mini-player frosted panel background.
Color musifiedMiniPlayerBg(bool isDark) => isDark
    ? (usePureBlackColor.value
        ? const Color(0xE6000000)
        : const Color(0xE61C1C1E))
    : const Color(0xE6FFFFFF);

/// Grouped list / sheet surface (#1C1C1E elevated, OLED near-black).
Color musifiedElevatedSurface(bool isDark) => isDark
    ? (usePureBlackColor.value ? const Color(0xFF0A0A0A) : MusifiedStyle.surface)
    : const Color(0xFFF2F2F7);

/// Sheet / dialog card on elevated surfaces.
Color musifiedSheetCard(bool isDark) => isDark
    ? (usePureBlackColor.value ? const Color(0xFF0A0A0A) : MusifiedStyle.surface)
    : CupertinoColors.white;

CupertinoThemeData buildCupertinoTheme({
  required Brightness brightness,
  Color primaryColor = const Color(0xFFFF2D55),
}) {
  final isDark = brightness == Brightness.dark;
  final useOled = isDark && usePureBlackColor.value;

  return CupertinoThemeData(
    brightness: brightness,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: isDark
        ? (useOled ? MusifiedStyle.oledBlack : MusifiedStyle.elevated)
        : MusifiedStyle.lightCanvas,
    barBackgroundColor: isDark
        ? const Color(0xB3121214)
        : const Color(0xB3FFFFFF),
    textTheme: CupertinoTextThemeData(
      textStyle: TextStyle(
        fontFamily: MusifiedStyle.uiFont,
        fontSize: 17,
        color: isDark ? CupertinoColors.white : CupertinoColors.black,
        decoration: TextDecoration.none,
      ),
      navTitleTextStyle: TextStyle(
        fontFamily: MusifiedStyle.displayFont,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: isDark ? CupertinoColors.white : CupertinoColors.black,
        decoration: TextDecoration.none,
      ),
      navLargeTitleTextStyle: TextStyle(
        fontFamily: MusifiedStyle.displayFont,
        fontSize: 34,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: isDark ? CupertinoColors.white : CupertinoColors.black,
        decoration: TextDecoration.none,
      ),
    ),
  );
}
