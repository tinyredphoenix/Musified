# 03 — Core Services (`common_services`, `source_resolver`, `jiosaavn`, `data_manager`, `io_service`)

## Purpose

* **`common_services.dart:1` (1535L)** — App-wide library: Hive `user` boxes, `fetchBestAudioStream:869`, `fetchSongStreamUrl:931`, `_isCachedStreamUrlAlive:259` HEAD+Range, `makeSongOffline:1157`, `getPlaylistInfoForWidget`, `like/offline` sync.
* **`source_resolver.dart:1` (181L)** — JioSaavn resolver via `JioSaavnService.searchTracks` + `TrackMatcher.isExactMatch`, Hive `saavn_match_cache` 1500 FIFO.
* **`jiosaavn_service.dart:1` (147L)** — `search.getResults` 5s + `DES ECB 38346591` `dart_des` decrypt, `formatTrack`.
* **`data_manager.dart:1` (274L)** — Cache durations `song 1h30` `playlist 5h` `search 1d` `default 2d`, `_memoryCache` 200/trim 50, `configureImageMemoryBudget:62` 48MB/120, `addOrUpdateData`/`getData`/`deleteData`/`cleanupOldCacheEntries`.
* **`io_service.dart:1` (40L)** — `applicationDirPath` global, `FilePaths` `tracks/`/`artworks/` + `getAudioPath`/`getArtworkPath` via `sanitizeStorageSongId`, `ensureDirectoriesExist`.

## Call graph

* `common_services` ← `MusifiedAudioHandler`, `AudioPreloadService`, `SourceResolver`, UI lists. → `Hive`, `http`, `YoutubeExplode` via `ProxyManager` `ytClient`, `JioSaavnService`, `SourceResolver`.
* `source_resolver` ← `common_services.fetchSongStreamUrl:1034`, `makeSongOffline:1206` → `JioSaavnService`, `TrackMatcher`, Hive.
* `jiosaavn` ← `SourceResolver` → `http.get`, `dart_des`.
* `data_manager` ← everywhere `addOrUpdateData`/`getData` → `Hive`, `ArtworkProvider`, `DefaultCacheManager`.
* `io_service` ← `common_services`, `playlist_download_service`, `mediaitem` → `dart:io`.

## Comments removed (verbatim)

```
// Cache durations for different types of data — data_manager.dart:9
// In-memory cache for frequently accessed items — 15
// Cap kept intentionally modest for LiveContainer / personal devices. — 34
// Bounds Flutter's in-memory decoded-image cache (not Hive / not downloads). — 61
// Check memory cache first — data_manager.dart:92
// Store in memory cache for faster access next time — 113
// Clean up old cache entries to prevent excessive storage usage — 173
// Get all keys except the ones with _date suffix — 180
// Very old cache entries (older than 2 days) should be removed — 197
// Check if the cache is still valid based on the caching duration — 233
// File extensions — io_service.dart:8
// Directory names — 12
// Get full paths for various file types — 16
// Ensure directories exist — 28
// Source preference is applied by fetchSongStreamUrl. Keeping this resolver source-agnostic ... — source_resolver.dart:38
// Check cache — 44
// Try query with artist first, then title-only fallback — 72
```

Plus ~60 `//` in `common_services` (HEAD fallback, `// 1. Search ...`, `// Keep the most ...` etc.)

## Verification vs auditfinal

* **FIXED** traversal: `FilePaths.getAudioPath:18` now `sanitizeStorageSongId(songId)` `app_utils.dart:173` (`^[a-zA-Z0-9_-]{11}$` else `_` stripped, cap 64).
* **FIXED** `isUsableYoutubePlaybackUrl:199` now central + used in `common_services` via `audio` modules (see `02_audio.md`).
* **PARTIALLY FIXED** `addOrUpdateData:72` now `putAll({key,value, ${key}_date: now})` atomic for `cache` category only; non-cache still single `put`; `_durationFromNumber:145` now `n>86400 → ms` (25h podcast mis-class still possible).
* **NOT FIXED** triple TTL desync 45m vs 1h vs 1h still (cache vs validation vs mem), `http.head` fallback `Range bytes=0-1` still treats redirect 200 as alive `common_services.dart:259`, `Retry 5×500ms no jitter`.
* **NOT FIXED** `jiosaavn_service` still static `body.indexOf('{')` fragile parse.

## Open risks

* `makeSongOffline:1157` still creates dirs before source check, `http.Client` per Saavn download not tied to cancel.
* `SourceResolver` `cacheMatch:165` still `unawaited` silent box close race.
