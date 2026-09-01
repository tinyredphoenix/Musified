# 09 — Utilities, Models, Constants

## Utilities (`lib/utilities/*` 15)

| File | Purpose | Callers |
|---|---|---|
| `app_utils.dart:13` | `getItemBorderRadius`, `listItemKey` hash, `asMapList`, playlist URL regex, `formatMonthPeriodLabel`, `kHeAacItags {139,599,600}`, `isHeAacStream`, `parseSongDuration` (`:`, seconds vs ms `>86400`→ms), `isPlayableYoutubeStreamUrl`, `youtubeStreamDurationSeconds` `dur`, `_youtubeVideoIdPattern {11}`, `sanitizeStorageSongId`, `isUsableYoutubePlaybackUrl` `expire+45s`, `selectAudioOnlyStreamForQuality` AAC-LC filter → fallback HE-AAC → any | `io_service`, `audio/*`, `common_services`, `data_manager` |
| `formatter.dart:22` | `formatSongTitle` bracket strip, `returnSongLayout` ` - ` split, `isLive` | `playlists_manager` |
| `mediaitem.dart:113` | `mapToMediaItem` `upgradeArtworkUrl` `w800/maxres`, offline lookup `hasPlayableOfflineFile` | `audio/*`, `playlists` |
| `artwork_provider.dart:11` | LRU `_cache 80` `FileImage` vs `CachedNetworkImageProvider` + `clearCache` | Every image widget |
| `async_loader.dart:32` | `FutureBuilder` wrapper `AsyncLoader` | `artist_page`, `library` |
| `track_matcher.dart:42` | `cleanText`, `titlesMatch` Jaccard 0.75 `inter>=2` | `source_resolver` |
| `playlist_utils.dart:30` | `generateCustomPlaylistId` `microseconds+Random`, `playlistExists` | `main.dart` deeplink + `playlists_manager` |
| `flutter_toast.dart:196` | `showToast/showAppToast` via `NavigationManager.context` | Everywhere |
| `language_utils.dart:4` | `appSupportedLocales`, `getLanguageName`, `getLocaleFromCode` script fallback | `main.dart` |
| `map_utils.dart` | `cloneMap/cloneMaps` | `audio` history |
| Others | `app_utils`, `flutter_bottom_sheet`, `sort_utils`, `url_launcher`, `offline_playlist_dialogs`, etc. | — |

## Models (`lib/models/*` 3)

* `position_data.dart:7` `{position,buffered,duration}` DTO
* `full_player_state.dart` `{playbackState,queue,position,mediaItem}` via `Rx.combineLatest4`
* `proxy_model.dart:1` `ProxyInfo {source,country,address,isSsl}` `==` only `address+country`

## Constants (`lib/constants/*` 3)

* `app_constants.dart` durations, Hive box names
* `clients.dart:4` `/// Musified resolves YouTube streams with visionos only — no fallback chain.` + `youtubeStreamClients()` → `VisionOS`
* `artist_constants.dart:1` cache versioning, timeouts, regexes for name normalization
* `version.dart` `1.8.0+30`

## Comments removed (sample 80+ lines)

```
/// Reads a stored/decoded `List` of maps back into typed maps ... — app_utils.dart:31
/// Validates if a URL is a YouTube playlist URL — 38
/// Extracts the playlist ID ... — 43
// Determine if this item is the absolute top ... — 13
/// Formats a [monthKey] ... into a locale-aware month label — 82
/// YouTube HE-AAC itags. iOS CoreAudio/AVPlayer reports these as ~2× duration. — 100
// Values larger than 24h-as-seconds are almost always milliseconds — 147
/// YouTube CDN URL must be absolute https ... — 153
/// googlevideo URLs carry track length as `dur` — 161
/// YouTube video IDs are 11 chars; reject path traversal ... — 170
/// Signed googlevideo URLs expire; stale preloads cause iOS -1004 — 186
/// Prefer YouTube over JioSaavn when the catalog entry is from YouTube. — 206
// CRITICAL FOR IOS: Apple AVPlayer does not support WebM — 219
/// Cache versioning constants ... — artist_constants.dart:1
// Patterns for removing common suffixes — 19
```

## Verification vs auditfinal

* **FIXED** `sanitizeStorageSongId:173` now enforces `^[a-zA-Z0-9_-]{11}$` else `_` strip + cap 64 — mitigates `common_services` SSRF via `songId`.
* **FIXED** `isUsableYoutubePlaybackUrl:199` central + used everywhere gapless.
* **NOT FIXED** `_durationFromNumber:145` 25h podcast→90s mis-parse; `selectAudioOnlyStreamForQuality:262` `sortByBitrate()` in-place sort mutation; `ProxyInfo ==` ignores `isSsl` dedup wrong.
* **NOT FIXED** `formatter` ` - ` split fails `Tyler, The Creator - IFHY`; `asMapList:33` `whereType<Map>` drops malformed but shallow clone still shared ref.
