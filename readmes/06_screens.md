# 06 — Screens + Router (`lib/screens/*` + `lib/services/router_service.dart`)

## Purpose

* **`router_service.dart:27` (377L)** — `NavigationManager` singleton `GoRouter` `StatefulShellRoute.indexedStack` 4 tabs (`home/search/library/settings`), `redirect` offline guards `48-73`, `artistPath/albumPath/basePathFor:297`, `getPage` fade 180ms / `_pushPage` slide `0.06` 220ms.
* **Screens 12:** `bottom_navigation_page 222L` floating MiniPlayer+TabBar, `home_page 487L`, `search_page 391L` debounce, `library_page 289L`, `playlist_page 665L`, `playlist_folder_page 315L`, `artist_page 482L`, `now_playing_page 276L`, `user_songs_page 358L`, `settings_page 892L`, `logs_page 74L`, `youtube_auth_webview 106L`.

## Call graph

* `NavigationManager` ← `main.dart NavigationManager.instance` + `router` getter, `appLinks` deeplink `handleIncomingLink` → `GoRouter` `parentNavigatorKey` + 4 tab `GlobalKey`.
* Each screen → `NavigationManager.artistPath/albumPath`, `audioHandler` via `main.dart`, `common_services`, `playlists_manager`, `Palette` `theme`.
* `SearchPage` → `fetchSongsList/searchArtists/getPlaylists` + `getSearchSuggestions` debounce 300ms timer `135`.
* `ArtistPage` → `getArtistCatalog`/`resolveArtist` via `youtube_music_explode` + `playlists_manager`.

## Comments removed (sample)

```
/// The page an artist opens on ... — artist_page.dart:31
/// Read the first time the page is shown online ... — 44
// Floating MiniPlayer + TabBar — bottom_navigation_page.dart:95
// --------------------------------------------------------------------------- // THEME SELECTOR CARD — settings_page.dart:88
// Refresh artist data, preserving current state on failure. — artist_page.dart:67
// Block syntax: setState doesn't accept Future-returning callbacks — 73
// Restore original order from backup — playlist_page.dart:607
// Sorting / Search — playlist_page.dart:63
// Handle offline mode redirects / Releases are only browsable through YouTube Music. — router_service.dart:49/58
/// The artist landing page ... 251 / A release opened from an artist page ... 282
```

Full ~400 comment lines across screens.

## Verification vs auditfinal

* **FIXED** `SearchPage` cold crash moved from top-level `Hive.box` to `initState:43` (`if value.isEmpty get`).
* **FIXED** `NavigationManager` now used via `routerDelegate.navigatorKey.currentContext` safe check `main.dart:429/461` instead of throw; still `router_service.dart:98` `context` getter throws if accessed early — kept for compat but callers now safe.
* **NOT FIXED** `refreshRouter:119` not wired to `offlineMode` — `BottomNavigationPage 65 Stack` manual `addPostFrameCallback` still anti-pattern.
* **NOT FIXED** `library` route duplicate `home/library` `router_service.dart:149` vs `libraryPath`.
* **NOT FIXED** `youtube_auth_webview` `NavigationDecision.navigate` always + cookie domain `Uri.parse('https://youtube.com')` miss `.youtube.com`.
* **PARTIALLY FIXED** search `Future.wait` now `fetchSongsList/searchArtists/getPlaylists(query)` `95` but still no debounce on main search (only suggestions 300ms).

## Per-screen notes

* `bottom_navigation_page:24` `Stream.value(false)` mini-player still single-fire (P1).
* `logs_page:56` `SingleChildScrollView` 200k single `Text` layout still jank.
* `playlist_folder_page:261` `TextEditingController` leak in rename dialog still present.
