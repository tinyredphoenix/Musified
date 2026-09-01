# 01 — `lib/main.dart` — Entry

## Purpose
Flutter entry, 5-phase `initialisation()` (Hive 5 boxes → dirs → SourceResolver/AudioService → router → AppLinks), `MusifiedApp` (`CupertinoApp.router`) with `WidgetsBindingObserver`, theme/locale/accent globals, `ErrorWidget.builder` OLED fallback, `FlutterError.onError` → `logger`.

## Call graph

* **Who calls:** Flutter engine (`main()`).
* **Whom it calls:** `Hive.initFlutter` + `openBox(settings/user/userNoBackup/cache/youtube_auth)` `lib/main.dart:286`, `reloadSettingsFromStorage` `settings_manager.dart:22`, `YtdlpClientSyncService.ensureLoaded`, `reloadSongLibraryStateFromStorage`, `OfflinePlaylistService.reloadOfflinePlaylistsFromStorage`, `YouTubeAuthService.restoreSession`, `YouTubeMusicSyncService.initialize`, `getApplicationDocumentsDirectory` + `FilePaths.ensureDirectoriesExist`, `SourceResolver.init`, `AudioService.init(MusifiedAudioHandler)` `.timeout 9s`, `NavigationManager.instance`, `AppLinks.getInitialLink` + `uriLinkStream`, `PlaylistSharingService.decodeAndExpandPlaylist`.
* **Downstream callers:** Every screen/widget via `audioHandler` global `lib/main.dart:37`, `isAudioHandlerInitialized`, `NavigationManager().context` (now safe via `routerDelegate.navigatorKey.currentContext:429`).

## Public surface
`MusifiedAudioHandler? _audioHandlerInstance` + `ValueNotifier<bool> audioHandlerReady:36`, `get audioHandler` throw if null, `MusifiedApp.updateAppState` via `findAncestorStateOfType`, `handleIncomingLink(Uri?)` async with size guard `399` `65536`.

## Comments removed (verbatim, would be stripped)

```
// Re-exported from logger_service for files that import main.dart. — 45
// NOTE: this used to be capped at 4 seconds. ... 12s safety net rationale — 263-273
// Phase 1: Hive + settings (never let this kill the app) — 284
// Restore persisted settings into ValueNotifiers + theme globals — 295
// Restore YouTube Music session if previously signed in — 302
// Phase 2: directories (must succeed for offline) — 309
// Fallback to temp dir so app still launches — 315
// Phase 3: audio + saavn (isolated so router always initializes) — 323
// Bounded so a slow/stuck native AudioService setup can never stall ... — 331-334
// Phase 4: router - MUST always run — 366
// Phase 5: deep links — 373
// Ensure the incoming playlist has a unique id so it can be removed later — 413
// Check for duplicate by title and song ytids — 418
```

Plus re-export `export 'package:musified/services/logger_service.dart' show logger, Logger;` line 18.

## Verification vs auditfinal

* **FIXED** `searchHistoryNotifier` crash: now `ValueNotifier([])` at import + Hive read in `initState:43` (not top-level).
* **FIXED** AppLinks cold start: `getInitialLink:375` + `uriLinkStream.listen` stored, size guard `399`, safe `navContext` `429/461` with null-check.
* **FIXED** `AudioService.init` orphan: `await AudioService.stop()` `348` before fallback handler.
* **NOT FIXED** `refreshRouter` still not wired to `offlineMode` (see `06_screens.md`).
* **Remaining risk:** `/tmp` fallback `318-320` still Documents→tmp on double failure.

## Notes

* `build:169` `overlayBrightness` derived from cached `themeMode` vs `isAppDarkMode(context)` mismatch possible.
* `ErrorWidget.builder:207` shows first 12 stack lines — expensive string split on every render error.
