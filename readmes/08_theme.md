# 08 — Theme (`lib/theme/*`)

## Purpose

* **`app_themes.dart:1` (129L)** — `ThemeMode` enum, cached globals `_themeModeCached/_brightnessCached`, helpers `musifiedCanvas/Card/SecondarySurface/MiniPlayerBg/ElevatedSurface/SheetCard` OLED-aware (`#000000` vs `#121214`/`#1C1C1E`), `buildCupertinoTheme(brightness)` with `barBackgroundColor 0xB3`.
* **`musified_style.dart:1` (135L)** — Design tokens spacing `spaceXs..Xxl`, radius `radiusSm..Pill`, colors `oledBlack/elevated/surface*`, fonts `.SF Pro Text/Display`, `TextStyle` factories `brandTitle/largeTitle/sectionTitle/songTitle`, `hairlineBorder`.
* **`app_colors.dart:1` (14L)** — `availableColors` list 10 Apple system colours (dead code).

## Call graph

* `app_themes` ← `main.dart buildCupertinoTheme` + every screen/widget `isAppDarkMode(context)`, `musifiedCanvas(isDark)` → `SchedulerBinding`, `MusifiedStyle`.
* `musified_style` ← everywhere spacing/typography.

## Comments removed

```
/// Scaffold / page canvas. OLED on = `#000000`, OLED off = elevated `#121214`. — app_themes.dart:57
/// Card / grouped-row fill that still contrasts with [musifiedCanvas]. — 62
/// Placeholder / chip / secondary control surface (OLED-aware). — 67
/// Mini-player frosted panel background. — 72
/// Grouped list / sheet surface (#1C1C1E elevated, OLED near-black). — 79
/// Sheet / dialog card on elevated surfaces. — 84
/// Shared spacing / radius / type tokens used across screens. — musified_style.dart:3
// Light (Apple Music–like cool white) — 26
/// Brand / large-title wordmark. — 39
/// Solid elevated fill for mini player / sheets — no BackdropFilter. — 121
```

## Verification vs auditfinal

* **NOT FIXED** globals at import `themeModeSetting.value` `app_themes.dart:8` flash wrong brightness until `syncThemeFromSettings()` first frame OLED flash.
* **NOT FIXED** `buildCupertinoTheme` `primaryColor` default `0xFFFF2D55` ignores `primaryColorSetting` `settings_manager.dart:79` `0xff91cef4` mismatch.
* **NOT FIXED** `.SF Pro` private font names `musified_style.dart:36` fallback on CI snapshots; hairline `0.5` not retina-aware.
* **NOT FIXED** `Duplicate` `MusifiedStyle.surface` vs `musifiedCard` drift risk `0xFF1C1C1E`.
* **NOT FIXED** `BackdropFilter blur 25+20` double translucent overdraw `BottomNavigationPage 97` + `MiniPlayer 20`.

## Notes

* `usePureBlackColor` read synchronously without listening in `buildCupertinoTheme:94` — stale if mutated outside `MusifiedApp`.
