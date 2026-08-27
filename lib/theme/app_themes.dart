import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:musified/services/settings_manager.dart';
import 'package:musified/theme/musified_style.dart';

enum ThemeMode { system, light, dark }

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
